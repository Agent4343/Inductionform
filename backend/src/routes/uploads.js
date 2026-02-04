/**
 * File Upload Routes
 *
 * Secure file handling for signatures, photos, and attachments
 * - File type validation
 * - Size limits
 * - Malware scanning considerations
 * - Secure file naming
 */

const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const path = require('path');
const fs = require('fs').promises;
const crypto = require('crypto');
const { param, validationResult } = require('express-validator');
const { query: dbQuery } = require('../config/database');

const router = express.Router();

// ===================
// CONFIGURATION
// ===================

// Allowed file types (MIME types)
const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];
const ALLOWED_DOC_TYPES = ['application/pdf'];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
const MAX_IMAGE_DIMENSION = 4096;
const THUMBNAIL_SIZE = 200;

// Upload directory
const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(__dirname, '../../uploads');

// Ensure upload directories exist
const ensureDirectories = async () => {
  const dirs = ['photos', 'signatures', 'documents', 'thumbnails'];
  for (const dir of dirs) {
    await fs.mkdir(path.join(UPLOAD_DIR, dir), { recursive: true });
  }
};
ensureDirectories();

// ===================
// MULTER CONFIGURATION
// ===================

// Generate secure filename
const generateSecureFilename = (originalname) => {
  const ext = path.extname(originalname).toLowerCase();
  const timestamp = Date.now();
  const randomBytes = crypto.randomBytes(16).toString('hex');
  return `${timestamp}-${randomBytes}${ext}`;
};

// File filter
const fileFilter = (allowedTypes) => (req, file, cb) => {
  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error(`Invalid file type. Allowed: ${allowedTypes.join(', ')}`), false);
  }
};

// Memory storage for processing before saving
const storage = multer.memoryStorage();

// Image upload middleware
const uploadImage = multer({
  storage,
  limits: {
    fileSize: MAX_FILE_SIZE,
    files: 1,
  },
  fileFilter: fileFilter([...ALLOWED_IMAGE_TYPES]),
});

// Document upload middleware
const uploadDocument = multer({
  storage,
  limits: {
    fileSize: MAX_FILE_SIZE,
    files: 1,
  },
  fileFilter: fileFilter([...ALLOWED_IMAGE_TYPES, ...ALLOWED_DOC_TYPES]),
});

// ===================
// HELPER FUNCTIONS
// ===================

/**
 * Process and save image with security checks
 */
const processAndSaveImage = async (buffer, subdir, options = {}) => {
  const filename = generateSecureFilename('image.jpg');
  const filepath = path.join(UPLOAD_DIR, subdir, filename);
  const thumbnailPath = path.join(UPLOAD_DIR, 'thumbnails', filename);

  // Use sharp to validate and process image
  // This also strips EXIF data (except orientation) for privacy
  const image = sharp(buffer);
  const metadata = await image.metadata();

  // Validate dimensions
  if (metadata.width > MAX_IMAGE_DIMENSION || metadata.height > MAX_IMAGE_DIMENSION) {
    throw new Error(`Image dimensions exceed maximum of ${MAX_IMAGE_DIMENSION}px`);
  }

  // Process main image - convert to JPEG, strip metadata
  await image
    .rotate() // Auto-rotate based on EXIF
    .jpeg({
      quality: options.quality || 85,
      progressive: true,
    })
    .toFile(filepath);

  // Create thumbnail
  await sharp(buffer)
    .rotate()
    .resize(THUMBNAIL_SIZE, THUMBNAIL_SIZE, {
      fit: 'cover',
      position: 'centre',
    })
    .jpeg({ quality: 70 })
    .toFile(thumbnailPath);

  // Get final file size
  const stats = await fs.stat(filepath);

  return {
    filename,
    filepath: `/${subdir}/${filename}`,
    thumbnailPath: `/thumbnails/${filename}`,
    size: stats.size,
    width: metadata.width,
    height: metadata.height,
  };
};

/**
 * Save signature data (base64 or raw)
 */
const saveSignature = async (signatureData, format = 'png') => {
  const filename = generateSecureFilename(`signature.${format}`);
  const filepath = path.join(UPLOAD_DIR, 'signatures', filename);

  // If base64, decode it
  let buffer;
  if (typeof signatureData === 'string' && signatureData.includes('base64')) {
    const base64Data = signatureData.replace(/^data:image\/\w+;base64,/, '');
    buffer = Buffer.from(base64Data, 'base64');
  } else {
    buffer = signatureData;
  }

  // Process with sharp to validate it's a real image
  await sharp(buffer)
    .png()
    .toFile(filepath);

  const stats = await fs.stat(filepath);

  return {
    filename,
    filepath: `/signatures/${filename}`,
    size: stats.size,
  };
};

// ===================
// VALIDATION MIDDLEWARE
// ===================

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

// ===================
// ROUTES
// ===================

/**
 * POST /api/uploads/photo
 * Upload a photo attachment
 */
router.post('/photo',
  uploadImage.single('photo'),
  async (req, res, next) => {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'No photo provided' });
      }

      const result = await processAndSaveImage(req.file.buffer, 'photos');

      // Log upload
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, new_values, ip_address)
         VALUES ($1, $2, $3, $4, $5)`,
        [req.user.id, 'upload', 'photo', JSON.stringify({ filename: result.filename }), req.ip]
      );

      res.status(201).json({
        message: 'Photo uploaded successfully',
        url: result.filepath,
        thumbnailUrl: result.thumbnailPath,
        size: result.size,
        dimensions: {
          width: result.width,
          height: result.height,
        },
      });
    } catch (error) {
      // Clean up on error
      next(error);
    }
  }
);

/**
 * POST /api/uploads/signature
 * Upload a signature image
 */
router.post('/signature',
  uploadImage.single('signature'),
  async (req, res, next) => {
    try {
      let result;

      // Support both file upload and base64
      if (req.file) {
        result = await processAndSaveImage(req.file.buffer, 'signatures', { quality: 90 });
      } else if (req.body.signatureData) {
        result = await saveSignature(req.body.signatureData);
      } else {
        return res.status(400).json({ error: 'No signature provided' });
      }

      // Log upload
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, new_values, ip_address)
         VALUES ($1, $2, $3, $4, $5)`,
        [req.user.id, 'upload', 'signature', JSON.stringify({ filename: result.filename }), req.ip]
      );

      res.status(201).json({
        message: 'Signature uploaded successfully',
        url: result.filepath,
        size: result.size,
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * POST /api/uploads/document
 * Upload a document (PDF or image)
 */
router.post('/document',
  uploadDocument.single('document'),
  async (req, res, next) => {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'No document provided' });
      }

      let result;

      if (req.file.mimetype === 'application/pdf') {
        // Save PDF directly (already validated by multer)
        const filename = generateSecureFilename('document.pdf');
        const filepath = path.join(UPLOAD_DIR, 'documents', filename);

        await fs.writeFile(filepath, req.file.buffer);
        const stats = await fs.stat(filepath);

        result = {
          filename,
          filepath: `/documents/${filename}`,
          size: stats.size,
          type: 'pdf',
        };
      } else {
        // Process as image
        result = await processAndSaveImage(req.file.buffer, 'documents');
        result.type = 'image';
      }

      // Log upload
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, new_values, ip_address)
         VALUES ($1, $2, $3, $4, $5)`,
        [req.user.id, 'upload', 'document', JSON.stringify({ filename: result.filename, type: result.type }), req.ip]
      );

      res.status(201).json({
        message: 'Document uploaded successfully',
        url: result.filepath,
        thumbnailUrl: result.thumbnailPath,
        size: result.size,
        type: result.type,
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * POST /api/uploads/form/:formId/attachment
 * Upload attachment for a specific form
 */
router.post('/form/:formId/attachment',
  [
    param('formId').isUUID().withMessage('Invalid form ID'),
  ],
  validate,
  uploadDocument.single('file'),
  async (req, res, next) => {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'No file provided' });
      }

      // Verify form access
      const form = await dbQuery(
        `SELECT id FROM forms
         WHERE id = $1
           AND (created_by = $2 OR assigned_to = $2 OR organization_id = $3)`,
        [req.params.formId, req.user.id, req.user.organizationId]
      );

      if (form.rows.length === 0) {
        return res.status(404).json({ error: 'Form not found or access denied' });
      }

      // Process file
      let fileResult;
      if (req.file.mimetype === 'application/pdf') {
        const filename = generateSecureFilename('attachment.pdf');
        const filepath = path.join(UPLOAD_DIR, 'documents', filename);
        await fs.writeFile(filepath, req.file.buffer);
        const stats = await fs.stat(filepath);
        fileResult = {
          filepath: `/documents/${filename}`,
          size: stats.size,
        };
      } else {
        fileResult = await processAndSaveImage(req.file.buffer, 'photos');
      }

      // Save to database
      const result = await dbQuery(
        `INSERT INTO form_attachments
         (form_id, field_id, file_name, file_type, file_size, file_url, thumbnail_url, uploaded_by, latitude, longitude)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         RETURNING *`,
        [
          req.params.formId,
          req.body.fieldId || null,
          req.file.originalname,
          req.file.mimetype,
          fileResult.size,
          fileResult.filepath,
          fileResult.thumbnailPath || null,
          req.user.id,
          req.body.latitude || null,
          req.body.longitude || null,
        ]
      );

      res.status(201).json({
        message: 'Attachment uploaded successfully',
        attachment: result.rows[0],
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * DELETE /api/uploads/:type/:filename
 * Delete an uploaded file (owner only)
 */
router.delete('/:type/:filename',
  async (req, res, next) => {
    try {
      const { type, filename } = req.params;

      // Validate type
      const allowedTypes = ['photos', 'signatures', 'documents'];
      if (!allowedTypes.includes(type)) {
        return res.status(400).json({ error: 'Invalid file type' });
      }

      // Validate filename (prevent path traversal)
      if (filename.includes('..') || filename.includes('/') || filename.includes('\\')) {
        return res.status(400).json({ error: 'Invalid filename' });
      }

      // Check if file exists in database and user owns it
      const attachment = await dbQuery(
        `SELECT fa.*, f.created_by as form_owner
         FROM form_attachments fa
         JOIN forms f ON fa.form_id = f.id
         WHERE fa.file_url LIKE $1
           AND (f.created_by = $2 OR fa.uploaded_by = $2)`,
        [`%/${filename}`, req.user.id]
      );

      if (attachment.rows.length === 0) {
        return res.status(404).json({ error: 'File not found or access denied' });
      }

      // Delete files
      const filepath = path.join(UPLOAD_DIR, type, filename);
      const thumbnailPath = path.join(UPLOAD_DIR, 'thumbnails', filename);

      await fs.unlink(filepath).catch(() => {}); // Ignore if already deleted
      await fs.unlink(thumbnailPath).catch(() => {}); // Thumbnail might not exist

      // Remove from database
      await dbQuery(
        'DELETE FROM form_attachments WHERE id = $1',
        [attachment.rows[0].id]
      );

      // Log deletion
      await dbQuery(
        `INSERT INTO audit_logs (user_id, action, resource_type, old_values, ip_address)
         VALUES ($1, $2, $3, $4, $5)`,
        [req.user.id, 'delete', 'attachment', JSON.stringify({ filename }), req.ip]
      );

      res.json({ message: 'File deleted successfully' });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /api/uploads/form/:formId
 * List attachments for a form
 */
router.get('/form/:formId',
  [
    param('formId').isUUID().withMessage('Invalid form ID'),
  ],
  validate,
  async (req, res, next) => {
    try {
      // Verify form access
      const form = await dbQuery(
        `SELECT id FROM forms
         WHERE id = $1
           AND (created_by = $2 OR assigned_to = $2 OR organization_id = $3)`,
        [req.params.formId, req.user.id, req.user.organizationId]
      );

      if (form.rows.length === 0) {
        return res.status(404).json({ error: 'Form not found or access denied' });
      }

      const attachments = await dbQuery(
        `SELECT fa.*, u.name as uploaded_by_name
         FROM form_attachments fa
         LEFT JOIN users u ON fa.uploaded_by = u.id
         WHERE fa.form_id = $1
         ORDER BY fa.created_at DESC`,
        [req.params.formId]
      );

      res.json(attachments.rows);
    } catch (error) {
      next(error);
    }
  }
);

// Error handler for multer
router.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        error: `File too large. Maximum size is ${MAX_FILE_SIZE / 1024 / 1024}MB`
      });
    }
    return res.status(400).json({ error: error.message });
  }
  next(error);
});

module.exports = router;
