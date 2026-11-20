// activitiesController.js
const pool = require('./db');
const { createNotification } = require('./notificationsController');
const { ACTIVITY_CATEGORIES } = require('./categories');
const { optimizeImage } = require('./imageService');
const { REVIEW_TAGS, REVIEW_TEXT_MAX } = require('./reviewTags');
const { isAdminUser } = require('./admin');

const ACTIVE_WINDOW_BEFORE_HOURS = 1;
const MAX_PEOPLE_CAP = 50000;
const ACTIVE_WINDOW_AFTER_HOURS = 3;

const LIST_SELECT = `
  SELECT
    a.id, a.title, a.category, a.description, a.landmark, a.starts_at, a.duration_minutes, a.max_people, a.banner_url,
    a.is_team_event, a.is_featured,
    (SELECT COUNT(*) FROM activity_teams t WHERE t.activity_id = a.id) AS event_activity_count,
    a.host_user_id, h.name AS host_name, h.id_verification_status = 'verified' AS host_verified,
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
    // Multi-day events (a 3-day fest) are a start plus a long duration;
    // endsAt saves every client from doing that sum.
    endsAt:
      row.duration_minutes == null
        ? null
        : new Date(new Date(row.starts_at).getTime() + row.duration_minutes * 60000),
    maxPeople: row.max_people,
    bannerUrl: row.banner_url,
    isEvent: !!row.is_team_event,
    isFeatured: !!row.is_featured,
    eventActivityCount: Number(row.event_activity_count || 0),
    hostUserId: row.host_user_id,
    hostName: row.host_name,
    hostVerified: !!row.host_verified,
    peopleJoined: row.people_joined,
    hostRating: row.host_rating === null ? null : Number(row.host_rating),
    joinedByMe: !!row.joined_by_me,
    requestPending: !!row.request_pending,
    requestDeclined: !!row.request_declined,
  };
}

async function createActivity(req, res) {
  const { title, description, landmark, startsAt, maxPeople, durationMinutes } = req.body;
  const isEvent = req.body.isEvent === true;
  // Events are always filed under 'Event' (their own Discover chip);
  // ordinary activities can't claim it.
  const category = isEvent ? 'Event' : req.body.category;
  if (!isEvent && category === 'Event') {
    return res.status(400).json({ success: false, message: 'Use isEvent to host an event' });
  }

  if (!title || !category || !startsAt || !maxPeople) {
    return res.status(400).json({ success: false, message: 'title, category, startsAt and maxPeople are required' });
  }
  if (!ACTIVITY_CATEGORIES.includes(category)) {
    return res.status(400).json({
      success: false,
      message: `category must be one of: ${ACTIVITY_CATEGORIES.join(', ')}`,
    });
  }
  if (!Number.isInteger(Number(maxPeople)) || Number(maxPeople) < 1 || Number(maxPeople) > MAX_PEOPLE_CAP) {
    return res.status(400).json({ success: false, message: `maxPeople must be between 1 and ${MAX_PEOPLE_CAP}` });
  }
  if (durationMinutes != null && (!Number.isInteger(durationMinutes) || durationMinutes <= 0)) {
    return res.status(400).json({ success: false, message: 'durationMinutes must be a positive integer' });
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    const [result] = await conn.query(
      `INSERT INTO activities
         (host_user_id, title, category, description, landmark, starts_at, duration_minutes, max_people, is_team_event, team_size)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.userId, title, category, description || null, landmark || null, new Date(startsAt), durationMinutes ?? null, maxPeople, isEvent, null]
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
      // Still listed while it's running: a fest that started yesterday and
      // ends tomorrow is upcoming in every sense that matters.
      clauses.push('DATE_ADD(a.starts_at, INTERVAL COALESCE(a.duration_minutes, 0) MINUTE) >= NOW()');
    }

    const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
    // Admin-featured activities (e.g. a fest) are pinned to the top.
    const [rows] = await pool.query(`${LIST_SELECT} ${where} ORDER BY a.is_featured DESC, a.starts_at ASC`, params);

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
      `SELECT u.id, u.name, u.avatar_url, u.id_verification_status = 'verified' AS verified,
              (SELECT AVG(score) FROM ratings r WHERE r.rated_user_id = u.id) AS avg_rating,
              r2.score AS my_score, r2.review_text AS my_review, r2.tags AS my_tags
       FROM activity_participants p
       JOIN users u ON u.id = p.user_id
       LEFT JOIN ratings r2
         ON r2.activity_id = p.activity_id AND r2.rater_user_id = ? AND r2.rated_user_id = u.id
       WHERE p.activity_id = ?`,
      [req.userId, req.params.id]
    );
    const eventActivities = await loadEventActivities(req.params.id);
    // The activity's group chat, only for people who are in it.
    const [chatRows] = await pool.query(
      `SELECT c.id FROM conversations c
       JOIN conversation_participants cp ON cp.conversation_id = c.id AND cp.user_id = ?
       WHERE c.activity_id = ? LIMIT 1`,
      [req.userId, req.params.id]
    );

    return res.status(200).json({
      success: true,
      activity: {
        ...serializeActivity(rows[0]),
        participants: participants.map((p) => ({
          id: p.id,
          name: p.name,
          avatarUrl: p.avatar_url,
          verified: !!p.verified,
          avgRating: p.avg_rating === null ? null : Number(p.avg_rating),
          myRating: p.my_score === null ? null : Number(p.my_score),
          myReview: p.my_review,
          myTags: p.my_tags ? p.my_tags.split(',') : [],
        })),
        eventActivities,
        groupChatId: chatRows[0]?.id ?? null,
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
      `SELECT jr.id, jr.user_id, jr.created_at, u.name, u.gender, u.avatar_url,
              u.id_verification_status = 'verified' AS verified,
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
        avatarUrl: r.avatar_url,
        verified: !!r.verified,
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
    const byAdmin = rows[0].host_user_id !== req.userId && (await isAdminUser(req.userId));
    if (rows[0].host_user_id !== req.userId && !byAdmin) {
      await conn.rollback();
      return res.status(403).json({ success: false, message: 'Only the host can delete this activity' });
    }
    const { title } = rows[0];
    const hostUserId = rows[0].host_user_id;

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
    await conn.query(
      `DELETE tm FROM activity_team_members tm
       JOIN activity_teams t ON t.id = tm.team_id
       WHERE t.activity_id = ?`,
      [activityId]
    );
    await conn.query(
      'DELETE s FROM activity_squads s JOIN activity_teams t ON t.id = s.item_id WHERE t.activity_id = ?',
      [activityId]
    );
    await conn.query('DELETE FROM activity_teams WHERE activity_id = ?', [activityId]);
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
        byAdmin ? `"${title}" was removed by the Companion team` : `The host cancelled "${title}"`
      );
    }
    if (byAdmin) {
      createNotification(
        hostUserId,
        'activity_cancelled',
        'Activity removed',
        `"${title}" was removed by the Companion team for breaking the community guidelines`
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

    const filename = await optimizeImage(req.file.path, 'banner');
    const bannerUrl = `/uploads/activity-banners/${filename}`;
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

    await removeFromEventActivities(conn, activityId, req.userId);

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
  const reviewText = typeof req.body.review === 'string' ? req.body.review.trim() : '';
  const tags = Array.isArray(req.body.tags)
    ? [...new Set(req.body.tags.filter((t) => REVIEW_TAGS.includes(t)))]
    : [];

  const validScore =
    typeof score === 'number' && score >= 1 && score <= 5 && Math.round(score * 2) === score * 2;
  if (!ratedUserId || !validScore) {
    return res.status(400).json({ success: false, message: 'ratedUserId and a score from 1-5 in 0.5 steps are required' });
  }
  if (Number(ratedUserId) === req.userId) {
    return res.status(400).json({ success: false, message: 'You cannot rate yourself' });
  }
  if (reviewText.length > REVIEW_TEXT_MAX) {
    return res.status(400).json({ success: false, message: `Reviews can be at most ${REVIEW_TEXT_MAX} characters` });
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
      `INSERT INTO ratings (activity_id, rater_user_id, rated_user_id, score, review_text, tags)
       VALUES (?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE score = VALUES(score), review_text = VALUES(review_text), tags = VALUES(tags)`,
      [activityId, req.userId, ratedUserId, score, reviewText || null, tags.length ? tags.join(',') : null]
    );

    const [[rater]] = await pool.query('SELECT name FROM users WHERE id = ?', [req.userId]);
    createNotification(
      ratedUserId,
      'rating_received',
      reviewText ? 'New review' : 'New rating',
      `${rater?.name || 'Someone'} rated you ${score} stars for "${title}"${reviewText ? ' and left a review' : ''}`,
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

// ---------- Events: activities inside an event ----------
// An event (activities.is_team_event = TRUE) is an umbrella such as a fest:
// people join the event the usual way (request -> host accepts), and the
// host adds the activities that happen inside it — Football (22 spots),
// Quiz (30 spots), each with an optional start time. Attendees can sign up
// for as many of them as have space. The host only organises, so they are
// never counted in an activity's spots.
//
// Stored in activity_teams / activity_team_members (the tables began life
// as "teams"); an event activity is one row in activity_teams.
//
// Team activities: the host can give an event activity a team size
// (Football, teams of 11). Then nobody signs up alone — attendees join a
// team with space or start one, which is how someone with no friends going
// finds people to play with. Teams live in activity_squads and a member's
// row in activity_team_members points at their squad. Each member still
// takes one of the activity's spots.

const EVENT_ACTIVITY_NAME_MAX = 60;
const EVENT_ACTIVITY_SPOTS_MAX = 500;

async function loadEventActivities(activityId, conn = pool) {
  const [items] = await conn.query(
    `SELECT t.id, t.name, t.max_members, t.starts_at, t.team_size
     FROM activity_teams t
     WHERE t.activity_id = ? ORDER BY t.starts_at IS NULL, t.starts_at ASC, t.created_at ASC`,
    [activityId]
  );
  if (items.length === 0) return [];
  const itemIds = items.map((t) => t.id);
  const [members] = await conn.query(
    `SELECT tm.team_id, tm.squad_id, u.id, u.name FROM activity_team_members tm
     JOIN users u ON u.id = tm.user_id
     WHERE tm.team_id IN (?) ORDER BY tm.joined_at ASC`,
    [itemIds]
  );
  const [squads] = await conn.query(
    `SELECT id, item_id, name, created_by_user_id FROM activity_squads
     WHERE item_id IN (?) ORDER BY created_at ASC`,
    [itemIds]
  );
  const person = (m) => ({ id: m.id, name: m.name });
  return items.map((t) => ({
    id: t.id,
    name: t.name,
    spots: t.max_members,
    startsAt: t.starts_at,
    teamSize: t.team_size,
    members: members.filter((m) => m.team_id === t.id).map(person),
    teams: t.team_size
      ? squads
          .filter((sq) => sq.item_id === t.id)
          .map((sq) => ({
            id: sq.id,
            name: sq.name,
            createdByUserId: sq.created_by_user_id,
            members: members.filter((m) => m.squad_id === sq.id).map(person),
          }))
      : [],
  }));
}

// Signs a user out of every activity inside an event (used when they leave
// the event itself).
async function removeFromEventActivities(conn, activityId, userId) {
  await conn.query(
    `DELETE tm FROM activity_team_members tm
     JOIN activity_teams t ON t.id = tm.team_id
     WHERE t.activity_id = ? AND tm.user_id = ?`,
    [activityId, userId]
  );
  await deleteEmptySquads(conn, 'item_id IN (SELECT id FROM activity_teams WHERE activity_id = ?)', [activityId]);
}

// A team nobody is in any more disappears.
async function deleteEmptySquads(conn, where, params) {
  await conn.query(
    `DELETE FROM activity_squads
     WHERE ${where}
       AND id NOT IN (SELECT squad_id FROM (
         SELECT DISTINCT squad_id FROM activity_team_members WHERE squad_id IS NOT NULL
       ) AS used)`,
    params
  );
}

async function isActivityParticipant(conn, activityId, userId) {
  const [rows] = await conn.query(
    'SELECT 1 FROM activity_participants WHERE activity_id = ? AND user_id = ?',
    [activityId, userId]
  );
  return rows.length > 0;
}

async function createEventActivity(req, res) {
  const eventId = req.params.id;
  const name = typeof req.body.name === 'string' ? req.body.name.trim() : '';
  const spots = Number(req.body.spots);
  const startsAt = req.body.startsAt ? new Date(req.body.startsAt) : null;
  const teamSize = req.body.teamSize == null ? null : Number(req.body.teamSize);

  if (!name || name.length > EVENT_ACTIVITY_NAME_MAX) {
    return res.status(400).json({ success: false, message: `Name is required (max ${EVENT_ACTIVITY_NAME_MAX} characters)` });
  }
  if (!Number.isInteger(spots) || spots < 1 || spots > EVENT_ACTIVITY_SPOTS_MAX) {
    return res.status(400).json({ success: false, message: `Spots must be between 1 and ${EVENT_ACTIVITY_SPOTS_MAX}` });
  }
  if (startsAt && Number.isNaN(startsAt.getTime())) {
    return res.status(400).json({ success: false, message: 'Invalid start time' });
  }
  if (teamSize !== null && (!Number.isInteger(teamSize) || teamSize < 2 || teamSize > spots)) {
    return res.status(400).json({ success: false, message: 'Players per team must be between 2 and the number of spots' });
  }

  try {
    const [rows] = await pool.query(
      'SELECT host_user_id, is_team_event, starts_at, duration_minutes FROM activities WHERE id = ?',
      [eventId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }
    if (!rows[0].is_team_event) {
      return res.status(400).json({ success: false, message: 'Only events can have activities inside them' });
    }
    if (rows[0].host_user_id !== req.userId) {
      return res.status(403).json({ success: false, message: 'Only the host can add activities to this event' });
    }
    if (startsAt) {
      const eventStart = new Date(rows[0].starts_at);
      // Without an end date the event is treated as that one day.
      const eventEnd = rows[0].duration_minutes
        ? new Date(eventStart.getTime() + rows[0].duration_minutes * 60000)
        : new Date(eventStart.getFullYear(), eventStart.getMonth(), eventStart.getDate(), 23, 59, 59);
      if (startsAt < eventStart || startsAt > eventEnd) {
        return res.status(400).json({ success: false, message: "Pick a time during the event's dates" });
      }
    }
    const [dupes] = await pool.query(
      'SELECT 1 FROM activity_teams WHERE activity_id = ? AND LOWER(name) = LOWER(?)',
      [eventId, name]
    );
    if (dupes.length > 0) {
      return res.status(409).json({ success: false, message: 'This event already has an activity with that name' });
    }
    const [result] = await pool.query(
      'INSERT INTO activity_teams (activity_id, name, max_members, starts_at, team_size, created_by_user_id) VALUES (?, ?, ?, ?, ?, ?)',
      [eventId, name, spots, startsAt, teamSize, req.userId]
    );
    return res.status(201).json({ success: true, eventActivityId: result.insertId });
  } catch (err) {
    console.error('createEventActivity error:', err);
    return res.status(500).json({ success: false, message: 'Server error adding activity' });
  }
}

async function joinEventActivity(req, res) {
  const { id: eventId, itemId } = req.params;
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [rows] = await conn.query(
      `SELECT t.name, t.max_members, t.team_size, a.title, a.host_user_id,
              (SELECT COUNT(*) FROM activity_team_members tm WHERE tm.team_id = t.id) AS member_count
       FROM activity_teams t JOIN activities a ON a.id = t.activity_id
       WHERE t.id = ? AND t.activity_id = ? FOR UPDATE`,
      [itemId, eventId]
    );
    if (rows.length === 0) {
      await conn.rollback();
      return res.status(404).json({ success: false, message: 'Activity not found in this event' });
    }
    const item = rows[0];
    if (item.team_size) {
      await conn.rollback();
      return res.status(400).json({ success: false, message: `${item.name} is played in teams. Join a team or start one.` });
    }
    if (item.host_user_id === req.userId) {
      await conn.rollback();
      return res.status(400).json({ success: false, message: "You're hosting this event, so you don't take a spot" });
    }
    if (!(await isActivityParticipant(conn, eventId, req.userId))) {
      await conn.rollback();
      return res.status(403).json({ success: false, message: 'Join the event before signing up for its activities' });
    }
    const [already] = await conn.query(
      'SELECT 1 FROM activity_team_members WHERE team_id = ? AND user_id = ?',
      [itemId, req.userId]
    );
    if (already.length > 0) {
      await conn.rollback();
      return res.status(409).json({ success: false, message: "You're already signed up for this" });
    }
    if (item.member_count >= item.max_members) {
      await conn.rollback();
      return res.status(409).json({ success: false, message: `${item.name} is full` });
    }
    await conn.query('INSERT INTO activity_team_members (team_id, user_id) VALUES (?, ?)', [itemId, req.userId]);
    await conn.commit();

    const [[joiner]] = await pool.query('SELECT name FROM users WHERE id = ?', [req.userId]);
    createNotification(
      item.host_user_id,
      'event_activity_joined',
      'New sign-up',
      `${joiner?.name || 'Someone'} signed up for ${item.name} at "${item.title}"`,
      Number(eventId)
    );
    return res.status(200).json({ success: true, message: 'Signed up' });
  } catch (err) {
    await conn.rollback();
    console.error('joinEventActivity error:', err);
    return res.status(500).json({ success: false, message: 'Server error signing up' });
  } finally {
    conn.release();
  }
}


// Shared checks for starting or joining a team in a team activity. Locks
// the activity row so two people can't take the last spot at once.
async function lockTeamActivity(conn, req, eventId, itemId) {
  const [rows] = await conn.query(
    `SELECT t.name, t.max_members, t.team_size, a.title, a.host_user_id,
            (SELECT COUNT(*) FROM activity_team_members tm WHERE tm.team_id = t.id) AS member_count,
            (SELECT COUNT(*) FROM activity_squads sq WHERE sq.item_id = t.id) AS squad_count
     FROM activity_teams t JOIN activities a ON a.id = t.activity_id
     WHERE t.id = ? AND t.activity_id = ? FOR UPDATE`,
    [itemId, eventId]
  );
  if (rows.length === 0) return { status: 404, message: 'Activity not found in this event' };
  const item = rows[0];
  if (!item.team_size) return { status: 400, message: `${item.name} isn't played in teams` };
  if (item.host_user_id === req.userId) {
    return { status: 400, message: "You're hosting this event, so you don't take a spot" };
  }
  if (!(await isActivityParticipant(conn, eventId, req.userId))) {
    return { status: 403, message: 'Join the event before signing up for its activities' };
  }
  const [already] = await conn.query(
    'SELECT 1 FROM activity_team_members WHERE team_id = ? AND user_id = ?',
    [itemId, req.userId]
  );
  if (already.length > 0) return { status: 409, message: `You're already in a team for ${item.name}` };
  if (item.member_count >= item.max_members) return { status: 409, message: `${item.name} is full` };
  return { item };
}

async function createSquad(req, res) {
  const { id: eventId, itemId } = req.params;
  const name = typeof req.body.name === 'string' ? req.body.name.trim() : '';
  if (!name || name.length > EVENT_ACTIVITY_NAME_MAX) {
    return res.status(400).json({ success: false, message: `Team name is required (max ${EVENT_ACTIVITY_NAME_MAX} characters)` });
  }
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const check = await lockTeamActivity(conn, req, eventId, itemId);
    if (!check.item) {
      await conn.rollback();
      return res.status(check.status).json({ success: false, message: check.message });
    }
    const { item } = check;
    // e.g. 40 spots in teams of 11 -> at most 4 teams.
    const maxSquads = Math.ceil(item.max_members / item.team_size);
    if (item.squad_count >= maxSquads) {
      await conn.rollback();
      return res.status(409).json({ success: false, message: `${item.name} already has its ${maxSquads} teams. Join one with space.` });
    }
    const [dupes] = await conn.query(
      'SELECT 1 FROM activity_squads WHERE item_id = ? AND LOWER(name) = LOWER(?)',
      [itemId, name]
    );
    if (dupes.length > 0) {
      await conn.rollback();
      return res.status(409).json({ success: false, message: 'A team with that name already exists' });
    }
    const [result] = await conn.query(
      'INSERT INTO activity_squads (item_id, name, created_by_user_id) VALUES (?, ?, ?)',
      [itemId, name, req.userId]
    );
    await conn.query(
      'INSERT INTO activity_team_members (team_id, user_id, squad_id) VALUES (?, ?, ?)',
      [itemId, req.userId, result.insertId]
    );
    await conn.commit();
    return res.status(201).json({ success: true, teamId: result.insertId });
  } catch (err) {
    await conn.rollback();
    console.error('createSquad error:', err);
    return res.status(500).json({ success: false, message: 'Server error starting team' });
  } finally {
    conn.release();
  }
}

async function joinSquad(req, res) {
  const { id: eventId, itemId, squadId } = req.params;
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const check = await lockTeamActivity(conn, req, eventId, itemId);
    if (!check.item) {
      await conn.rollback();
      return res.status(check.status).json({ success: false, message: check.message });
    }
    const { item } = check;
    const [squads] = await conn.query(
      `SELECT s.name, s.created_by_user_id,
              (SELECT COUNT(*) FROM activity_team_members tm WHERE tm.squad_id = s.id) AS size
       FROM activity_squads s WHERE s.id = ? AND s.item_id = ?`,
      [squadId, itemId]
    );
    if (squads.length === 0) {
      await conn.rollback();
      return res.status(404).json({ success: false, message: 'Team not found' });
    }
    const squad = squads[0];
    if (squad.size >= item.team_size) {
      await conn.rollback();
      return res.status(409).json({ success: false, message: `${squad.name} is full` });
    }
    await conn.query(
      'INSERT INTO activity_team_members (team_id, user_id, squad_id) VALUES (?, ?, ?)',
      [itemId, req.userId, squadId]
    );
    await conn.commit();

    if (squad.created_by_user_id !== req.userId) {
      const [[joiner]] = await pool.query('SELECT name FROM users WHERE id = ?', [req.userId]);
      createNotification(
        squad.created_by_user_id,
        'team_joined',
        'New teammate',
        `${joiner?.name || 'Someone'} joined your team ${squad.name} for ${item.name} at "${item.title}"`,
        Number(eventId)
      );
    }
    return res.status(200).json({ success: true, message: 'Joined team' });
  } catch (err) {
    await conn.rollback();
    console.error('joinSquad error:', err);
    return res.status(500).json({ success: false, message: 'Server error joining team' });
  } finally {
    conn.release();
  }
}

async function leaveEventActivity(req, res) {
  const { id: eventId, itemId } = req.params;
  try {
    const [result] = await pool.query(
      `DELETE tm FROM activity_team_members tm
       JOIN activity_teams t ON t.id = tm.team_id
       WHERE tm.team_id = ? AND t.activity_id = ? AND tm.user_id = ?`,
      [itemId, eventId, req.userId]
    );
    if (result.affectedRows === 0) {
      return res.status(400).json({ success: false, message: "You're not signed up for this" });
    }
    await deleteEmptySquads(pool, 'item_id = ?', [itemId]);
    return res.status(200).json({ success: true, message: 'Left' });
  } catch (err) {
    console.error('leaveEventActivity error:', err);
    return res.status(500).json({ success: false, message: 'Server error leaving activity' });
  }
}

async function deleteEventActivity(req, res) {
  const { id: eventId, itemId } = req.params;
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [rows] = await conn.query(
      `SELECT t.name, a.host_user_id, a.title
       FROM activity_teams t JOIN activities a ON a.id = t.activity_id
       WHERE t.id = ? AND t.activity_id = ? FOR UPDATE`,
      [itemId, eventId]
    );
    if (rows.length === 0) {
      await conn.rollback();
      return res.status(404).json({ success: false, message: 'Activity not found in this event' });
    }
    const { name, host_user_id, title } = rows[0];
    if (req.userId !== host_user_id) {
      await conn.rollback();
      return res.status(403).json({ success: false, message: 'Only the host can remove activities from this event' });
    }
    const [members] = await conn.query('SELECT user_id FROM activity_team_members WHERE team_id = ?', [itemId]);
    await conn.query('DELETE FROM activity_team_members WHERE team_id = ?', [itemId]);
    await conn.query('DELETE FROM activity_squads WHERE item_id = ?', [itemId]);
    await conn.query('DELETE FROM activity_teams WHERE id = ?', [itemId]);
    await conn.commit();

    for (const { user_id } of members) {
      createNotification(user_id, 'event_activity_removed', 'Activity removed', `${name} at "${title}" was cancelled`, Number(eventId));
    }
    return res.status(200).json({ success: true, message: 'Removed' });
  } catch (err) {
    await conn.rollback();
    console.error('deleteEventActivity error:', err);
    return res.status(500).json({ success: false, message: 'Server error removing activity' });
  } finally {
    conn.release();
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
  createEventActivity,
  joinEventActivity,
  leaveEventActivity,
  deleteEventActivity,
  createSquad,
  joinSquad,
  findActiveActivityForUser,
  getCompanionNames,
};
