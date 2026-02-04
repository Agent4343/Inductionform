/**
 * Database Configuration
 *
 * Uses PostgreSQL with parameterized queries to prevent SQL injection
 */

const { Pool } = require('pg');

// Create connection pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20, // Maximum number of connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Test connection on startup
pool.on('connect', () => {
  console.log('Connected to PostgreSQL database');
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle client', err);
  process.exit(-1);
});

/**
 * Execute a parameterized query
 * ALWAYS use parameterized queries to prevent SQL injection
 *
 * @param {string} text - SQL query with $1, $2, etc. placeholders
 * @param {Array} params - Array of parameter values
 * @returns {Promise} Query result
 */
const query = async (text, params) => {
  const start = Date.now();
  try {
    const res = await pool.query(text, params);
    const duration = Date.now() - start;

    // Log slow queries in development
    if (process.env.NODE_ENV !== 'production' && duration > 100) {
      console.log('Slow query:', { text, duration: `${duration}ms`, rows: res.rowCount });
    }

    return res;
  } catch (error) {
    console.error('Database query error:', error.message);
    throw error;
  }
};

/**
 * Get a client from the pool for transactions
 */
const getClient = async () => {
  const client = await pool.connect();
  const originalQuery = client.query.bind(client);
  const originalRelease = client.release.bind(client);

  // Track query timeout
  const timeout = setTimeout(() => {
    console.error('A client has been checked out for too long!');
  }, 5000);

  client.release = () => {
    clearTimeout(timeout);
    originalRelease();
  };

  client.query = (...args) => {
    return originalQuery(...args);
  };

  return client;
};

module.exports = {
  query,
  getClient,
  pool,
};
