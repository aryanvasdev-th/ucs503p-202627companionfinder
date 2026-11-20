// adminRoutes.js
const express = require('express');
const router = express.Router();
const { verifyToken } = require('./authMiddleware');
const { requireAdmin } = require('./admin');
const { banUser, unbanUser, setVerified, deleteReview, setFeatured } = require('./adminController');

router.use(verifyToken, requireAdmin);

router.post('/users/:id/ban', banUser);
router.post('/users/:id/unban', unbanUser);
router.post('/users/:id/verification', setVerified);
router.delete('/reviews/:ratingId', deleteReview);
router.post('/activities/:id/featured', setFeatured);
// Deleting any activity reuses DELETE /api/activities/:id, which lets
// admins through as well as the host.

module.exports = router;
