/**
 * Forms Routes
 *
 * CRUD operations for forms with:
 * - Access control
 * - Sharing functionality
 * - Signature collection
 * - Approval workflow
 */

const express = require('express');
const router = express.Router();
const { body, param, query, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');

const db = require('../config/database');

/**
 * GET /api/forms
 * List forms for current user
 */
router.get('/', [
  query('status').optional().isIn(['draft', 'submitted', 'approved', 'rejected']),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('offset').optional().isInt({ min: 0 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { status, limit = 50, offset = 0 } = req.query;
    const userId = req.user.id;

    let queryText = `
      SELECT f.*, u.name as created_by_name,
             (SELECT COUNT(*) FROM form_signatures WHERE form_id = f.id) as signature_count,
             (SELECT COUNT(*) FROM form_attachments WHERE form_id = f.id) as attachment_count
      FROM forms f
      LEFT JOIN users u ON f.created_by = u.id
      WHERE (f.created_by = $1 OR f.assigned_to = $1
             OR f.id IN (SELECT form_id FROM form_shares WHERE shared_with_user = $1))
    `;
    const params = [userId];

    if (status) {
      params.push(status);
      queryText += ` AND f.status = $${params.length}`;
    }

    queryText += ` ORDER BY f.updated_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(limit, offset);

    const result = await db.query(queryText, params);

    // Get total count
    const countResult = await db.query(
      `SELECT COUNT(*) FROM forms f
       WHERE f.created_by = $1 OR f.assigned_to = $1
       OR f.id IN (SELECT form_id FROM form_shares WHERE shared_with_user = $1)`,
      [userId]
    );

    res.json({
      forms: result.rows,
      total: parseInt(countResult.rows[0].count),
      limit: parseInt(limit),
      offset: parseInt(offset),
    });

  } catch (error) {
    console.error('List forms error:', error);
    res.status(500).json({ error: 'Failed to list forms' });
  }
});

/**
 * GET /api/forms/:id
 * Get single form with all details
 */
router.get('/:id', [
  param('id').isUUID(),
], async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    // Get form with access check
    const formResult = await db.query(
      `SELECT f.*, u.name as created_by_name, u.email as created_by_email
       FROM forms f
       LEFT JOIN users u ON f.created_by = u.id
       WHERE f.id = $1
       AND (f.created_by = $2 OR f.assigned_to = $2
            OR f.id IN (SELECT form_id FROM form_shares WHERE shared_with_user = $2))`,
      [id, userId]
    );

    if (formResult.rows.length === 0) {
      return res.status(404).json({ error: 'Form not found' });
    }

    const form = formResult.rows[0];

    // Get signatures
    const signaturesResult = await db.query(
      `SELECT * FROM form_signatures WHERE form_id = $1 ORDER BY signed_at`,
      [id]
    );

    // Get attachments
    const attachmentsResult = await db.query(
      `SELECT * FROM form_attachments WHERE form_id = $1 ORDER BY created_at`,
      [id]
    );

    // Get approvals
    const approvalsResult = await db.query(
      `SELECT fa.*, u.name as approver_name
       FROM form_approvals fa
       LEFT JOIN users u ON fa.user_id = u.id
       WHERE fa.form_id = $1 ORDER BY fa.decided_at`,
      [id]
    );

    // Get shares
    const sharesResult = await db.query(
      `SELECT fs.*, u.name as shared_with_name
       FROM form_shares fs
       LEFT JOIN users u ON fs.shared_with_user = u.id
       WHERE fs.form_id = $1`,
      [id]
    );

    res.json({
      form,
      signatures: signaturesResult.rows,
      attachments: attachmentsResult.rows,
      approvals: approvalsResult.rows,
      shares: sharesResult.rows,
    });

  } catch (error) {
    console.error('Get form error:', error);
    res.status(500).json({ error: 'Failed to get form' });
  }
});

/**
 * POST /api/forms
 * Create new form
 */
router.post('/', [
  body('title').trim().isLength({ min: 1, max: 255 }),
  body('template_id').optional().isUUID(),
  body('fields').isArray(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { title, template_id, fields, latitude, longitude, metadata } = req.body;
    const userId = req.user.id;

    const result = await db.query(
      `INSERT INTO forms (title, template_id, fields, created_by, organization_id, latitude, longitude, metadata, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'draft')
       RETURNING *`,
      [title, template_id, JSON.stringify(fields), userId, req.user.organization_id, latitude, longitude, JSON.stringify(metadata || {})]
    );

    const form = result.rows[0];

    // Log creation
    await db.query(
      `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, new_values)
       VALUES ($1, 'create', 'form', $2, $3)`,
      [userId, form.id, JSON.stringify({ title, template_id })]
    );

    res.status(201).json({ form });

  } catch (error) {
    console.error('Create form error:', error);
    res.status(500).json({ error: 'Failed to create form' });
  }
});

/**
 * PUT /api/forms/:id
 * Update form
 */
router.put('/:id', [
  param('id').isUUID(),
  body('fields').optional().isArray(),
], async (req, res) => {
  try {
    const { id } = req.params;
    const { title, fields, metadata, latitude, longitude } = req.body;
    const userId = req.user.id;

    // Check ownership
    const existing = await db.query(
      'SELECT * FROM forms WHERE id = $1 AND created_by = $2',
      [id, userId]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ error: 'Form not found or access denied' });
    }

    if (existing.rows[0].status !== 'draft') {
      return res.status(400).json({ error: 'Cannot edit submitted form' });
    }

    const result = await db.query(
      `UPDATE forms
       SET title = COALESCE($1, title),
           fields = COALESCE($2, fields),
           metadata = COALESCE($3, metadata),
           latitude = COALESCE($4, latitude),
           longitude = COALESCE($5, longitude),
           updated_at = NOW()
       WHERE id = $6
       RETURNING *`,
      [title, fields ? JSON.stringify(fields) : null, metadata ? JSON.stringify(metadata) : null, latitude, longitude, id]
    );

    res.json({ form: result.rows[0] });

  } catch (error) {
    console.error('Update form error:', error);
    res.status(500).json({ error: 'Failed to update form' });
  }
});

/**
 * POST /api/forms/:id/submit
 * Submit form for approval
 */
router.post('/:id/submit', [
  param('id').isUUID(),
], async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    // Check ownership and status
    const existing = await db.query(
      'SELECT * FROM forms WHERE id = $1 AND created_by = $2',
      [id, userId]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ error: 'Form not found or access denied' });
    }

    if (existing.rows[0].status !== 'draft') {
      return res.status(400).json({ error: 'Form already submitted' });
    }

    const result = await db.query(
      `UPDATE forms SET status = 'submitted', submitted_at = NOW(), updated_at = NOW()
       WHERE id = $1 RETURNING *`,
      [id]
    );

    // Log submission
    await db.query(
      `INSERT INTO audit_logs (user_id, action, resource_type, resource_id)
       VALUES ($1, 'submit', 'form', $2)`,
      [userId, id]
    );

    // Create notification for approvers (if assigned)
    if (existing.rows[0].assigned_to) {
      await db.query(
        `INSERT INTO notifications (user_id, type, title, message, data)
         VALUES ($1, 'form_submitted', 'Form Submitted', 'A form requires your review', $2)`,
        [existing.rows[0].assigned_to, JSON.stringify({ form_id: id })]
      );
    }

    res.json({ form: result.rows[0] });

  } catch (error) {
    console.error('Submit form error:', error);
    res.status(500).json({ error: 'Failed to submit form' });
  }
});

/**
 * POST /api/forms/:id/approve
 * Approve form
 */
router.post('/:id/approve', [
  param('id').isUUID(),
  body('comments').optional().trim(),
], async (req, res) => {
  const client = await db.getClient();

  try {
    const { id } = req.params;
    const { comments } = req.body;
    const userId = req.user.id;

    await client.query('BEGIN');

    // Check form exists and user can approve
    const existing = await client.query(
      `SELECT * FROM forms WHERE id = $1
       AND (assigned_to = $2 OR created_by = $2 OR $2 IN (
         SELECT shared_with_user FROM form_shares WHERE form_id = $1 AND permission = 'approve'
       ))`,
      [id, userId]
    );

    if (existing.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Form not found or access denied' });
    }

    if (existing.rows[0].status !== 'submitted') {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Form is not pending approval' });
    }

    // Create approval record
    await client.query(
      `INSERT INTO form_approvals (form_id, user_id, decision, comments)
       VALUES ($1, $2, 'approved', $3)`,
      [id, userId, comments]
    );

    // Update form status
    const result = await client.query(
      `UPDATE forms SET status = 'approved', updated_at = NOW()
       WHERE id = $1 RETURNING *`,
      [id]
    );

    // Notify form creator
    await client.query(
      `INSERT INTO notifications (user_id, type, title, message, data)
       VALUES ($1, 'form_approved', 'Form Approved', 'Your form has been approved', $2)`,
      [existing.rows[0].created_by, JSON.stringify({ form_id: id })]
    );

    await client.query('COMMIT');

    res.json({ form: result.rows[0] });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Approve form error:', error);
    res.status(500).json({ error: 'Failed to approve form' });
  } finally {
    client.release();
  }
});

/**
 * POST /api/forms/:id/reject
 * Reject form
 */
router.post('/:id/reject', [
  param('id').isUUID(),
  body('reason').trim().isLength({ min: 1 }).withMessage('Rejection reason required'),
], async (req, res) => {
  const client = await db.getClient();

  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { id } = req.params;
    const { reason } = req.body;
    const userId = req.user.id;

    await client.query('BEGIN');

    // Check form exists and user can approve
    const existing = await client.query(
      `SELECT * FROM forms WHERE id = $1
       AND (assigned_to = $2 OR created_by = $2)`,
      [id, userId]
    );

    if (existing.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Form not found or access denied' });
    }

    // Create rejection record
    await client.query(
      `INSERT INTO form_approvals (form_id, user_id, decision, comments)
       VALUES ($1, $2, 'rejected', $3)`,
      [id, userId, reason]
    );

    // Update form status
    const result = await client.query(
      `UPDATE forms SET status = 'rejected', updated_at = NOW()
       WHERE id = $1 RETURNING *`,
      [id]
    );

    // Notify form creator
    await client.query(
      `INSERT INTO notifications (user_id, type, title, message, data)
       VALUES ($1, 'form_rejected', 'Form Rejected', $2, $3)`,
      [existing.rows[0].created_by, `Reason: ${reason}`, JSON.stringify({ form_id: id })]
    );

    await client.query('COMMIT');

    res.json({ form: result.rows[0] });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Reject form error:', error);
    res.status(500).json({ error: 'Failed to reject form' });
  } finally {
    client.release();
  }
});

/**
 * POST /api/forms/:id/share
 * Share form with another user
 */
router.post('/:id/share', [
  param('id').isUUID(),
  body('email').isEmail().normalizeEmail(),
  body('permission').isIn(['view', 'sign', 'approve']),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { id } = req.params;
    const { email, permission } = req.body;
    const userId = req.user.id;

    // Check ownership
    const existing = await db.query(
      'SELECT * FROM forms WHERE id = $1 AND created_by = $2',
      [id, userId]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ error: 'Form not found or access denied' });
    }

    // Check if user exists
    const userResult = await db.query(
      'SELECT id FROM users WHERE email = $1',
      [email]
    );

    const sharedWithUserId = userResult.rows.length > 0 ? userResult.rows[0].id : null;

    // Generate share token
    const shareToken = crypto.randomBytes(32).toString('hex');

    // Create share
    const result = await db.query(
      `INSERT INTO form_shares (form_id, shared_by, shared_with_email, shared_with_user, permission, token, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW() + INTERVAL '7 days')
       RETURNING *`,
      [id, userId, email, sharedWithUserId, permission, shareToken]
    );

    // Create notification if user exists
    if (sharedWithUserId) {
      await db.query(
        `INSERT INTO notifications (user_id, type, title, message, data)
         VALUES ($1, 'form_shared', 'Form Shared With You', 'Someone shared a form with you', $2)`,
        [sharedWithUserId, JSON.stringify({ form_id: id })]
      );
    }

    // TODO: Send email notification

    res.json({
      share: result.rows[0],
      shareLink: `${process.env.APP_URL}/forms/shared/${shareToken}`,
    });

  } catch (error) {
    console.error('Share form error:', error);
    res.status(500).json({ error: 'Failed to share form' });
  }
});

/**
 * POST /api/forms/:id/signatures
 * Add signature to form
 */
router.post('/:id/signatures', [
  param('id').isUUID(),
  body('signer_name').trim().isLength({ min: 1 }),
  body('signer_role').optional().trim(),
  body('signature_data').isLength({ min: 1 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { id } = req.params;
    const { signer_name, signer_role, signer_email, signature_type, signature_data, witness_name, witness_email } = req.body;
    const userId = req.user.id;

    // Check access
    const access = await db.query(
      `SELECT * FROM forms WHERE id = $1
       AND (created_by = $2 OR assigned_to = $2
            OR id IN (SELECT form_id FROM form_shares WHERE shared_with_user = $2 AND permission IN ('sign', 'approve')))`,
      [id, userId]
    );

    if (access.rows.length === 0) {
      return res.status(404).json({ error: 'Form not found or access denied' });
    }

    // Create signature
    const result = await db.query(
      `INSERT INTO form_signatures (form_id, user_id, signer_name, signer_email, signer_role, signature_type, signature_data, witness_name, witness_email, ip_address, user_agent)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [id, userId, signer_name, signer_email, signer_role, signature_type || 'drawn', signature_data, witness_name, witness_email, req.ip, req.get('user-agent')]
    );

    // Update form
    await db.query(
      'UPDATE forms SET updated_at = NOW() WHERE id = $1',
      [id]
    );

    res.status(201).json({ signature: result.rows[0] });

  } catch (error) {
    console.error('Add signature error:', error);
    res.status(500).json({ error: 'Failed to add signature' });
  }
});

/**
 * DELETE /api/forms/:id
 * Delete form (only drafts)
 */
router.delete('/:id', [
  param('id').isUUID(),
], async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    // Check ownership and status
    const existing = await db.query(
      'SELECT * FROM forms WHERE id = $1 AND created_by = $2',
      [id, userId]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ error: 'Form not found or access denied' });
    }

    if (existing.rows[0].status !== 'draft') {
      return res.status(400).json({ error: 'Cannot delete submitted form' });
    }

    await db.query('DELETE FROM forms WHERE id = $1', [id]);

    // Log deletion
    await db.query(
      `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, old_values)
       VALUES ($1, 'delete', 'form', $2, $3)`,
      [userId, id, JSON.stringify({ title: existing.rows[0].title })]
    );

    res.json({ message: 'Form deleted' });

  } catch (error) {
    console.error('Delete form error:', error);
    res.status(500).json({ error: 'Failed to delete form' });
  }
});

module.exports = router;
