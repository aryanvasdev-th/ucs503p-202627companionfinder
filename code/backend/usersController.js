// usersController.js
const pool = require('./db');
const { optimizeImage } = require('./imageService');
const { verifyThaparCard, IdCardError } = require('./idCardService');
const { REVIEW_TAGS } = require('./reviewTags');
const { isAdminEmail, isAdminUser } = require('./admin');

async function getMe(req, res) {
  try {
    const [rows] = await pool.query(
      `SELECT id, email, name, bio, avatar_url, gender, emergency_contact_name, emergency_contact_phone,
              id_verification_status, id_verified_at
       FROM users WHERE id = ?`,
      [req.userId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    return res.status(200).json({ success: true, user: { ...rows[0], isAdmin: isAdminEmail(rows[0].email) } });
  } catch (err) {
    console.error('getMe error:', err);
    return res.status(500).json({ success: false, message: 'Server error fetching profile' });
  }
}

async function updateMe(req, res) {
  try {
    const { name, bio, avatarUrl, gender } = req.body;
    await pool.query(
      'UPDATE users SET name = COALESCE(?, name), bio = COALESCE(?, bio), avatar_url = COALESCE(?, avatar_url), gender = COALESCE(?, gender) WHERE id = ?',
      [name ?? null, bio ?? null, avatarUrl ?? null, gender ?? null, req.userId]
    );
    return res.status(200).json({ success: true, message: 'Profile updated' });
  } catch (err) {
    console.error('updateMe error:', err);
    return res.status(500).json({ success: false, message: 'Server error updating profile' });
  }
}

async function updateEmergencyContact(req, res) {
  try {
    const { name, phone } = req.body;
    if (!name || !phone) {
      return res.status(400).json({ success: false, message: 'name and phone are required' });
    }
    await pool.query(
      'UPDATE users SET emergency_contact_name = ?, emergency_contact_phone = ? WHERE id = ?',
      [name, phone, req.userId]
    );
    return res.status(200).json({ success: true, message: 'Emergency contact updated' });
  } catch (err) {
    console.error('updateEmergencyContact error:', err);
    return res.status(500).json({ success: false, message: 'Server error updating emergency contact' });
  }
}

async function uploadAvatar(req, res) {
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'No image file provided' });
  }
  try {
    const filename = await optimizeImage(req.file.path, 'avatar');
    const avatarUrl = `/uploads/avatars/${filename}`;
    await pool.query('UPDATE users SET avatar_url = ? WHERE id = ?', [avatarUrl, req.userId]);
    return res.status(200).json({ success: true, avatarUrl });
  } catch (err) {
    console.error('uploadAvatar error:', err);
    return res.status(500).json({ success: false, message: 'Server error uploading avatar' });
  }
}

// Public profile: what another student sees when they tap someone's name.
// Deliberately leaves out email, phone and emergency contact.
async function getPublicProfile(req, res) {
  const userId = Number(req.params.id);
  if (!Number.isInteger(userId)) {
    return res.status(400).json({ success: false, message: 'Invalid user id' });
  }
  try {
    const [users] = await pool.query(
      `SELECT id, email, name, bio, avatar_url, gender, id_verification_status, is_banned, ban_reason, created_at
       FROM users WHERE id = ?`,
      [userId]
    );
    if (users.length === 0) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    const user = users[0];
    const viewerIsAdmin = await isAdminUser(req.userId);

    const [[counts]] = await pool.query(
      `SELECT
         (SELECT COUNT(*) FROM activities WHERE host_user_id = ?) AS hosted,
         (SELECT COUNT(*) FROM activity_participants p JOIN activities a ON a.id = p.activity_id
           WHERE p.user_id = ? AND a.host_user_id != ?) AS joined,
         (SELECT AVG(score) FROM ratings WHERE rated_user_id = ?) AS avg_rating,
         (SELECT COUNT(*) FROM ratings WHERE rated_user_id = ?) AS rating_count`,
      [userId, userId, userId, userId, userId]
    );

    // Star histogram, bucketed by whole star (4.5 counts toward 4).
    const [buckets] = await pool.query(
      `SELECT FLOOR(score) AS stars, COUNT(*) AS n FROM ratings WHERE rated_user_id = ? GROUP BY FLOOR(score)`,
      [userId]
    );
    const distribution = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
    for (const b of buckets) distribution[Number(b.stars)] = Number(b.n);

    const [tagRows] = await pool.query(
      'SELECT tags FROM ratings WHERE rated_user_id = ? AND tags IS NOT NULL',
      [userId]
    );
    const tagCounts = {};
    for (const { tags } of tagRows) {
      for (const tag of tags.split(',')) {
        if (REVIEW_TAGS.includes(tag)) tagCounts[tag] = (tagCounts[tag] || 0) + 1;
      }
    }
    const topTags = Object.entries(tagCounts)
      .sort((a, b) => b[1] - a[1])
      .map(([tag, count]) => ({ tag, count }));

    const [reviews] = await pool.query(
      `SELECT r.id, r.score, r.review_text, r.tags, r.created_at, r.rater_user_id, u.name AS rater_name,
              a.id AS activity_id, a.title AS activity_title, a.host_user_id = r.rated_user_id AS as_host
       FROM ratings r
       JOIN users u ON u.id = r.rater_user_id
       JOIN activities a ON a.id = r.activity_id
       WHERE r.rated_user_id = ?
       ORDER BY r.created_at DESC
       LIMIT 30`,
      [userId]
    );

    const [upcoming] = await pool.query(
      `SELECT id, title, category, starts_at FROM activities
       WHERE host_user_id = ? AND starts_at >= NOW() ORDER BY starts_at ASC LIMIT 5`,
      [userId]
    );

    return res.status(200).json({
      success: true,
      profile: {
        id: user.id,
        name: user.name,
        bio: user.bio,
        avatarUrl: user.avatar_url,
        gender: user.gender,
        verified: user.id_verification_status === 'verified',
        // "Team Companion" badge for the app's maker.
        isAdmin: isAdminEmail(user.email),
        // Moderation state is only shown to admins.
        ...(viewerIsAdmin ? { isBanned: !!user.is_banned, banReason: user.ban_reason } : {}),
        memberSince: user.created_at,
        stats: {
          hosted: Number(counts.hosted),
          joined: Number(counts.joined),
          avgRating: counts.avg_rating === null ? null : Number(counts.avg_rating),
          ratingCount: Number(counts.rating_count),
        },
        ratingDistribution: distribution,
        topTags,
        reviews: reviews.map((r) => ({
          id: r.id,
          score: Number(r.score),
          text: r.review_text,
          tags: r.tags ? r.tags.split(',') : [],
          reviewerId: r.rater_user_id,
          reviewerName: r.rater_name,
          activityId: r.activity_id,
          activityTitle: r.activity_title,
          asHost: !!r.as_host,
          createdAt: r.created_at,
        })),
        upcomingHosted: upcoming.map((a) => ({
          id: a.id,
          title: a.title,
          category: a.category,
          startsAt: a.starts_at,
        })),
      },
    });
  } catch (err) {
    console.error('getPublicProfile error:', err);
    return res.status(500).json({ success: false, message: 'Server error fetching profile' });
  }
}

async function searchUsers(req, res) {
  const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
  if (q.length < 2) {
    return res.status(200).json({ success: true, users: [] });
  }
  try {
    const [rows] = await pool.query(
      `SELECT u.id, u.name, u.avatar_url, u.id_verification_status = 'verified' AS verified,
              (SELECT AVG(score) FROM ratings r WHERE r.rated_user_id = u.id) AS avg_rating,
              (SELECT COUNT(*) FROM ratings r WHERE r.rated_user_id = u.id) AS rating_count
       FROM users u
       WHERE u.is_verified = TRUE AND u.name LIKE ? AND u.id != ?
       ORDER BY u.name ASC LIMIT 25`,
      [`%${q}%`, req.userId]
    );
    return res.status(200).json({
      success: true,
      users: rows.map((r) => ({
        id: r.id,
        name: r.name,
        avatarUrl: r.avatar_url,
        verified: !!r.verified,
        avgRating: r.avg_rating === null ? null : Number(r.avg_rating),
        ratingCount: Number(r.rating_count),
      })),
    });
  } catch (err) {
    console.error('searchUsers error:', err);
    return res.status(500).json({ success: false, message: 'Server error searching users' });
  }
}

// Thapar ID verification (see idCardService.js): OCR on the card front,
// barcode on the back, both matched to the account's OTP-verified email.
// Photos are only held in memory; we store the outcome and a keyed hash of
// the roll number so one card can't verify two accounts.
async function verifyId(req, res) {
  const front = req.files?.idFront?.[0];
  const back = req.files?.idBack?.[0];
  if (!front || !back) {
    return res.status(400).json({ success: false, message: 'Photos of both the front and back of your ID card are required' });
  }
  try {
    const [[user]] = await pool.query('SELECT email FROM users WHERE id = ?', [req.userId]);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const result = await verifyThaparCard({ frontBuffer: front.buffer, backBuffer: back.buffer, email: user.email });

    const [taken] = await pool.query(
      'SELECT id FROM users WHERE id_roll_hash = ? AND id != ?',
      [result.rollHash, req.userId]
    );
    if (taken.length > 0) {
      return res.status(409).json({
        success: false,
        code: 'CARD_ALREADY_USED',
        message: 'This ID card is already linked to another account.',
      });
    }

    await pool.query(
      `UPDATE users SET id_verification_status = 'verified', id_verified_at = NOW(), id_roll_hash = ? WHERE id = ?`,
      [result.rollHash, req.userId]
    );
    return res.status(200).json({
      success: true,
      verified: true,
      checks: result.checks,
      message: "You're verified! Your Thapar ID card matches your account.",
    });
  } catch (err) {
    if (err instanceof IdCardError) {
      await pool
        .query(
          `UPDATE users SET id_verification_status = 'failed' WHERE id = ? AND id_verification_status != 'verified'`,
          [req.userId]
        )
        .catch(() => {});
      return res.status(422).json({ success: false, verified: false, code: err.code, message: err.message });
    }
    if (err?.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        success: false,
        code: 'CARD_ALREADY_USED',
        message: 'This ID card is already linked to another account.',
      });
    }
    console.error('verifyId error:', err);
    return res.status(500).json({ success: false, message: 'Server error verifying ID' });
  }
}

module.exports = {
  getMe,
  updateMe,
  updateEmergencyContact,
  uploadAvatar,
  getPublicProfile,
  searchUsers,
  verifyId,
};
