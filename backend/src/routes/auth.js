/**
 * Authentication Routes
 *
 * Security features:
 * - Password hashing with bcrypt (cost factor 12)
 * - JWT tokens with short expiration
 * - Refresh token rotation
 * - Input validation
 * - Rate limiting (applied in server.js)
 */

const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { body, validationResult } = require('express-validator');

const db = require('../config/database');
const {
  generateAccessToken,
  generateRefreshToken,
  authenticateToken,
  JWT_SECRET
} = require('../middleware/auth');
const jwt = require('jsonwebtoken');

// Bcrypt cost factor (higher = more secure but slower)
const BCRYPT_ROUNDS = 12;

/**
 * POST /api/auth/register
 * Create new user account
 */
router.post('/register', [
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('password')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters')
    .matches(/[A-Z]/)
    .withMessage('Password must contain uppercase letter')
    .matches(/[a-z]/)
    .withMessage('Password must contain lowercase letter')
    .matches(/[0-9]/)
    .withMessage('Password must contain number'),
  body('name').trim().isLength({ min: 2 }).withMessage('Name required'),
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, password, name } = req.body;

    // Check if email already exists
    const existingUser = await db.query(
      'SELECT id FROM users WHERE email = $1',
      [email.toLowerCase()]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

    // Create user
    const result = await db.query(
      `INSERT INTO users (email, password_hash, name, role)
       VALUES ($1, $2, $3, $4)
       RETURNING id, email, name, role, created_at`,
      [email.toLowerCase(), passwordHash, name, 'user']
    );

    const user = result.rows[0];

    // Generate tokens
    const accessToken = generateAccessToken(user.id);
    const refreshToken = generateRefreshToken(user.id);

    // Store refresh token hash
    const refreshTokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    await db.query(
      `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
       VALUES ($1, $2, NOW() + INTERVAL '7 days')`,
      [user.id, refreshTokenHash]
    );

    // Log the registration
    await db.query(
      `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, ip_address, user_agent)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [user.id, 'register', 'user', user.id, req.ip, req.get('user-agent')]
    );

    res.status(201).json({
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
      },
      accessToken,
      refreshToken,
    });

  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Registration failed' });
  }
});

/**
 * POST /api/auth/login
 * Authenticate user and return tokens
 */
router.post('/login', [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, password } = req.body;

    // Get user
    const result = await db.query(
      'SELECT id, email, password_hash, name, role, is_active FROM users WHERE email = $1',
      [email.toLowerCase()]
    );

    if (result.rows.length === 0) {
      // Use same error message to prevent email enumeration
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];

    if (!user.is_active) {
      return res.status(401).json({ error: 'Account is deactivated' });
    }

    // Verify password
    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate tokens
    const accessToken = generateAccessToken(user.id);
    const refreshToken = generateRefreshToken(user.id);

    // Store refresh token hash
    const refreshTokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    await db.query(
      `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
       VALUES ($1, $2, NOW() + INTERVAL '7 days')`,
      [user.id, refreshTokenHash]
    );

    // Update last login
    await db.query(
      'UPDATE users SET last_login_at = NOW() WHERE id = $1',
      [user.id]
    );

    // Log the login
    await db.query(
      `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, ip_address, user_agent)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [user.id, 'login', 'user', user.id, req.ip, req.get('user-agent')]
    );

    res.json({
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
      },
      accessToken,
      refreshToken,
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Login failed' });
  }
});

/**
 * POST /api/auth/refresh
 * Get new access token using refresh token
 */
router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token required' });
    }

    // Verify token
    let decoded;
    try {
      decoded = jwt.verify(refreshToken, JWT_SECRET);
    } catch (err) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    // Check if token exists and not revoked
    const tokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    const result = await db.query(
      `SELECT id, user_id FROM refresh_tokens
       WHERE token_hash = $1 AND expires_at > NOW() AND revoked_at IS NULL`,
      [tokenHash]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid or expired refresh token' });
    }

    const tokenRecord = result.rows[0];

    // Revoke old refresh token (rotation)
    await db.query(
      'UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = $1',
      [tokenRecord.id]
    );

    // Generate new tokens
    const newAccessToken = generateAccessToken(tokenRecord.user_id);
    const newRefreshToken = generateRefreshToken(tokenRecord.user_id);

    // Store new refresh token
    const newTokenHash = crypto.createHash('sha256').update(newRefreshToken).digest('hex');
    await db.query(
      `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
       VALUES ($1, $2, NOW() + INTERVAL '7 days')`,
      [tokenRecord.user_id, newTokenHash]
    );

    res.json({
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    });

  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(500).json({ error: 'Token refresh failed' });
  }
});

/**
 * POST /api/auth/logout
 * Revoke refresh token
 */
router.post('/logout', authenticateToken, async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (refreshToken) {
      const tokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
      await db.query(
        'UPDATE refresh_tokens SET revoked_at = NOW() WHERE token_hash = $1',
        [tokenHash]
      );
    }

    // Log the logout
    await db.query(
      `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, ip_address, user_agent)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [req.user.id, 'logout', 'user', req.user.id, req.ip, req.get('user-agent')]
    );

    res.json({ message: 'Logged out successfully' });

  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({ error: 'Logout failed' });
  }
});

/**
 * POST /api/auth/forgot-password
 * Send password reset email
 */
router.post('/forgot-password', [
  body('email').isEmail().normalizeEmail(),
], async (req, res) => {
  try {
    const { email } = req.body;

    // Always return success to prevent email enumeration
    res.json({ message: 'If the email exists, a reset link will be sent.' });

    // Check if user exists (async, don't wait)
    const result = await db.query(
      'SELECT id FROM users WHERE email = $1',
      [email.toLowerCase()]
    );

    if (result.rows.length > 0) {
      // TODO: Generate reset token and send email
      // For now, just log it
      console.log(`Password reset requested for: ${email}`);
    }

  } catch (error) {
    console.error('Forgot password error:', error);
    // Still return success to prevent enumeration
    res.json({ message: 'If the email exists, a reset link will be sent.' });
  }
});

/**
 * GET /api/auth/me
 * Get current user info
 */
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const result = await db.query(
      `SELECT id, email, name, role, organization_id, created_at, last_login_at
       FROM users WHERE id = $1`,
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user: result.rows[0] });

  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Failed to get user info' });
  }
});

/**
 * DELETE /api/auth/account
 * Delete user account (GDPR compliance)
 */
router.delete('/account', authenticateToken, async (req, res) => {
  const client = await db.getClient();

  try {
    await client.query('BEGIN');

    // Delete user's data
    await client.query('DELETE FROM notifications WHERE user_id = $1', [req.user.id]);
    await client.query('DELETE FROM refresh_tokens WHERE user_id = $1', [req.user.id]);

    // Anonymize audit logs (keep for compliance but remove identifying info)
    await client.query(
      `UPDATE audit_logs SET user_id = NULL WHERE user_id = $1`,
      [req.user.id]
    );

    // Delete the user
    await client.query('DELETE FROM users WHERE id = $1', [req.user.id]);

    await client.query('COMMIT');

    res.json({ message: 'Account deleted successfully' });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Delete account error:', error);
    res.status(500).json({ error: 'Failed to delete account' });
  } finally {
    client.release();
  }
});

module.exports = router;
