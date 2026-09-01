// authController.js
// Handles user registration + login verification for the Campus Companion Finder app.
// Registration requires OTP email verification before the account can log in.

const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const pool = require('./db'); // your mysql2/promise connection pool
const {
  createAndSendOtp,
  secondsSinceLastOtp,
  RESEND_COOLDOWN_SECONDS,
  PURPOSE_RESET_PASSWORD,
} = require('./otpController');

const JWT_SECRET = process.env.JWT_SECRET; // keep this in .env, never hardcode
const JWT_EXPIRES_IN = '7d';
const SALT_ROUNDS = 10;

// Server-side domain enforcement — never trust the client-side check alone.
const ALLOWED_EMAIL_DOMAIN = '@thapar.edu';

function isCollegeEmail(email) {
  return typeof email === 'string' && email.toLowerCase().endsWith(ALLOWED_EMAIL_DOMAIN);
}

/**
 * REGISTER
 * Creates the account as unverified, sends an OTP, and waits for /verify-otp
 * before the account can be used to log in.
 */
async function registerUser(req, res) {
  try {
    const { email, password, name, gender } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email and password are required' });
    }

    if (!gender || !gender.trim()) {
      return res.status(400).json({ success: false, message: 'Gender is required' });
    }

    if (!isCollegeEmail(email)) {
      return res.status(400).json({ success: false, message: `Email must end with ${ALLOWED_EMAIL_DOMAIN}` });
    }

    const [existing] = await pool.query(
      'SELECT id, is_verified FROM users WHERE email = ?',
      [email]
    );

    if (existing.length > 0) {
      if (existing[0].is_verified) {
        return res.status(409).json({ success: false, message: 'An account with this email already exists' });
      }
      // account exists but was never verified — let them retry, just resend an OTP
      await createAndSendOtp(email);
      return res.status(200).json({
        success: true,
        message: 'Account already pending verification. A new OTP has been sent.',
      });
    }

    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);

    await pool.query(
      'INSERT INTO users (email, password_hash, name, gender, is_verified) VALUES (?, ?, ?, ?, FALSE)',
      [email, hashedPassword, name || null, gender.trim()]
    );

    await createAndSendOtp(email);

    return res.status(201).json({
      success: true,
      message: 'Account created. Please check your email for a verification code.',
    });
  } catch (err) {
    console.error('registerUser error:', err);
    return res.status(500).json({ success: false, message: 'Server error during registration' });
  }
}

/**
 * LOGIN
 * Verifies email + password, blocks unverified accounts, returns a JWT if valid.
 */
async function loginUser(req, res) {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email and password are required' });
    }

    const [rows] = await pool.query(
      'SELECT id, email, password_hash, is_verified FROM users WHERE email = ?',
      [email]
    );

    // generic message either way — don't reveal whether the email exists
    if (rows.length === 0) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    const user = rows[0];
    const isMatch = await bcrypt.compare(password, user.password_hash);

    if (!isMatch) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    if (!user.is_verified) {
      // resend an OTP so they can immediately finish verification
      await createAndSendOtp(user.email);
      return res.status(403).json({
        success: false,
        message: 'Email not verified. A new OTP has been sent to your email.',
        requiresVerification: true,
      });
    }

    const token = jwt.sign(
      { userId: user.id, email: user.email },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    return res.status(200).json({
      success: true,
      message: 'Login successful',
      token,
      user: { id: user.id, email: user.email },
    });
  } catch (err) {
    console.error('loginUser error:', err);
    return res.status(500).json({ success: false, message: 'Server error during login' });
  }
}

/**
 * FORGOT PASSWORD
 * Sends a password-reset OTP if the email belongs to a verified account.
 * Response is identical either way so the endpoint can't be used to test
 * which emails have accounts.
 */
async function forgotPassword(req, res) {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ success: false, message: 'Email is required' });
    }

    const [rows] = await pool.query(
      'SELECT id, is_verified FROM users WHERE email = ?',
      [email]
    );

    if (rows.length > 0 && rows[0].is_verified) {
      const secondsSinceLast = await secondsSinceLastOtp(email, PURPOSE_RESET_PASSWORD);
      if (secondsSinceLast === null || secondsSinceLast >= RESEND_COOLDOWN_SECONDS) {
        await createAndSendOtp(email, PURPOSE_RESET_PASSWORD);
      }
    }

    return res.status(200).json({
      success: true,
      message: 'If an account exists for that email, a password reset code has been sent.',
    });
  } catch (err) {
    console.error('forgotPassword error:', err);
    return res.status(500).json({ success: false, message: 'Server error while requesting password reset' });
  }
}

/**
 * RESET PASSWORD
 * Verifies the reset OTP and sets a new password.
 */
async function resetPassword(req, res) {
  try {
    const { email, otp, newPassword } = req.body;

    if (!email || !otp || !newPassword) {
      return res.status(400).json({ success: false, message: 'Email, OTP, and new password are required' });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({ success: false, message: 'Password must be at least 8 characters' });
    }

    const [rows] = await pool.query(
      'SELECT * FROM otp_verifications WHERE email = ? AND purpose = ? ORDER BY created_at DESC LIMIT 1',
      [email, PURPOSE_RESET_PASSWORD]
    );

    if (rows.length === 0) {
      return res.status(400).json({ success: false, message: 'No reset code found for this email. Please request a new one.' });
    }

    const record = rows[0];

    if (new Date(record.expires_at) < new Date()) {
      return res.status(400).json({ success: false, message: 'Reset code has expired. Please request a new one.' });
    }

    if (record.otp_code !== otp) {
      return res.status(400).json({ success: false, message: 'Incorrect reset code' });
    }

    const hashedPassword = await bcrypt.hash(newPassword, SALT_ROUNDS);
    await pool.query('UPDATE users SET password_hash = ? WHERE email = ?', [hashedPassword, email]);
    await pool.query('DELETE FROM otp_verifications WHERE email = ? AND purpose = ?', [email, PURPOSE_RESET_PASSWORD]);

    return res.status(200).json({ success: true, message: 'Password reset successfully' });
  } catch (err) {
    console.error('resetPassword error:', err);
    return res.status(500).json({ success: false, message: 'Server error during password reset' });
  }
}

module.exports = { registerUser, loginUser, forgotPassword, resetPassword };
