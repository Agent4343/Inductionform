/**
 * User Management Routes
 *
 * Secure endpoints for user profile and organization management
 */

const express = require('express');
const bcrypt = require('bcryptjs');
const { body, param, query, validationResult } = require('express-validator');
const { query: dbQuery, getClient } = require('../config/database');
const { requireRole } = require('../middleware/auth');

const router = express.Router();

// Password requirements
const PASSWORD_MIN_LENGTH = 8;
const BCRYPT_ROUNDS = 12;

/**
 * Validation middleware
 */
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

// ===================
// PROFILE ROUTES
// ===================

/**
 * GET /api/users/me
 * Get current user profile
 */
router.get('/me', async (req, res, next) => {
  try {
    const result = await dbQuery(
      `SELECT
        u.id, u.email, u.name, u.role, u.is_active, u.email_verified,
        u.last_login_at, u.created_at,
        o.id as organization_id, o.name as organization_name
       FROM users u
       LEFT JOIN organizations o ON u.organization_id = o.id
       WHERE u.id = $1`,
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
});

/**
 * PUT /api/users/me
 * Update current user profile
 */
router.put('/me',
  [
    body('name').optional().trim().notEmpty().isLength({ max: 255 }).escape(),
    body('email').optional().isEmail().normalizeEmail(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const { name, email } = req.body;
      const updates = [];
      const values = [];
      let paramIndex = 1;

      if (name) {
        updates.push(`name = $${paramIndex++}`);
        values.push(name);
      }

      if (email && email !== req.user.email) {
        // Check if email is already taken
        const existing = await dbQuery(
          'SELECT id FROM users WHERE email = $1 AND id != $2',
          [email, req.user.id]
        );

        if (existing.rows.length > 0) {
          return res.status(400).json({ error: 'Email already in use' });
        }

        updates.push(`email = $${paramIndex++}`);
        updates.push(`email_verified = false`); // Require re-verification
        values.push(email);
      }

      if (updates.length === 0) {
        return res.status(400).json({ error: 'No valid fields to update' });
      }

      updates.push(`updated_at = CURRENT_TIMESTAMP`);
      values.push(req.user.id);

      const result = await dbQuery(
        `UPDATE users
         SET ${updates.join(', ')}
         WHERE id = $${paramIndex}
         RETURNING id, email, name, role, email_verified, updated_at`,
        values
      );

      // Log audit
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, new_values, ip_address)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [req.user.id, 'update', 'user', req.user.id, JSON.stringify({ name, email }), req.ip]
      );

      res.json(result.rows[0]);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * PUT /api/users/me/password
 * Change password
 */
router.put('/me/password',
  [
    body('currentPassword').notEmpty().withMessage('Current password is required'),
    body('newPassword')
      .isLength({ min: PASSWORD_MIN_LENGTH })
      .withMessage(`Password must be at least ${PASSWORD_MIN_LENGTH} characters`)
      .matches(/[A-Z]/)
      .withMessage('Password must contain uppercase letter')
      .matches(/[a-z]/)
      .withMessage('Password must contain lowercase letter')
      .matches(/[0-9]/)
      .withMessage('Password must contain number'),
  ],
  validate,
  async (req, res, next) => {
    try {
      const { currentPassword, newPassword } = req.body;

      // Get current password hash
      const user = await dbQuery(
        'SELECT password_hash FROM users WHERE id = $1',
        [req.user.id]
      );

      if (user.rows.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }

      // Verify current password
      const validPassword = await bcrypt.compare(currentPassword, user.rows[0].password_hash);
      if (!validPassword) {
        return res.status(401).json({ error: 'Current password is incorrect' });
      }

      // Hash new password
      const newPasswordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);

      // Update password
      await dbQuery(
        `UPDATE users
         SET password_hash = $1, updated_at = CURRENT_TIMESTAMP
         WHERE id = $2`,
        [newPasswordHash, req.user.id]
      );

      // Revoke all refresh tokens (force re-login on other devices)
      await dbQuery(
        `UPDATE refresh_tokens
         SET revoked_at = CURRENT_TIMESTAMP
         WHERE user_id = $1 AND revoked_at IS NULL`,
        [req.user.id]
      );

      // Log audit
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, ip_address)
         VALUES ($1, $2, $3, $4, $5)`,
        [req.user.id, 'password_change', 'user', req.user.id, req.ip]
      );

      res.json({ message: 'Password updated successfully' });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /api/users/me/notifications
 * Get user notifications
 */
router.get('/me/notifications',
  [
    query('unreadOnly').optional().isBoolean().toBoolean(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const unreadOnly = req.query.unreadOnly || false;
      const limit = req.query.limit || 50;

      let queryText = `
        SELECT * FROM notifications
        WHERE user_id = $1
      `;
      const params = [req.user.id];

      if (unreadOnly) {
        queryText += ` AND read_at IS NULL`;
      }

      queryText += ` ORDER BY created_at DESC LIMIT $2`;
      params.push(limit);

      const result = await dbQuery(queryText, params);

      // Get unread count
      const countResult = await dbQuery(
        `SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND read_at IS NULL`,
        [req.user.id]
      );

      res.json({
        notifications: result.rows,
        unreadCount: parseInt(countResult.rows[0].count),
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * PUT /api/users/me/notifications/:id/read
 * Mark notification as read
 */
router.put('/me/notifications/:id/read',
  [
    param('id').isUUID().withMessage('Invalid notification ID'),
  ],
  validate,
  async (req, res, next) => {
    try {
      const result = await dbQuery(
        `UPDATE notifications
         SET read_at = CURRENT_TIMESTAMP
         WHERE id = $1 AND user_id = $2
         RETURNING id`,
        [req.params.id, req.user.id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Notification not found' });
      }

      res.json({ message: 'Notification marked as read' });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * PUT /api/users/me/notifications/read-all
 * Mark all notifications as read
 */
router.put('/me/notifications/read-all', async (req, res, next) => {
  try {
    await dbQuery(
      `UPDATE notifications
       SET read_at = CURRENT_TIMESTAMP
       WHERE user_id = $1 AND read_at IS NULL`,
      [req.user.id]
    );

    res.json({ message: 'All notifications marked as read' });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/users/me/activity
 * Get user activity log
 */
router.get('/me/activity',
  [
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
    query('offset').optional().isInt({ min: 0 }).toInt(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const limit = req.query.limit || 50;
      const offset = req.query.offset || 0;

      const result = await dbQuery(
        `SELECT action, resource_type, resource_id, created_at
         FROM audit_logs
         WHERE user_id = $1
         ORDER BY created_at DESC
         LIMIT $2 OFFSET $3`,
        [req.user.id, limit, offset]
      );

      res.json(result.rows);
    } catch (error) {
      next(error);
    }
  }
);

// ===================
// ORGANIZATION USER MANAGEMENT (Admin only)
// ===================

/**
 * GET /api/users
 * List users in organization (Admin/Manager only)
 */
router.get('/',
  requireRole(['admin', 'manager']),
  [
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
    query('role').optional().trim().escape(),
    query('search').optional().trim().escape(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const page = req.query.page || 1;
      const limit = req.query.limit || 20;
      const offset = (page - 1) * limit;
      const { role, search } = req.query;

      let queryText = `
        SELECT
          id, email, name, role, is_active, email_verified,
          last_login_at, created_at
         FROM users
         WHERE organization_id = $1
      `;
      const params = [req.user.organizationId];
      let paramIndex = 2;

      if (role) {
        queryText += ` AND role = $${paramIndex++}`;
        params.push(role);
      }

      if (search) {
        queryText += ` AND (name ILIKE $${paramIndex} OR email ILIKE $${paramIndex})`;
        params.push(`%${search}%`);
        paramIndex++;
      }

      queryText += ` ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
      params.push(limit, offset);

      const result = await dbQuery(queryText, params);

      // Get total count
      let countQuery = `SELECT COUNT(*) FROM users WHERE organization_id = $1`;
      const countParams = [req.user.organizationId];

      if (role) {
        countQuery += ` AND role = $2`;
        countParams.push(role);
      }

      const countResult = await dbQuery(countQuery, countParams);
      const total = parseInt(countResult.rows[0].count);

      res.json({
        users: result.rows,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit),
        },
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * POST /api/users/invite
 * Invite user to organization (Admin only)
 */
router.post('/invite',
  requireRole(['admin']),
  [
    body('email').isEmail().normalizeEmail(),
    body('name').trim().notEmpty().isLength({ max: 255 }).escape(),
    body('role').isIn(['user', 'manager']).withMessage('Invalid role'),
  ],
  validate,
  async (req, res, next) => {
    try {
      const { email, name, role } = req.body;

      // Check if user already exists
      const existing = await dbQuery(
        'SELECT id, organization_id FROM users WHERE email = $1',
        [email]
      );

      if (existing.rows.length > 0) {
        if (existing.rows[0].organization_id) {
          return res.status(400).json({ error: 'User already belongs to an organization' });
        }

        // Update existing user to join organization
        await dbQuery(
          `UPDATE users
           SET organization_id = $1, role = $2, updated_at = CURRENT_TIMESTAMP
           WHERE id = $3`,
          [req.user.organizationId, role, existing.rows[0].id]
        );

        // Create notification
        await dbQuery(
          `INSERT INTO notifications (user_id, type, title, message, data)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            existing.rows[0].id,
            'organization_invite',
            'Organization Invitation',
            `You have been added to an organization`,
            JSON.stringify({ organizationId: req.user.organizationId }),
          ]
        );

        return res.json({ message: 'User added to organization' });
      }

      // Create new user with temporary password
      const tempPassword = require('crypto').randomBytes(16).toString('hex');
      const passwordHash = await bcrypt.hash(tempPassword, BCRYPT_ROUNDS);

      const result = await dbQuery(
        `INSERT INTO users (email, password_hash, name, role, organization_id, email_verified)
         VALUES ($1, $2, $3, $4, $5, false)
         RETURNING id, email, name, role`,
        [email, passwordHash, name, role, req.user.organizationId]
      );

      // TODO: Send invitation email with password reset link

      // Log audit
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, new_values, ip_address)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [req.user.id, 'invite', 'user', result.rows[0].id, JSON.stringify({ email, role }), req.ip]
      );

      res.status(201).json({
        message: 'User invited successfully',
        user: result.rows[0],
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * PUT /api/users/:id/role
 * Update user role (Admin only)
 */
router.put('/:id/role',
  requireRole(['admin']),
  [
    param('id').isUUID().withMessage('Invalid user ID'),
    body('role').isIn(['user', 'manager', 'admin']).withMessage('Invalid role'),
  ],
  validate,
  async (req, res, next) => {
    try {
      // Can't change own role
      if (req.params.id === req.user.id) {
        return res.status(400).json({ error: 'Cannot change your own role' });
      }

      const result = await dbQuery(
        `UPDATE users
         SET role = $1, updated_at = CURRENT_TIMESTAMP
         WHERE id = $2 AND organization_id = $3
         RETURNING id, email, name, role`,
        [req.body.role, req.params.id, req.user.organizationId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'User not found in your organization' });
      }

      // Log audit
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, new_values, ip_address)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [req.user.id, 'role_change', 'user', req.params.id, JSON.stringify({ role: req.body.role }), req.ip]
      );

      res.json(result.rows[0]);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * PUT /api/users/:id/deactivate
 * Deactivate user (Admin only)
 */
router.put('/:id/deactivate',
  requireRole(['admin']),
  [
    param('id').isUUID().withMessage('Invalid user ID'),
  ],
  validate,
  async (req, res, next) => {
    try {
      // Can't deactivate yourself
      if (req.params.id === req.user.id) {
        return res.status(400).json({ error: 'Cannot deactivate yourself' });
      }

      const result = await dbQuery(
        `UPDATE users
         SET is_active = false, updated_at = CURRENT_TIMESTAMP
         WHERE id = $1 AND organization_id = $2
         RETURNING id`,
        [req.params.id, req.user.organizationId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'User not found in your organization' });
      }

      // Revoke all their tokens
      await dbQuery(
        `UPDATE refresh_tokens
         SET revoked_at = CURRENT_TIMESTAMP
         WHERE user_id = $1`,
        [req.params.id]
      );

      // Log audit
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, ip_address)
         VALUES ($1, $2, $3, $4, $5)`,
        [req.user.id, 'deactivate', 'user', req.params.id, req.ip]
      );

      res.json({ message: 'User deactivated successfully' });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * PUT /api/users/:id/reactivate
 * Reactivate user (Admin only)
 */
router.put('/:id/reactivate',
  requireRole(['admin']),
  [
    param('id').isUUID().withMessage('Invalid user ID'),
  ],
  validate,
  async (req, res, next) => {
    try {
      const result = await dbQuery(
        `UPDATE users
         SET is_active = true, updated_at = CURRENT_TIMESTAMP
         WHERE id = $1 AND organization_id = $2
         RETURNING id`,
        [req.params.id, req.user.organizationId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'User not found in your organization' });
      }

      // Log audit
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, ip_address)
         VALUES ($1, $2, $3, $4, $5)`,
        [req.user.id, 'reactivate', 'user', req.params.id, req.ip]
      );

      res.json({ message: 'User reactivated successfully' });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * DELETE /api/users/:id
 * Remove user from organization (Admin only)
 * Note: This doesn't delete the user, just removes them from the org
 */
router.delete('/:id',
  requireRole(['admin']),
  [
    param('id').isUUID().withMessage('Invalid user ID'),
  ],
  validate,
  async (req, res, next) => {
    try {
      // Can't remove yourself
      if (req.params.id === req.user.id) {
        return res.status(400).json({ error: 'Cannot remove yourself from the organization' });
      }

      const result = await dbQuery(
        `UPDATE users
         SET organization_id = NULL, role = 'user', updated_at = CURRENT_TIMESTAMP
         WHERE id = $1 AND organization_id = $2
         RETURNING id`,
        [req.params.id, req.user.organizationId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'User not found in your organization' });
      }

      // Revoke all their tokens
      await dbQuery(
        `UPDATE refresh_tokens
         SET revoked_at = CURRENT_TIMESTAMP
         WHERE user_id = $1`,
        [req.params.id]
      );

      // Log audit
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, ip_address)
         VALUES ($1, $2, $3, $4, $5)`,
        [req.user.id, 'remove_from_org', 'user', req.params.id, req.ip]
      );

      res.json({ message: 'User removed from organization' });
    } catch (error) {
      next(error);
    }
  }
);

module.exports = router;
