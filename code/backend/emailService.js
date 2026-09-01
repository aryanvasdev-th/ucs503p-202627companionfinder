// emailService.js
// Handles sending emails (OTP verification) via nodemailer.
// Uses SMTP credentials from environment variables — never hardcode these.

const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: process.env.EMAIL_HOST,       // e.g. smtp.gmail.com
  port: process.env.EMAIL_PORT || 587,
  secure: false,                      // true for port 465, false for 587
  auth: {
    user: process.env.EMAIL_USER,     // your sending address
    pass: process.env.EMAIL_PASS,     // app password, NOT your real account password
  },
});

async function sendOtpEmail(toEmail, otp) {
  const mailOptions = {
    from: `"Campus Companion" <${process.env.EMAIL_USER}>`,
    to: toEmail,
    subject: 'Your Campus Companion verification code',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto;">
        <h2>Verify your email</h2>
        <p>Use the code below to verify your Campus Companion account. It expires in 10 minutes.</p>
        <div style="font-size: 32px; font-weight: bold; letter-spacing: 6px; margin: 20px 0;">
          ${otp}
        </div>
        <p>If you didn't request this, you can safely ignore this email.</p>
      </div>
    `,
  };

  await transporter.sendMail(mailOptions);
}

async function sendPasswordResetOtpEmail(toEmail, otp) {
  const mailOptions = {
    from: `"Campus Companion" <${process.env.EMAIL_USER}>`,
    to: toEmail,
    subject: 'Your Campus Companion password reset code',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto;">
        <h2>Reset your password</h2>
        <p>Use the code below to reset your Campus Companion password. It expires in 10 minutes.</p>
        <div style="font-size: 32px; font-weight: bold; letter-spacing: 6px; margin: 20px 0;">
          ${otp}
        </div>
        <p>If you didn't request this, you can safely ignore this email — your password won't change.</p>
      </div>
    `,
  };

  await transporter.sendMail(mailOptions);
}

module.exports = { sendOtpEmail, sendPasswordResetOtpEmail };
