// otpController.js
const crypto = require('crypto');
const pool = require('./db');
const { sendOtpEmail } = require('./emailService');

const OTP_EXPIRY_MINUTES = 10;
const RESEND_COOLDOWN_SECONDS = 60;

function generateOtp() {
  // 6-digit numeric OTP, e.g. "042951"
  return crypto.randomInt(0, 1000000).toString().padStart(6, '0');
}

/**
 * Creates a fresh OTP for an email and sends it.
 * Reused by both the register flow and the "resend OTP" endpoint.
 */
async function createAndSendOtp(email) {
  const otp = generateOtp();
  const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

  // invalidate any previous unused OTPs for this email
  await pool.query('DELETE FROM otp_verifications WHERE email = ?', [email]);

  await pool.query(
    'INSERT INTO otp_verifications (email, otp_code, expires_at) VALUES (?, ?, ?)',
    [email, otp, expiresAt]
  );

  await sendOtpEmail(email, otp);
}

/**
 * POST /api/auth/verify-otp
 * body: { email, otp }
 */
async function verifyOtp(req, res) {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({ success: false, message: 'Email and OTP are required' });
    }

    const [rows] = await pool.query(
      'SELECT * FROM otp_verifications WHERE email = ? ORDER BY created_at DESC LIMIT 1',
      [email]
    );

    if (rows.length === 0) {
      return res.status(400).json({ success: false, message: 'No OTP found for this email. Please request a new one.' });
    }

    const record = rows[0];

    if (new Date(record.expires_at) < new Date()) {
      return res.status(400).json({ success: false, message: 'OTP has expired. Please request a new one.' });
    }

    if (record.otp_code !== otp) {
      return res.status(400).json({ success: false, message: 'Incorrect OTP' });
    }

    // mark user verified, clean up OTP row
    await pool.query('UPDATE users SET is_verified = TRUE WHERE email = ?', [email]);
    await pool.query('DELETE FROM otp_verifications WHERE email = ?', [email]);

    return res.status(200).json({ success: true, message: 'Email verified successfully' });
  } catch (err) {
    console.error('verifyOtp error:', err);
    return res.status(500).json({ success: false, message: 'Server error during OTP verification' });
  }
}

/**
 * POST /api/auth/resend-otp
 * body: { email }
 */
async function resendOtp(req, res) {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ success: false, message: 'Email is required' });
    }

    const [existing] = await pool.query(
      'SELECT created_at FROM otp_verifications WHERE email = ? ORDER BY created_at DESC LIMIT 1',
      [email]
    );

    if (existing.length > 0) {
      const secondsSinceLast = (Date.now() - new Date(existing[0].created_at).getTime()) / 1000;
      if (secondsSinceLast < RESEND_COOLDOWN_SECONDS) {
        const wait = Math.ceil(RESEND_COOLDOWN_SECONDS - secondsSinceLast);
        return res.status(429).json({ success: false, message: `Please wait ${wait}s before requesting another OTP` });
      }
    }

    await createAndSendOtp(email);
    return res.status(200).json({ success: true, message: 'OTP resent' });
  } catch (err) {
    console.error('resendOtp error:', err);
    return res.status(500).json({ success: false, message: 'Server error while resending OTP' });
  }
}

module.exports = { createAndSendOtp, verifyOtp, resendOtp };
