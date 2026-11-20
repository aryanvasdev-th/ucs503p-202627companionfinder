// authMiddleware.js
const jwt = require('jsonwebtoken');
const pool = require('./db');

const JWT_SECRET = process.env.JWT_SECRET;

// Checks the token, then that the account hasn't been banned since it was
// issued — so a ban takes effect immediately, not when the token expires.
async function verifyToken(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: 'Missing or invalid Authorization header' });
  }

  const token = header.slice('Bearer '.length);

  let payload;
  try {
    payload = jwt.verify(token, JWT_SECRET);
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }

  try {
    const [rows] = await pool.query('SELECT is_banned, ban_reason FROM users WHERE id = ?', [payload.userId]);
    if (rows.length === 0) {
      return res.status(401).json({ success: false, message: 'Account not found' });
    }
    if (rows[0].is_banned) {
      return res.status(403).json({
        success: false,
        banned: true,
        message: `Your account has been suspended${rows[0].ban_reason ? `: ${rows[0].ban_reason}` : '.'}`,
      });
    }
  } catch (err) {
    console.error('verifyToken ban check error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }

  req.userId = payload.userId;
  req.userEmail = payload.email;
  next();
}

module.exports = { verifyToken };
