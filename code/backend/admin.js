// admin.js
// The app's maker gets moderation powers. Who counts as admin is set only
// in backend/.env (ADMIN_EMAILS, comma-separated), never from the app, so
// nobody can grant themselves admin by editing a request.
const pool = require('./db');

function adminEmails() {
  return (process.env.ADMIN_EMAILS || '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
}

function isAdminEmail(email) {
  return !!email && adminEmails().includes(String(email).toLowerCase());
}

async function isAdminUser(userId) {
  const [rows] = await pool.query('SELECT email FROM users WHERE id = ?', [userId]);
  return rows.length > 0 && isAdminEmail(rows[0].email);
}

// Route guard: 403 unless the logged-in user is an admin.
async function requireAdmin(req, res, next) {
  try {
    if (await isAdminUser(req.userId)) return next();
    return res.status(403).json({ success: false, message: 'Admins only' });
  } catch (err) {
    console.error('requireAdmin error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
}

module.exports = { isAdminEmail, isAdminUser, requireAdmin };
