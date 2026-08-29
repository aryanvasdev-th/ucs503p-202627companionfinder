// notificationsController.js
const pool = require('./db');

// Called by other controllers when something notification-worthy happens.
// Best-effort — callers should not let a failure here break the main flow.
async function createNotification(userId, type, title, body, activityId = null) {
  try {
    await pool.query(
      'INSERT INTO notifications (user_id, type, title, body, activity_id) VALUES (?, ?, ?, ?, ?)',
      [userId, type, title, body || null, activityId]
    );
  } catch (err) {
    console.error('createNotification error:', err);
  }
}

async function listNotifications(req, res) {
  try {
    const [rows] = await pool.query(
      `SELECT id, type, title, body, activity_id, read_at, created_at
       FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 50`,
      [req.userId]
    );
    return res.status(200).json({
      success: true,
      notifications: rows.map((r) => ({
        id: r.id,
        type: r.type,
        title: r.title,
        body: r.body,
        activityId: r.activity_id,
        read: r.read_at !== null,
        createdAt: r.created_at,
      })),
    });
  } catch (err) {
    console.error('listNotifications error:', err);
    return res.status(500).json({ success: false, message: 'Server error listing notifications' });
  }
}

async function markRead(req, res) {
  try {
    await pool.query(
      'UPDATE notifications SET read_at = NOW() WHERE id = ? AND user_id = ? AND read_at IS NULL',
      [req.params.id, req.userId]
    );
    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('markRead error:', err);
    return res.status(500).json({ success: false, message: 'Server error updating notification' });
  }
}

async function markAllRead(req, res) {
  try {
    await pool.query(
      'UPDATE notifications SET read_at = NOW() WHERE user_id = ? AND read_at IS NULL',
      [req.userId]
    );
    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('markAllRead error:', err);
    return res.status(500).json({ success: false, message: 'Server error updating notifications' });
  }
}

module.exports = { createNotification, listNotifications, markRead, markAllRead };
