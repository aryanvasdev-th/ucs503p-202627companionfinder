// usersController.js
const pool = require('./db');
const { convertHeicIfNeeded } = require('./imageService');

async function getMe(req, res) {
  try {
    const [rows] = await pool.query(
      `SELECT id, email, name, bio, avatar_url, gender, emergency_contact_name, emergency_contact_phone
       FROM users WHERE id = ?`,
      [req.userId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    return res.status(200).json({ success: true, user: rows[0] });
  } catch (err) {
    console.error('getMe error:', err);
    return res.status(500).json({ success: false, message: 'Server error fetching profile' });
  }
}

async function updateMe(req, res) {
  try {
    const { name, bio, avatarUrl, gender } = req.body;
    await pool.query(
      'UPDATE users SET name = COALESCE(?, name), bio = COALESCE(?, bio), avatar_url = COALESCE(?, avatar_url), gender = COALESCE(?, gender) WHERE id = ?',
      [name ?? null, bio ?? null, avatarUrl ?? null, gender ?? null, req.userId]
    );
    return res.status(200).json({ success: true, message: 'Profile updated' });
  } catch (err) {
    console.error('updateMe error:', err);
    return res.status(500).json({ success: false, message: 'Server error updating profile' });
  }
}

async function updateEmergencyContact(req, res) {
  try {
    const { name, phone } = req.body;
    if (!name || !phone) {
      return res.status(400).json({ success: false, message: 'name and phone are required' });
    }
    await pool.query(
      'UPDATE users SET emergency_contact_name = ?, emergency_contact_phone = ? WHERE id = ?',
      [name, phone, req.userId]
    );
    return res.status(200).json({ success: true, message: 'Emergency contact updated' });
  } catch (err) {
    console.error('updateEmergencyContact error:', err);
    return res.status(500).json({ success: false, message: 'Server error updating emergency contact' });
  }
}

async function uploadAvatar(req, res) {
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'No image file provided' });
  }
  try {
    const filename = await convertHeicIfNeeded(req.file.path);
    const avatarUrl = `/uploads/avatars/${filename}`;
    await pool.query('UPDATE users SET avatar_url = ? WHERE id = ?', [avatarUrl, req.userId]);
    return res.status(200).json({ success: true, avatarUrl });
  } catch (err) {
    console.error('uploadAvatar error:', err);
    return res.status(500).json({ success: false, message: 'Server error uploading avatar' });
  }
}

module.exports = { getMe, updateMe, updateEmergencyContact, uploadAvatar };
