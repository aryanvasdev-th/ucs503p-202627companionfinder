// conversationsController.js
const pool = require('./db');

async function listConversations(req, res) {
  try {
    const [rows] = await pool.query(
      `SELECT
         c.id,
         c.activity_id,
         a.title AS activity_title,
         a.banner_url AS activity_banner_url,
         (CASE WHEN c.activity_id IS NULL THEN
            (SELECT u.name FROM conversation_participants cp2
             JOIN users u ON u.id = cp2.user_id
             WHERE cp2.conversation_id = c.id AND cp2.user_id != ? LIMIT 1)
          ELSE NULL END) AS other_user_name,
         (SELECT body FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) AS last_message,
         (SELECT created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) AS last_message_at
       FROM conversations c
       JOIN conversation_participants cp ON cp.conversation_id = c.id
       LEFT JOIN activities a ON a.id = c.activity_id
       WHERE cp.user_id = ?
       ORDER BY last_message_at IS NULL, last_message_at DESC`,
      [req.userId, req.userId]
    );
    return res.status(200).json({ success: true, conversations: rows });
  } catch (err) {
    console.error('listConversations error:', err);
    return res.status(500).json({ success: false, message: 'Server error listing conversations' });
  }
}

async function isParticipant(conversationId, userId) {
  const [rows] = await pool.query(
    'SELECT 1 FROM conversation_participants WHERE conversation_id = ? AND user_id = ?',
    [conversationId, userId]
  );
  return rows.length > 0;
}

async function getMessages(req, res) {
  try {
    const conversationId = req.params.id;
    if (!(await isParticipant(conversationId, req.userId))) {
      return res.status(403).json({ success: false, message: 'Not a participant in this conversation' });
    }

    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 100);
    const before = req.query.before || null;

    const [rows] = await pool.query(
      `SELECT m.id, m.conversation_id, m.sender_user_id, u.name AS sender_name, m.body, m.created_at
       FROM messages m
       JOIN users u ON u.id = m.sender_user_id
       WHERE m.conversation_id = ? AND (? IS NULL OR m.created_at < ?)
       ORDER BY m.created_at DESC
       LIMIT ?`,
      [conversationId, before, before, limit]
    );

    return res.status(200).json({ success: true, messages: rows.reverse() });
  } catch (err) {
    console.error('getMessages error:', err);
    return res.status(500).json({ success: false, message: 'Server error fetching messages' });
  }
}

async function startDirectConversation(req, res) {
  try {
    const { otherUserId } = req.body;
    if (!otherUserId || otherUserId === req.userId) {
      return res.status(400).json({ success: false, message: 'A valid otherUserId is required' });
    }

    const [existing] = await pool.query(
      `SELECT c.id FROM conversations c
       JOIN conversation_participants p1 ON p1.conversation_id = c.id AND p1.user_id = ?
       JOIN conversation_participants p2 ON p2.conversation_id = c.id AND p2.user_id = ?
       WHERE c.activity_id IS NULL
       LIMIT 1`,
      [req.userId, otherUserId]
    );

    if (existing.length > 0) {
      return res.status(200).json({ success: true, conversationId: existing[0].id });
    }

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      const [result] = await conn.query('INSERT INTO conversations (activity_id) VALUES (NULL)');
      const conversationId = result.insertId;
      await conn.query(
        'INSERT INTO conversation_participants (conversation_id, user_id) VALUES (?, ?), (?, ?)',
        [conversationId, req.userId, conversationId, otherUserId]
      );
      await conn.commit();
      return res.status(201).json({ success: true, conversationId });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (err) {
    console.error('startDirectConversation error:', err);
    return res.status(500).json({ success: false, message: 'Server error starting conversation' });
  }
}

// Shared with socket.js so REST and socket sends persist messages identically.
async function saveMessage(conversationId, senderUserId, body) {
  const [result] = await pool.query(
    'INSERT INTO messages (conversation_id, sender_user_id, body) VALUES (?, ?, ?)',
    [conversationId, senderUserId, body]
  );
  const [rows] = await pool.query(
    `SELECT m.id, m.conversation_id, m.sender_user_id, u.name AS sender_name, m.body, m.created_at
     FROM messages m JOIN users u ON u.id = m.sender_user_id WHERE m.id = ?`,
    [result.insertId]
  );
  return rows[0];
}

module.exports = {
  listConversations,
  getMessages,
  startDirectConversation,
  isParticipant,
  saveMessage,
};
