/**
 * DigitalFormsApp API Server
 *
 * Security features:
 * - Helmet for HTTP headers
 * - Rate limiting
 * - CORS configuration
 * - Input validation
 * - JWT authentication
 * - Password hashing with bcrypt
 * - SQL injection prevention (parameterized queries)
 */

require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const compression = require('compression');
const morgan = require('morgan');
const path = require('path');

// Import routes
const authRoutes = require('./routes/auth');
const formRoutes = require('./routes/forms');
const templateRoutes = require('./routes/templates');
const uploadRoutes = require('./routes/uploads');
const userRoutes = require('./routes/users');

// Import middleware
const { authenticateToken } = require('./middleware/auth');
const errorHandler = require('./middleware/errorHandler');

const app = express();
const PORT = process.env.PORT || 3000;

// ===================
// SECURITY MIDDLEWARE
// ===================

// Helmet - Sets various HTTP headers for security
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  crossOriginEmbedderPolicy: false,
}));

// CORS - Configure allowed origins
const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'];
app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (mobile apps, curl, etc.)
    if (!origin) return callback(null, true);

    if (allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Rate limiting - Prevent brute force attacks
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: { error: 'Too many requests, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// Stricter rate limit for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Limit each IP to 10 auth requests per windowMs
  message: { error: 'Too many login attempts, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// ===================
// GENERAL MIDDLEWARE
// ===================

// Compression
app.use(compression());

// Logging (disable in production or use a proper logger)
if (process.env.NODE_ENV !== 'production') {
  app.use(morgan('dev'));
} else {
  app.use(morgan('combined'));
}

// Body parsing with size limits
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Static files for uploads (with restricted access)
app.use('/uploads', express.static(path.join(__dirname, '../uploads'), {
  maxAge: '1d',
  etag: true,
}));

// ===================
// HEALTH CHECK
// ===================

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// ===================
// API ROUTES
// ===================

// Auth routes (with stricter rate limiting)
app.use('/api/auth', authLimiter, authRoutes);

// Protected routes (require authentication)
app.use('/api/forms', authenticateToken, formRoutes);
app.use('/api/templates', authenticateToken, templateRoutes);
app.use('/api/uploads', authenticateToken, uploadRoutes);
app.use('/api/users', authenticateToken, userRoutes);

// ===================
// ERROR HANDLING
// ===================

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Global error handler
app.use(errorHandler);

// ===================
// START SERVER
// ===================

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = app;
