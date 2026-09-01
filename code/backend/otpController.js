// otpController.js
const crypto = require('crypto');
const pool = require('./db');
const { sendOtpEmail, sendPasswordResetOtpEmail } = require('./emailService');

const OTP_EXPIRY_MINUTES = 10;
const RESEND_COOLDOWN_SECONDS = 60;

const PURPOSE_VERIFY_EMAIL = 'verify_email';
const PURPOSE_RESET_PASSWORD = 'reset_password';

function generateOtp() {
  // 6-digit numeric OTP, e.g. "042951"
  return crypto.randomInt(0, 1000000).toString().padStart(6, '0');
}

/**
 * Creates a fresh OTP for an email and sends it. `purpose` keeps registration
 * codes and password-reset codes from being interchangeable.
 */
async function createAndSendOtp(email, purpose = PURPOSE_VERIFY_EMAIL) {
  const otp = generateOtp();
  const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

  // invalidate any previous unused OTPs for this email + purpose
  await pool.query('DELETE FROM otp_verifications WHERE email = ? AND purpose = ?', [email, purpose]);

  await pool.query(
    'INSERT INTO otp_verifications (email, otp_code, expires_at, purpose) VALUES (?, ?, ?, ?)',
    [email, otp, expiresAt, purpose]
  );

  if (purpose === PURPOSE_RESET_PASSWORD) {
    await sendPasswordResetOtpEmail(email, otp);
  } else {
    await sendOtpEmail(email, otp);
  }
}

/**
 * Seconds since the last OTP of this purpose was issued for an email, or
 * null if none exists. Used to enforce the resend cooldown.
 */
async function secondsSinceLastOtp(email, purpose) {
  const [existing] = await pool.query(
    'SELECT created_at FROM otp_verifications WHERE email = ? AND purpose = ? ORDER BY created_at DESC LIMIT 1',
    [email, purpose]
  );

  if (existing.length === 0) return null;
  return (Date.now() - new Date(existing[0].created_at).getTime()) / 1000;
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
      'SELECT * FROM otp_verifications WHERE email = ? AND purpose = ? ORDER BY created_at DESC LIMIT 1',
      [email, PURPOSE_VERIFY_EMAIL]
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
    await pool.query('DELETE FROM otp_verifications WHERE email = ? AND purpose = ?', [email, PURPOSE_VERIFY_EMAIL]);

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

    const secondsSinceLast = await secondsSinceLastOtp(email, PURPOSE_VERIFY_EMAIL);
    if (secondsSinceLast !== null && secondsSinceLast < RESEND_COOLDOWN_SECONDS) {
      const wait = Math.ceil(RESEND_COOLDOWN_SECONDS - secondsSinceLast);
      return res.status(429).json({ success: false, message: `Please wait ${wait}s before requesting another OTP` });
    }

    await createAndSendOtp(email, PURPOSE_VERIFY_EMAIL);
    return res.status(200).json({ success: true, message: 'OTP resent' });
  } catch (err) {
    console.error('resendOtp error:', err);
    return res.status(500).json({ success: false, message: 'Server error while resending OTP' });
  }
}

module.exports = {
  createAndSendOtp,
  verifyOtp,
  resendOtp,
  secondsSinceLastOtp,
  RESEND_COOLDOWN_SECONDS,
  PURPOSE_VERIFY_EMAIL,
  PURPOSE_RESET_PASSWORD,
};
