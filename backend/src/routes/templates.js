/**
 * Form Templates Routes
 *
 * Secure endpoints for managing form templates
 */

const express = require('express');
const { body, param, query, validationResult } = require('express-validator');
const { query: dbQuery, getClient } = require('../config/database');
const { requireRole } = require('../middleware/auth');
const fs = require('fs');
const path = require('path');

const router = express.Router();

/**
 * Load built-in templates from JSON file
 */
let builtInTemplates = [];
try {
  const templatesPath = path.join(__dirname, '../../../shared/templates/industrial-templates.json');
  const templatesData = fs.readFileSync(templatesPath, 'utf8');
  const parsedData = JSON.parse(templatesData);
  builtInTemplates = parsedData.templates.map(template => ({
    ...template,
    fieldCount: template.fields?.length || 0,
    is_public: true,
    is_builtin: true,
    version: template.version || '1.0'
  }));
  console.log(`Loaded ${builtInTemplates.length} built-in templates from JSON`);
} catch (error) {
  console.error('Failed to load built-in templates:', error.message);
}

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

/**
 * GET /api/templates
 * List available templates (built-in + database)
 */
router.get('/',
  [
    query('category').optional().trim().escape(),
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const category = req.query.category;
      
      // Start with built-in templates
      let allTemplates = [...builtInTemplates];

      // Filter built-in templates by category if specified
      if (category) {
        allTemplates = allTemplates.filter(t => 
          t.category.toLowerCase() === category.toLowerCase()
        );
      }

      // Try to fetch database templates (may fail if DB not set up)
      try {
        const page = req.query.page || 1;
        const limit = req.query.limit || 20;
        const offset = (page - 1) * limit;

        let queryText = `
          SELECT
            t.id, t.name, t.description, t.category, t.fields,
            t.settings, t.is_public, t.version, t.created_at,
            u.name as created_by_name
          FROM form_templates t
          LEFT JOIN users u ON t.created_by = u.id
          WHERE t.is_active = true
            AND (
              t.is_public = true
              OR t.organization_id = $1
              OR t.created_by = $2
            )
        `;
        const params = [req.user.organizationId, req.user.id];
        let paramIndex = 3;

        if (category) {
          queryText += ` AND t.category = $${paramIndex}`;
          params.push(category);
          paramIndex++;
        }

        queryText += ` ORDER BY t.created_at DESC`;

        const result = await dbQuery(queryText, params);
        
        // Add database templates with fieldCount
        const dbTemplates = result.rows.map(t => ({
          ...t,
          fieldCount: Array.isArray(t.fields) ? t.fields.length : 0,
          is_builtin: false
        }));
        
        allTemplates = [...allTemplates, ...dbTemplates];
      } catch (dbError) {
        console.log('Database templates not available, using built-in only:', dbError.message);
      }

      res.json({
        templates: allTemplates,
        pagination: {
          page: 1,
          limit: allTemplates.length,
          total: allTemplates.length,
          pages: 1
        }
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /api/templates/:id
 * Get single template (built-in or database)
 */
router.get('/:id',
  [
    param('id').notEmpty().withMessage('Template ID required'),
  ],
  validate,
  async (req, res, next) => {
    try {
      const templateId = req.params.id;
      
      // First check if it's a built-in template
      const builtInTemplate = builtInTemplates.find(t => t.id === templateId);
      if (builtInTemplate) {
        return res.json(builtInTemplate);
      }

      // Otherwise try database (UUID validation for DB templates)
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(templateId)) {
        return res.status(404).json({ error: 'Template not found' });
      }

      const result = await dbQuery(
        `SELECT
          t.*, u.name as created_by_name
         FROM form_templates t
         LEFT JOIN users u ON t.created_by = u.id
         WHERE t.id = $1
           AND t.is_active = true
           AND (
             t.is_public = true
             OR t.organization_id = $2
             OR t.created_by = $3
           )`,
        [templateId, req.user.organizationId, req.user.id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Template not found' });
      }

      res.json(result.rows[0]);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * POST /api/templates
 * Create new template
 */
router.post('/',
  [
    body('name').trim().notEmpty().isLength({ max: 255 }).escape(),
    body('description').optional().trim().isLength({ max: 2000 }).escape(),
    body('category').optional().trim().isLength({ max: 100 }).escape(),
    body('fields').isArray().withMessage('Fields must be an array'),
    body('fields.*.id').notEmpty().withMessage('Each field must have an ID'),
    body('fields.*.type').notEmpty().withMessage('Each field must have a type'),
    body('fields.*.label').notEmpty().withMessage('Each field must have a label'),
    body('settings').optional().isObject(),
    body('isPublic').optional().isBoolean(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const { name, description, category, fields, settings, isPublic } = req.body;

      // Sanitize field data
      const sanitizedFields = fields.map(field => ({
        id: field.id,
        type: field.type,
        label: String(field.label).substring(0, 255),
        placeholder: field.placeholder ? String(field.placeholder).substring(0, 255) : null,
        required: Boolean(field.required),
        options: Array.isArray(field.options) ? field.options.slice(0, 100) : [],
        defaultValue: field.defaultValue,
        validation: field.validation || {},
        conditions: Array.isArray(field.conditions) ? field.conditions : [],
        order: parseInt(field.order) || 0,
      }));

      const result = await dbQuery(
        `INSERT INTO form_templates
         (name, description, category, organization_id, created_by, fields, settings, is_public)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [
          name,
          description || null,
          category || null,
          req.user.organizationId,
          req.user.id,
          JSON.stringify(sanitizedFields),
          JSON.stringify(settings || {}),
          isPublic || false
        ]
      );

      // Log audit
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, new_values, ip_address)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [req.user.id, 'create', 'template', result.rows[0].id, JSON.stringify({ name }), req.ip]
      );

      res.status(201).json(result.rows[0]);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * PUT /api/templates/:id
 * Update template (creates new version)
 */
router.put('/:id',
  [
    param('id').isUUID().withMessage('Invalid template ID'),
    body('name').optional().trim().notEmpty().isLength({ max: 255 }).escape(),
    body('description').optional().trim().isLength({ max: 2000 }).escape(),
    body('category').optional().trim().isLength({ max: 100 }).escape(),
    body('fields').optional().isArray(),
    body('settings').optional().isObject(),
    body('isPublic').optional().isBoolean(),
  ],
  validate,
  async (req, res, next) => {
    const client = await getClient();

    try {
      await client.query('BEGIN');

      // Check ownership
      const existing = await client.query(
        `SELECT * FROM form_templates
         WHERE id = $1 AND is_active = true
           AND (created_by = $2 OR organization_id = $3)`,
        [req.params.id, req.user.id, req.user.organizationId]
      );

      if (existing.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Template not found or access denied' });
      }

      const template = existing.rows[0];
      const { name, description, category, fields, settings, isPublic } = req.body;

      // Prepare update fields
      const updates = [];
      const values = [];
      let paramIndex = 1;

      if (name !== undefined) {
        updates.push(`name = $${paramIndex++}`);
        values.push(name);
      }
      if (description !== undefined) {
        updates.push(`description = $${paramIndex++}`);
        values.push(description);
      }
      if (category !== undefined) {
        updates.push(`category = $${paramIndex++}`);
        values.push(category);
      }
      if (fields !== undefined) {
        updates.push(`fields = $${paramIndex++}`);
        values.push(JSON.stringify(fields));
      }
      if (settings !== undefined) {
        updates.push(`settings = $${paramIndex++}`);
        values.push(JSON.stringify(settings));
      }
      if (isPublic !== undefined) {
        updates.push(`is_public = $${paramIndex++}`);
        values.push(isPublic);
      }

      // Increment version
      updates.push(`version = version + 1`);
      updates.push(`updated_at = CURRENT_TIMESTAMP`);

      values.push(req.params.id);

      const result = await client.query(
        `UPDATE form_templates
         SET ${updates.join(', ')}
         WHERE id = $${paramIndex}
         RETURNING *`,
        values
      );

      // Log audit
      await client.query(
        `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, old_values, new_values, ip_address)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          req.user.id,
          'update',
          'template',
          req.params.id,
          JSON.stringify({ name: template.name, version: template.version }),
          JSON.stringify({ name: result.rows[0].name, version: result.rows[0].version }),
          req.ip
        ]
      );

      await client.query('COMMIT');
      res.json(result.rows[0]);
    } catch (error) {
      await client.query('ROLLBACK');
      next(error);
    } finally {
      client.release();
    }
  }
);

/**
 * DELETE /api/templates/:id
 * Soft delete template
 */
router.delete('/:id',
  [
    param('id').isUUID().withMessage('Invalid template ID'),
  ],
  validate,
  async (req, res, next) => {
    try {
      const result = await dbQuery(
        `UPDATE form_templates
         SET is_active = false, updated_at = CURRENT_TIMESTAMP
         WHERE id = $1 AND (created_by = $2 OR organization_id = $3)
         RETURNING id`,
        [req.params.id, req.user.id, req.user.organizationId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Template not found or access denied' });
      }

      // Log audit
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, resource_id, ip_address)
         VALUES ($1, $2, $3, $4, $5)`,
        [req.user.id, 'delete', 'template', req.params.id, req.ip]
      );

      res.json({ message: 'Template deleted successfully' });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * POST /api/templates/:id/duplicate
 * Create a copy of a template
 */
router.post('/:id/duplicate',
  [
    param('id').isUUID().withMessage('Invalid template ID'),
  ],
  validate,
  async (req, res, next) => {
    try {
      // Get original template
      const original = await dbQuery(
        `SELECT * FROM form_templates
         WHERE id = $1 AND is_active = true
           AND (is_public = true OR organization_id = $2 OR created_by = $3)`,
        [req.params.id, req.user.organizationId, req.user.id]
      );

      if (original.rows.length === 0) {
        return res.status(404).json({ error: 'Template not found' });
      }

      const template = original.rows[0];

      // Create copy
      const result = await dbQuery(
        `INSERT INTO form_templates
         (name, description, category, organization_id, created_by, fields, settings, is_public)
         VALUES ($1, $2, $3, $4, $5, $6, $7, false)
         RETURNING *`,
        [
          `${template.name} (Copy)`,
          template.description,
          template.category,
          req.user.organizationId,
          req.user.id,
          template.fields,
          template.settings
        ]
      );

      res.status(201).json(result.rows[0]);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /api/templates/categories
 * List available template categories
 */
router.get('/meta/categories', async (req, res, next) => {
  try {
    const result = await dbQuery(
      `SELECT DISTINCT category
       FROM form_templates
       WHERE is_active = true
         AND category IS NOT NULL
         AND (is_public = true OR organization_id = $1 OR created_by = $2)
       ORDER BY category`,
      [req.user.organizationId, req.user.id]
    );

    res.json(result.rows.map(r => r.category));
  } catch (error) {
    next(error);
  }
});

module.exports = router;
