// activitiesController.js
const pool = require('./db');
const { createNotification } = require('./notificationsController');

const ACTIVE_WINDOW_BEFORE_HOURS = 1;
const ACTIVE_WINDOW_AFTER_HOURS = 3;

const LIST_SELECT = `
  SELECT
    a.id, a.title, a.category, a.description, a.landmark, a.starts_at, a.duration_minutes, a.max_people, a.banner_url,
    a.host_user_id, h.name AS host_name,
    (SELECT COUNT(*) FROM activity_participants p WHERE p.activity_id = a.id) AS people_joined,
    (SELECT AVG(score) FROM ratings r WHERE r.rated_user_id = a.host_user_id) AS host_rating,
    EXISTS(
      SELECT 1 FROM activity_participants p2 WHERE p2.activity_id = a.id AND p2.user_id = ?
    ) AS joined_by_me,
    EXISTS(
      SELECT 1 FROM activity_join_requests jr WHERE jr.activity_id = a.id AND jr.user_id = ? AND jr.status = 'pending'
    ) AS request_pending,
    EXISTS(
      SELECT 1 FROM activity_join_requests jr WHERE jr.activity_id = a.id AND jr.user_id = ? AND jr.status = 'declined'
    ) AS request_declined
  FROM activities a
  JOIN users h ON h.id = a.host_user_id
`;

function serializeActivity(row) {
  return {
    id: row.id,
    title: row.title,
    category: row.category,
    description: row.description,
    landmark: row.landmark,
    startsAt: row.starts_at,
    durationMinutes: row.duration_minutes,
    maxPeople: row.max_people,
    bannerUrl: row.banner_url,
    hostUserId: row.host_user_id,
    hostName: row.host_name,
    peopleJoined: row.people_joined,
    hostRating: row.host_rating === null ? null : Number(row.host_rating),
    joinedByMe: !!row.joined_by_me,
    requestPending: !!row.request_pending,
    requestDeclined: !!row.request_declined,
  };
}

async function createActivity(req, res) {
  const { title, category, description, landmark, startsAt, maxPeople, durationMinutes } = req.body;

  if (!title || !category || !startsAt || !maxPeople) {
    return res.status(400).json({ success: false, message: 'title, category, startsAt and maxPeople are required' });
  }
  if (durationMinutes != null && (!Number.isInteger(durationMinutes) || durationMinutes <= 0)) {
    return res.status(400).json({ success: false, message: 'durationMinutes must be a positive integer' });
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const [result] = await conn.query(
      'INSERT INTO activities (host_user_id, title, category, description, landmark, starts_at, duration_minutes, max_people) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [req.userId, title, category, description || null, landmark || null, new Date(startsAt), durationMinutes ?? null, maxPeople]
    );
    const activityId = result.insertId;

    await conn.query(
      'INSERT INTO activity_participants (activity_id, user_id) VALUES (?, ?)',
      [activityId, req.userId]
    );

    const [convResult] = await conn.query(
      'INSERT INTO conversations (activity_id) VALUES (?)',
      [activityId]
    );
    await conn.query(
      'INSERT INTO conversation_participants (conversation_id, user_id) VALUES (?, ?)',
      [convResult.insertId, req.userId]
    );

    await conn.commit();
    return res.status(201).json({ success: true, activityId });
  } catch (err) {
    await conn.rollback();
    console.error('createActivity error:', err);
    return res.status(500).json({ success: false, message: 'Server error creating activity' });
  } finally {
    conn.release();
  }
}

async function listActivities(req, res) {
  try {
    const { category, search, upcoming } = req.query;
    const clauses = [];
    const params = [req.userId, req.userId, req.userId];

    if (category) {
      clauses.push('a.category = ?');
      params.push(category);
    }
    if (search) {
      clauses.push('a.title LIKE ?');
      params.push(`%${search}%`);
    }
    if (upcoming === 'true') {
      clauses.push('a.starts_at >= NOW()');
    }

    const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
    const [rows] = await pool.query(`${LIST_SELECT} ${where} ORDER BY a.starts_at ASC`, params);

    return res.status(200).json({ success: true, activities: rows.map(serializeActivity) });
  } catch (err) {
    console.error('listActivities error:', err);
    return res.status(500).json({ success: false, message: 'Server error listing activities' });
  }
}

async function getActivity(req, res) {
  try {
    const [rows] = await pool.query(`${LIST_SELECT} WHERE a.id = ?`, [req.userId, req.userId, req.userId, req.params.id]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Activity not found' });
    }

    const [participants] = await pool.query(
      `SELECT u.id, u.name,
              (SELECT AVG(score) FROM ratings r WHERE r.rated_user_id = u.id) AS avg_rating
       FROM activity_participants p JOIN users u ON u.id = p.user_id WHERE p.activity_id = ?`,
      [req.params.id]
    );

    return res.status(200).json({
      success: true,
      activity: {
        ...serializeActivity(rows[0]),
        participants: participants.map((p) => ({
          id: p.id,
          name: p.name,
          avgRating: p.avg_rating === null ? null : Number(p.avg_rating),
        })),
      },
    });
  } catch (err) {
    console.error('getActivity error:', err);
    return res.status(500).json({ success: false, message: 'Server error fetching activity' });
  }
}

async function requestJoin(req, res) {
  const activityId = req.params.id;
  try {
    const [rows] = await pool.query(
      `SELECT a.host_user_id, a.title, a.max_people,
              (SELECT COUNT(*) FROM activity_participants p WHERE p.activity_id = a.id) AS people_joined
       FROM activities a WHERE a.id = ?`,
      [activityId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Activity not found' });
    }
    const { host_user_id, title, max_people, people_joined } = rows[0];
    if (host_user_id === req.userId) {
      return res.status(400).json({ success: false, message: 'You are already hosting this activity' });
    }

    const [already] = await pool.query(
      'SELECT 1 FROM activity_participants WHERE activity_id = ? AND user_id = ?',
      [activityId, req.userId]
    );
    if (already.length > 0) {
      return res.status(400).json({ success: false, message: 'You have already joined this activity' });
    }
    if (people_joined >= max_people) {
      return res.status(409).json({ success: false, message: 'Activity is full' });
    }

    const [existingRequest] = await pool.query(
      'SELECT status FROM activity_join_requests WHERE activity_id = ? AND user_id = ?',
      [activityId, req.userId]
    );
    if (existingRequest.length > 0 && existingRequest[0].status === 'declined') {
      return res.status(403).json({ success: false, message: 'The host declined your request to join this activity' });
    }

    await pool.query(
      `INSERT INTO activity_join_requests (activity_id, user_id, status, responded_at)
       VALUES (?, ?, 'pending', NULL)
       ON DUPLICATE KEY UPDATE status = 'pending', responded_at = NULL, created_at = CURRENT_TIMESTAMP`,
      [activityId, req.userId]
    );

    const [[requester]] = await pool.query('SELECT name FROM users WHERE id = ?', [req.userId]);
    createNotification(
      host_user_id,
      'join_request',
      'New join request',
      `${requester?.name || 'Someone'} wants to join "${title}"`,
      Number(activityId)
    );

    return res.status(200).json({ success: true, message: 'Request sent' });
  } catch (err) {
    console.error('requestJoin error:', err);
    return res.status(500).json({ success: false, message: 'Server error requesting to join' });
  }
}

async function cancelJoinRequest(req, res) {
  const activityId = req.params.id;
  try {
    await pool.query(
      `DELETE FROM activity_join_requests WHERE activity_id = ? AND user_id = ? AND status = 'pending'`,
      [activityId, req.userId]
    );
    return res.status(200).json({ success: true, message: 'Request cancelled' });
  } catch (err) {
    console.error('cancelJoinRequest error:', err);
    return res.status(500).json({ success: false, message: 'Server error cancelling request' });
  }
}

async function listJoinRequests(req, res) {
  const activityId = req.params.id;
  try {
    const [actRows] = await pool.query('SELECT host_user_id FROM activities WHERE id = ?', [activityId]);
    if (actRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Activity not found' });
    }
    if (actRows[0].host_user_id !== req.userId) {
      return res.status(403).json({ success: false, message: 'Only the host can view join requests' });
    }

    const [rows] = await pool.query(
      `SELECT jr.id, jr.user_id, jr.created_at, u.name, u.gender,
              (SELECT AVG(score) FROM ratings r WHERE r.rated_user_id = u.id) AS avg_rating
       FROM activity_join_requests jr
       JOIN users u ON u.id = jr.user_id
       WHERE jr.activity_id = ? AND jr.status = 'pending'
       ORDER BY jr.created_at ASC`,
      [activityId]
    );

    return res.status(200).json({
      success: true,
      requests: rows.map((r) => ({
        id: r.id,
        userId: r.user_id,
        name: r.name,
        gender: r.gender,
        avgRating: r.avg_rating === null ? null : Number(r.avg_rating),
        createdAt: r.created_at,
      })),
    });
  } catch (err) {
    console.error('listJoinRequests error:', err);
    return res.status(500).json({ success: false, message: 'Server error listing join requests' });
  }
}

async function respondToJoinRequest(req, res, accept) {
  const activityId = req.params.id;
  const requestId = req.params.requestId;
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const [actRows] = await conn.query(
      `SELECT host_user_id, title, max_people,
              (SELECT COUNT(*) FROM activity_participants p WHERE p.activity_id = a.id) AS people_joined
       FROM activities a WHERE a.id = ? FOR UPDATE`,
      [activityId]
    );
    if (actRows.length === 0) {
      await conn.rollback();
      return res.status(404).json({ success: false, message: 'Activity not found' });
    }
    const { host_user_id, title, max_people, people_joined } = actRows[0];
    if (host_user_id !== req.userId) {
      await conn.rollback();
      return res.status(403).json({ success: false, message: 'Only the host can respond to join requests' });
    }

    const [reqRows] = await conn.query(
      'SELECT user_id, status FROM activity_join_requests WHERE id = ? AND activity_id = ? FOR UPDATE',
      [requestId, activityId]
    );
    if (reqRows.length === 0) {
      await conn.rollback();
      return res.status(404).json({ success: false, message: 'Request not found' });
    }
    if (reqRows[0].status !== 'pending') {
      await conn.rollback();
      return res.status(400).json({ success: false, message: 'This request has already been responded to' });
    }
    const requesterUserId = reqRows[0].user_id;

    if (accept) {
      if (people_joined >= max_people) {
        await conn.rollback();
        return res.status(409).json({ success: false, message: 'Activity is full' });
      }
      await conn.query(
        'INSERT IGNORE INTO activity_participants (activity_id, user_id) VALUES (?, ?)',
        [activityId, requesterUserId]
      );
      const [convRows] = await conn.query('SELECT id FROM conversations WHERE activity_id = ?', [activityId]);
      if (convRows.length > 0) {
        await conn.query(
          'INSERT IGNORE INTO conversation_participants (conversation_id, user_id) VALUES (?, ?)',
          [convRows[0].id, requesterUserId]
        );
      }
    }

    await conn.query(
      'UPDATE activity_join_requests SET status = ?, responded_at = NOW() WHERE id = ?',
      [accept ? 'accepted' : 'declined', requestId]
    );

    await conn.commit();

    createNotification(
      requesterUserId,
      accept ? 'request_accepted' : 'request_declined',
      accept ? 'Request accepted' : 'Request declined',
      accept
        ? `You're in! Your request to join "${title}" was accepted.`
        : `Your request to join "${title}" was declined.`,
      accept ? Number(activityId) : null
    );

    return res.status(200).json({ success: true, message: accept ? 'Request accepted' : 'Request declined' });
  } catch (err) {
    await conn.rollback();
    console.error('respondToJoinRequest error:', err);
    return res.status(500).json({ success: false, message: 'Server error responding to request' });
  } finally {
    conn.release();
  }
}

async function acceptJoinRequest(req, res) {
  return respondToJoinRequest(req, res, true);
}

async function declineJoinRequest(req, res) {
  return respondToJoinRequest(req, res, false);
}

async function deleteActivity(req, res) {
  const activityId = req.params.id;
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const [rows] = await conn.query(
      'SELECT host_user_id, title FROM activities WHERE id = ? FOR UPDATE',
      [activityId]
    );
    if (rows.length === 0) {
      await conn.rollback();
      return res.status(404).json({ success: false, message: 'Activity not found' });
    }
    if (rows[0].host_user_id !== req.userId) {
      await conn.rollback();
      return res.status(403).json({ success: false, message: 'Only the host can delete this activity' });
    }
    const { title } = rows[0];

    const [otherParticipants] = await conn.query(
      'SELECT user_id FROM activity_participants WHERE activity_id = ? AND user_id != ?',
      [activityId, req.userId]
    );
    const [pendingRequesters] = await conn.query(
      `SELECT user_id FROM activity_join_requests WHERE activity_id = ? AND status = 'pending'`,
      [activityId]
    );

    await conn.query(
      `DELETE m FROM messages m
       JOIN conversations c ON c.id = m.conversation_id
       WHERE c.activity_id = ?`,
      [activityId]
    );
    await conn.query(
      `DELETE cp FROM conversation_participants cp
       JOIN conversations c ON c.id = cp.conversation_id
       WHERE c.activity_id = ?`,
      [activityId]
    );
    await conn.query('DELETE FROM conversations WHERE activity_id = ?', [activityId]);
    await conn.query('DELETE FROM ratings WHERE activity_id = ?', [activityId]);
    await conn.query('DELETE FROM activity_participants WHERE activity_id = ?', [activityId]);
    await conn.query('UPDATE sos_alerts SET activity_id = NULL WHERE activity_id = ?', [activityId]);
    await conn.query('UPDATE notifications SET activity_id = NULL WHERE activity_id = ?', [activityId]);
    await conn.query('DELETE FROM activity_join_requests WHERE activity_id = ?', [activityId]);
    await conn.query('DELETE FROM activities WHERE id = ?', [activityId]);

    await conn.commit();

    for (const { user_id } of otherParticipants) {
      createNotification(
        user_id,
        'activity_cancelled',
        'Activity cancelled',
        `The host cancelled "${title}"`
      );
    }
    for (const { user_id } of pendingRequesters) {
      createNotification(
        user_id,
        'activity_cancelled',
        'Activity cancelled',
        `"${title}" was cancelled before your join request was reviewed`
      );
    }

    return res.status(200).json({ success: true, message: 'Activity deleted' });
  } catch (err) {
    await conn.rollback();
    console.error('deleteActivity error:', err);
    return res.status(500).json({ success: false, message: 'Server error deleting activity' });
  } finally {
    conn.release();
  }
}

async function uploadActivityBanner(req, res) {
  const activityId = req.params.id;
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'No image file provided' });
  }
  try {
    const [rows] = await pool.query('SELECT host_user_id FROM activities WHERE id = ?', [activityId]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Activity not found' });
    }
    if (rows[0].host_user_id !== req.userId) {
      return res.status(403).json({ success: false, message: 'Only the host can set the banner image' });
    }

    const bannerUrl = `/uploads/activity-banners/${req.file.filename}`;
    await pool.query('UPDATE activities SET banner_url = ? WHERE id = ?', [bannerUrl, activityId]);
    return res.status(200).json({ success: true, bannerUrl });
  } catch (err) {
    console.error('uploadActivityBanner error:', err);
    return res.status(500).json({ success: false, message: 'Server error uploading banner' });
  }
}

async function leaveActivity(req, res) {
  const activityId = req.params.id;
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    await conn.query(
      'DELETE FROM activity_participants WHERE activity_id = ? AND user_id = ?',
      [activityId, req.userId]
    );

    const [convRows] = await conn.query('SELECT id FROM conversations WHERE activity_id = ?', [activityId]);
    if (convRows.length > 0) {
      await conn.query(
        'DELETE FROM conversation_participants WHERE conversation_id = ? AND user_id = ?',
        [convRows[0].id, req.userId]
      );
    }

    await conn.commit();
    return res.status(200).json({ success: true, message: 'Left activity' });
  } catch (err) {
    await conn.rollback();
    console.error('leaveActivity error:', err);
    return res.status(500).json({ success: false, message: 'Server error leaving activity' });
  } finally {
    conn.release();
  }
}

async function rateParticipant(req, res) {
  const activityId = req.params.id;
  const { ratedUserId, score } = req.body;

  const validScore =
    typeof score === 'number' && score >= 1 && score <= 5 && Math.round(score * 2) === score * 2;
  if (!ratedUserId || !validScore) {
    return res.status(400).json({ success: false, message: 'ratedUserId and a score from 1-5 in 0.5 steps are required' });
  }
  if (Number(ratedUserId) === req.userId) {
    return res.status(400).json({ success: false, message: 'You cannot rate yourself' });
  }

  try {
    const [actRows] = await pool.query(
      'SELECT title, starts_at, duration_minutes FROM activities WHERE id = ?',
      [activityId]
    );
    if (actRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Activity not found' });
    }
    const { title, starts_at, duration_minutes } = actRows[0];
    const endsAt = new Date(starts_at.getTime() + (duration_minutes || 0) * 60000);
    if (new Date() < endsAt) {
      return res.status(400).json({ success: false, message: 'You can rate people once this activity is over' });
    }

    const [rows] = await pool.query(
      'SELECT user_id FROM activity_participants WHERE activity_id = ? AND user_id IN (?, ?)',
      [activityId, req.userId, ratedUserId]
    );
    if (rows.length < 2) {
      return res.status(403).json({ success: false, message: 'Both users must have taken part in this activity' });
    }

    await pool.query(
      `INSERT INTO ratings (activity_id, rater_user_id, rated_user_id, score)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE score = VALUES(score)`,
      [activityId, req.userId, ratedUserId, score]
    );

    const [[rater]] = await pool.query('SELECT name FROM users WHERE id = ?', [req.userId]);
    createNotification(
      ratedUserId,
      'rating_received',
      'New rating',
      `${rater?.name || 'Someone'} rated you ${score} stars for "${title}"`,
      Number(activityId)
    );

    return res.status(200).json({ success: true, message: 'Rating saved' });
  } catch (err) {
    console.error('rateParticipant error:', err);
    return res.status(500).json({ success: false, message: 'Server error saving rating' });
  }
}

async function myActivities(req, res) {
  try {
    const [rows] = await pool.query(
      `${LIST_SELECT}
       WHERE a.id IN (
         SELECT activity_id FROM activity_participants WHERE user_id = ?
       )
       ORDER BY a.starts_at ASC`,
      [req.userId, req.userId, req.userId, req.userId]
    );
    return res.status(200).json({ success: true, activities: rows.map(serializeActivity) });
  } catch (err) {
    console.error('myActivities error:', err);
    return res.status(500).json({ success: false, message: 'Server error fetching your activities' });
  }
}

// Used by the SOS flow: the activity a user is currently "in" — one they've
// joined/hosted whose start time is close to now.
async function findActiveActivityForUser(userId) {
  const [rows] = await pool.query(
    `SELECT a.id, a.title FROM activities a
     JOIN activity_participants p ON p.activity_id = a.id
     WHERE p.user_id = ?
       AND a.starts_at BETWEEN DATE_SUB(NOW(), INTERVAL ? HOUR) AND DATE_ADD(NOW(), INTERVAL ? HOUR)
     ORDER BY a.starts_at DESC
     LIMIT 1`,
    [userId, ACTIVE_WINDOW_BEFORE_HOURS, ACTIVE_WINDOW_AFTER_HOURS]
  );
  return rows[0] || null;
}

async function getCompanionNames(activityId, excludingUserId) {
  const [rows] = await pool.query(
    `SELECT u.name, u.email FROM activity_participants p JOIN users u ON u.id = p.user_id
     WHERE p.activity_id = ? AND p.user_id != ?`,
    [activityId, excludingUserId]
  );
  return rows.map((r) => r.name || r.email);
}

module.exports = {
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
  findActiveActivityForUser,
  getCompanionNames,
};
