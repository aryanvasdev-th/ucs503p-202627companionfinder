// usersRoutes.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { verifyToken } = require('./authMiddleware');
const {
  getMe,
  updateMe,
  updateEmergencyContact,
  uploadAvatar,
  getPublicProfile,
  searchUsers,
  verifyId,
} = require('./usersController');

router.use(verifyToken);

const avatarsDir = path.join(__dirname, 'uploads', 'avatars');
fs.mkdirSync(avatarsDir, { recursive: true });

const EXT_BY_MIMETYPE = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/heic': '.heic',
  'image/heif': '.heif',
};

const avatarUpload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, avatarsDir),
    filename: (req, file, cb) => {
      cb(null, `${req.userId}-${Date.now()}${EXT_BY_MIMETYPE[file.mimetype] || ''}`);
    },
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (!EXT_BY_MIMETYPE[file.mimetype]) {
      return cb(new Error('Only JPEG, PNG, WEBP, or HEIC images are allowed'));
    }
    cb(null, true);
  },
});

// Wrapped so multer errors (bad file type, too large) come back as JSON
// instead of falling through to Express's default HTML error page.
function handleAvatarUpload(req, res, next) {
  avatarUpload.single('avatar')(req, res, (err) => {
    if (err) {
      return res.status(400).json({ success: false, message: err.message || 'Upload failed' });
    }
    next();
  });
}

// ID photos stay in memory only (never touch the public /uploads folder).
const idVerificationUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 2 },
  fileFilter: (req, file, cb) => {
    if (!EXT_BY_MIMETYPE[file.mimetype]) {
      return cb(new Error('Only JPEG, PNG, WEBP, or HEIC images are allowed'));
    }
    cb(null, true);
  },
});

function handleIdVerificationUpload(req, res, next) {
  idVerificationUpload.fields([
    { name: 'idFront', maxCount: 1 },
    { name: 'idBack', maxCount: 1 },
  ])(req, res, (err) => {
    if (err) {
      return res.status(400).json({ success: false, message: err.message || 'Upload failed' });
    }
    next();
  });
}

router.get('/me', getMe);
router.patch('/me', updateMe);
router.patch('/me/emergency-contact', updateEmergencyContact);
router.post('/me/avatar', handleAvatarUpload, uploadAvatar);
router.post('/me/verify-id', handleIdVerificationUpload, verifyId);
router.get('/search', searchUsers);
router.get('/:id', getPublicProfile);

module.exports = router;
