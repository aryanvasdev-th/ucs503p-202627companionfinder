// conversationsRoutes.js
const express = require('express');
const router = express.Router();
const { verifyToken } = require('./authMiddleware');
const { listConversations, getMessages, startDirectConversation } = require('./conversationsController');

router.use(verifyToken);

router.get('/', listConversations);
router.get('/:id/messages', getMessages);
router.post('/dm', startDirectConversation);

module.exports = router;
