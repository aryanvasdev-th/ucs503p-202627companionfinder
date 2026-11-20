// adminController.js
// Moderation actions for the app's maker. Every route here sits behind
// requireAdmin (admin.js); admins are set in backend/.env as ADMIN_EMAILS.
const pool = require('./db');
const { createNotification } = require('./notificationsController');
const { isAdminUser } = require('./admin');

const REASON_MAX = 255;

async function banUser(req, res) {
  const userId = Number(req.params.id);
  const reason = typeof req.body.reason === 'string' ? req.body.reason.trim().slice(0, REASON_MAX) : '';
  if (userId === req.userId) {
    return res.status(400).json({ success: false, message: "You can't ban yourself" });
  }
  try {
    if (await isAdminUser(userId)) {
      return res.status(400).json({ success: false, message: "Admins can't be banned" });
    }
    const [result] = await pool.query(
      'UPDATE users SET is_banned = TRUE, ban_reason = ? WHERE id = ?',
      [reason || null, userId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    return res.status(200).json({ success: true, message: 'User banned' });
  } catch (err) {
    console.error('banUser error:', err);
    return res.status(500).json({ success: false, message: 'Server error banning user' });
  }
}

async function unbanUser(req, res) {
  try {
    const [result] = await pool.query(
      'UPDATE users SET is_banned = FALSE, ban_reason = NULL WHERE id = ?',
      [req.params.id]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    return res.status(200).json({ success: true, message: 'User unbanned' });
  } catch (err) {
    console.error('unbanUser error:', err);
    return res.status(500).json({ success: false, message: 'Server error unbanning user' });
  }
}

// Manual override for the red tick, e.g. when a genuine card won't scan.
async function setVerified(req, res) {
  const verified = req.body.verified === true;
  try {
    const [result] = await pool.query(
      `UPDATE users SET id_verification_status = ?, id_verified_at = IF(?, NOW(), NULL) WHERE id = ?`,
      [verified ? 'verified' : 'none', verified, req.params.id]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    if (verified) {
      createNotification(Number(req.params.id), 'id_verified', "You're verified", 'The Companion team verified your Thapar ID.');
    }
    return res.status(200).json({ success: true, message: verified ? 'Verified' : 'Verification removed' });
  } catch (err) {
    console.error('setVerified error:', err);
    return res.status(500).json({ success: false, message: 'Server error updating verification' });
  }
}

async function deleteReview(req, res) {
  try {
    const [rows] = await pool.query(
      `SELECT r.rater_user_id, a.title FROM ratings r JOIN activities a ON a.id = r.activity_id WHERE r.id = ?`,
      [req.params.ratingId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Review not found' });
    }
    await pool.query('DELETE FROM ratings WHERE id = ?', [req.params.ratingId]);
    createNotification(
      rows[0].rater_user_id,
      'review_removed',
      'Review removed',
      `Your review for "${rows[0].title}" was removed by the Companion team for breaking the community guidelines`
    );
    return res.status(200).json({ success: true, message: 'Review removed' });
  } catch (err) {
    console.error('deleteReview error:', err);
    return res.status(500).json({ success: false, message: 'Server error removing review' });
  }
}

// Pin an activity or event to the top of Discover for everyone.
async function setFeatured(req, res) {
  const featured = req.body.featured === true;
  try {
    const [result] = await pool.query('UPDATE activities SET is_featured = ? WHERE id = ?', [featured, req.params.id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Activity not found' });
    }
    return res.status(200).json({ success: true, message: featured ? 'Featured' : 'No longer featured' });
  } catch (err) {
    console.error('setFeatured error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
}

module.exports = { banUser, unbanUser, setVerified, deleteReview, setFeatured };
