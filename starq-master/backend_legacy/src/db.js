const { Pool } = require('pg');

function createPool() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    throw new Error('DATABASE_URL is required');
  }
  return new Pool({ connectionString: url, max: 10 });
}

module.exports = { createPool };
