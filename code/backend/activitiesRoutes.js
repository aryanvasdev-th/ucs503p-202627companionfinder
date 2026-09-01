// activitiesRoutes.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { verifyToken } = require('./authMiddleware');
const {
  createActivity,
  listActivities,
  getActivity,
  requestJoin,
  cancelJoinRequest,
  listJoinRequests,
  acceptJoinRequest,
  declineJoinRequest,
  leaveActivity,
  deleteActivity,
  uploadActivityBanner,
  rateParticipant,
  myActivities,
} = require('./activitiesController');

router.use(verifyToken);

const bannersDir = path.join(__dirname, 'uploads', 'activity-banners');
fs.mkdirSync(bannersDir, { recursive: true });

const EXT_BY_MIMETYPE = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/heic': '.heic',
  'image/heif': '.heif',
};

const bannerUpload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, bannersDir),
    filename: (req, file, cb) => {
      cb(null, `${req.params.id}-${Date.now()}${EXT_BY_MIMETYPE[file.mimetype] || ''}`);
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
function handleBannerUpload(req, res, next) {
  bannerUpload.single('banner')(req, res, (err) => {
    if (err) {
      return res.status(400).json({ success: false, message: err.message || 'Upload failed' });
    }
    next();
  });
}

router.post('/', createActivity);
router.get('/', listActivities);
router.get('/mine', myActivities);
router.get('/:id', getActivity);
router.post('/:id/request-join', requestJoin);
router.delete('/:id/request-join', cancelJoinRequest);
router.get('/:id/requests', listJoinRequests);
router.post('/:id/requests/:requestId/accept', acceptJoinRequest);
router.post('/:id/requests/:requestId/decline', declineJoinRequest);
router.delete('/:id/join', leaveActivity);
router.delete('/:id', deleteActivity);
router.post('/:id/banner', handleBannerUpload, uploadActivityBanner);
router.post('/:id/rate', rateParticipant);

module.exports = router;
