const mysql = require('mysql2/promise');
const config = require('./config');

const pool = mysql.createPool(config.db);

/** Helper : requête préparée (anti-injection par construction). */
async function q(sql, params = []) {
  const [rows] = await pool.execute(sql, params);
  return rows;
}

module.exports = { pool, q };
