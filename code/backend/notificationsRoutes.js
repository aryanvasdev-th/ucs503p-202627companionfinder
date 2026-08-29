// notificationsRoutes.js
const express = require('express');
const router = express.Router();
const { verifyToken } = require('./authMiddleware');
const { listNotifications, markRead, markAllRead } = require('./notificationsController');

router.use(verifyToken);

router.get('/', listNotifications);
router.patch('/:id/read', markRead);
router.post('/read-all', markAllRead);

module.exports = router;
