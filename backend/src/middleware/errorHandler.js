/**
 * Global Error Handler
 *
 * Catches all errors and returns consistent responses
 * Hides internal details in production
 */

const errorHandler = (err, req, res, next) => {
  console.error('Error:', err);

  // Default error
  let status = 500;
  let message = 'Internal server error';
  let code = 'INTERNAL_ERROR';

  // Handle specific error types
  if (err.name === 'ValidationError') {
    status = 400;
    message = err.message;
    code = 'VALIDATION_ERROR';
  } else if (err.name === 'UnauthorizedError') {
    status = 401;
    message = 'Invalid token';
    code = 'UNAUTHORIZED';
  } else if (err.code === '23505') {
    // PostgreSQL unique violation
    status = 409;
    message = 'Resource already exists';
    code = 'DUPLICATE_ENTRY';
  } else if (err.code === '23503') {
    // PostgreSQL foreign key violation
    status = 400;
    message = 'Referenced resource not found';
    code = 'FOREIGN_KEY_VIOLATION';
  } else if (err.message === 'Not allowed by CORS') {
    status = 403;
    message = 'CORS not allowed';
    code = 'CORS_ERROR';
  }

  // Send response
  const response = {
    error: message,
    code,
  };

  // Include stack trace in development
  if (process.env.NODE_ENV !== 'production') {
    response.stack = err.stack;
  }

  res.status(status).json(response);
};

module.exports = errorHandler;
