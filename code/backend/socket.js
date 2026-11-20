// socket.js
// Real-time messaging. Chosen over polling because the app is meant to launch
// campus-wide — polling load scales with user-count x frequency regardless of
// whether anything changed, while sockets only push on an actual new message.
const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');
const pool = require('./db');
const { isParticipant, saveMessage } = require('./conversationsController');

const JWT_SECRET = process.env.JWT_SECRET;

let io = null;

// Pushes an event to every open connection of one user (all their devices).
// No-op before the socket server is up, so callers never need to check.
function emitToUser(userId, event, payload) {
  io?.to(`user:${userId}`).emit(event, payload);
}

function initSocket(httpServer) {
  io = new Server(httpServer, {
    cors: { origin: '*' },
  });

  io.use(async (socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error('Missing auth token'));
    let payload;
    try {
      payload = jwt.verify(token, JWT_SECRET);
    } catch (err) {
      return next(new Error('Invalid or expired token'));
    }
    try {
      const [rows] = await pool.query('SELECT is_banned FROM users WHERE id = ?', [payload.userId]);
      if (rows.length === 0 || rows[0].is_banned) return next(new Error('Account suspended'));
    } catch (err) {
      return next(new Error('Server error'));
    }
    socket.userId = payload.userId;
    next();
  });

  io.on('connection', (socket) => {
    // Personal room so notifications (join requests, accept/decline) can be
    // pushed the moment they're created instead of waiting for a refresh.
    socket.join(`user:${socket.userId}`);

    socket.on('conversation:join', async (conversationId, ack) => {
      try {
        const allowed = await isParticipant(conversationId, socket.userId);
        if (!allowed) {
          return ack?.({ success: false, message: 'Not a participant in this conversation' });
        }
        socket.join(`conversation:${conversationId}`);
        ack?.({ success: true });
      } catch (err) {
        console.error('conversation:join error:', err);
        ack?.({ success: false, message: 'Server error joining conversation' });
      }
    });

    socket.on('message:send', async ({ conversationId, body }, ack) => {
      try {
        if (!conversationId || !body?.trim()) {
          return ack?.({ success: false, message: 'conversationId and body are required' });
        }
        const allowed = await isParticipant(conversationId, socket.userId);
        if (!allowed) {
          return ack?.({ success: false, message: 'Not a participant in this conversation' });
        }

        const message = await saveMessage(conversationId, socket.userId, body.trim());
        io.to(`conversation:${conversationId}`).emit('message:new', message);
        ack?.({ success: true, message });
      } catch (err) {
        console.error('message:send error:', err);
        ack?.({ success: false, message: 'Server error sending message' });
      }
    });
  });

  return io;
}

module.exports = { initSocket, emitToUser };
