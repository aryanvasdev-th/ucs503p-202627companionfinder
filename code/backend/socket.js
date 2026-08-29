// socket.js
// Real-time messaging. Chosen over polling because the app is meant to launch
// campus-wide — polling load scales with user-count x frequency regardless of
// whether anything changed, while sockets only push on an actual new message.
const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');
const { isParticipant, saveMessage } = require('./conversationsController');

const JWT_SECRET = process.env.JWT_SECRET;

function initSocket(httpServer) {
  const io = new Server(httpServer, {
    cors: { origin: '*' },
  });

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error('Missing auth token'));
    try {
      const payload = jwt.verify(token, JWT_SECRET);
      socket.userId = payload.userId;
      next();
    } catch (err) {
      next(new Error('Invalid or expired token'));
    }
  });

  io.on('connection', (socket) => {
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

module.exports = { initSocket };
