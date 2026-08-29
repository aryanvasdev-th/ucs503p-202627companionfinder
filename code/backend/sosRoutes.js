// sosRoutes.js
const express = require('express');
const router = express.Router();
const { verifyToken } = require('./authMiddleware');
const { triggerSos } = require('./sosController');

router.use(verifyToken);

router.post('/', triggerSos);

module.exports = router;
