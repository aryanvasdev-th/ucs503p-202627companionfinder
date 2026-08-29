// sosController.js
const pool = require('./db');
const { sendSosSms } = require('./smsService');
const { findActiveActivityForUser, getCompanionNames } = require('./activitiesController');

async function triggerSos(req, res) {
  try {
    const { latitude, longitude } = req.body;
    if (latitude === undefined || longitude === undefined) {
      return res.status(400).json({ success: false, message: 'latitude and longitude are required' });
    }

    const [userRows] = await pool.query(
      'SELECT name, email, emergency_contact_name, emergency_contact_phone FROM users WHERE id = ?',
      [req.userId]
    );
    const user = userRows[0];

    if (!user || !user.emergency_contact_phone) {
      return res.status(400).json({
        success: false,
        message: 'Add an emergency contact phone number in your profile before using SOS',
      });
    }

    const activeActivity = await findActiveActivityForUser(req.userId);
    const companions = activeActivity
      ? await getCompanionNames(activeActivity.id, req.userId)
      : [];

    await sendSosSms(user.emergency_contact_phone, {
      userName: user.name || user.email,
      latitude,
      longitude,
      companions,
    });

    await pool.query(
      `INSERT INTO sos_alerts (user_id, activity_id, latitude, longitude, notified_contact_phone)
       VALUES (?, ?, ?, ?, ?)`,
      [req.userId, activeActivity ? activeActivity.id : null, latitude, longitude, user.emergency_contact_phone]
    );

    return res.status(200).json({ success: true, message: 'Emergency contact notified' });
  } catch (err) {
    console.error('triggerSos error:', err);
    return res.status(500).json({ success: false, message: 'Server error triggering SOS' });
  }
}

module.exports = { triggerSos };
