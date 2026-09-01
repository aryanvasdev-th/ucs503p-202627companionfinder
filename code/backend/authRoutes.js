// authRoutes.js
const express = require('express');
const router = express.Router();
const { registerUser, loginUser, forgotPassword, resetPassword } = require('./authController');
const { verifyOtp, resendOtp } = require('./otpController');

router.post('/register', registerUser);
router.post('/verify-otp', verifyOtp);
router.post('/resend-otp', resendOtp);
router.post('/login', loginUser);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);

module.exports = router;

// In your main app.js / server.js:
// const authRoutes = require('./authRoutes');
// app.use('/api/auth', authRoutes);
