/**
 * Authentication Middleware
 *
 * Security features:
 * - JWT verification
 * - Token expiration checking
 * - User lookup from database
 */

const jwt = require('jsonwebtoken');
const db = require('../config/database');

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

/**
 * Verify JWT token and attach user to request
 */
const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      return res.status(401).json({ error: 'Access token required' });
    }

    // Verify token
    let decoded;
    try {
      decoded = jwt.verify(token, JWT_SECRET);
    } catch (err) {
      if (err.name === 'TokenExpiredError') {
        return res.status(401).json({ error: 'Token expired', code: 'TOKEN_EXPIRED' });
      }
      return res.status(403).json({ error: 'Invalid token' });
    }

    // Get user from database
    const result = await db.query(
      'SELECT id, email, name, role, organization_id, is_active FROM users WHERE id = $1',
      [decoded.userId]
    );

    if (result.rows.length === 0) {
      return res.status(403).json({ error: 'User not found' });
    }

    const user = result.rows[0];

    if (!user.is_active) {
      return res.status(403).json({ error: 'Account is deactivated' });
    }

    // Attach user to request
    req.user = user;
    next();

  } catch (error) {
    console.error('Auth middleware error:', error);
    res.status(500).json({ error: 'Authentication failed' });
  }
};

/**
 * Check if user has required role
 * Usage: requireRole('admin') or requireRole(['admin', 'manager'])
 */
const requireRole = (roles) => {
  // Handle both array and single role
  const allowedRoles = Array.isArray(roles) ? roles : [roles];

  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }

    next();
  };
};

/**
 * Optional authentication - attach user if token provided, but don't require it
 */
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return next();
    }

    const decoded = jwt.verify(token, JWT_SECRET);

    const result = await db.query(
      'SELECT id, email, name, role, organization_id, is_active FROM users WHERE id = $1',
      [decoded.userId]
    );

    if (result.rows.length > 0 && result.rows[0].is_active) {
      req.user = result.rows[0];
    }

    next();
  } catch (error) {
    // Token invalid, but that's okay for optional auth
    next();
  }
};

/**
 * Generate access token
 */
const generateAccessToken = (userId) => {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: '15m' });
};

/**
 * Generate refresh token
 */
const generateRefreshToken = (userId) => {
  return jwt.sign({ userId, type: 'refresh' }, JWT_SECRET, { expiresIn: '7d' });
};

module.exports = {
  authenticateToken,
  requireRole,
  optionalAuth,
  generateAccessToken,
  generateRefreshToken,
  JWT_SECRET,
};
