// api.test.js
// End-to-end tests for the REST API and the chat socket, run against a live
// server and a throwaway database. They create their own accounts, so they
// must never be pointed at the real database.
//
//   1. Create an empty database and load schema.sql into it.
//   2. Start the server against it with ADMIN_EMAILS=test.admin@thapar.edu and
//      EMAIL_HOST pointing at a local SMTP sink, so no real mail goes out.
//   3. TEST_API_URL=http://localhost:5055 DB_NAME=<that database> npm test
//
// One-time codes are read straight from the database rather than from mail.
// Each test is tagged with the test-case id used in the project report.

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const mysql = require('mysql2/promise');

const API = (process.env.TEST_API_URL || 'http://localhost:5055').replace(/\/$/, '');
const RUN = Date.now().toString(36);
const PASSWORD = 'Testpass#123';

let db;

before(async () => {
  if (!/test/i.test(process.env.DB_NAME || '')) {
    throw new Error('Refusing to run: DB_NAME must name a test database');
  }
  db = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME,
  });
});

after(async () => {
  await db?.end();
});

// ---------- helpers ----------

async function call(method, path, { token, body, form } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  let payload;
  if (form) {
    payload = form;
  } else if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
    payload = JSON.stringify(body);
  }
  const res = await fetch(`${API}${path}`, { method, headers, body: payload });
  let json = null;
  try {
    json = await res.json();
  } catch {
    json = null;
  }
  return { status: res.status, body: json };
}

async function latestOtp(email, purpose = 'verify_email') {
  const [rows] = await db.query(
    'SELECT otp_code FROM otp_verifications WHERE email = ? AND purpose = ? ORDER BY id DESC LIMIT 1',
    [email, purpose]
  );
  return rows[0]?.otp_code;
}

let userSeq = 0;
async function makeUser(label, { email } = {}) {
  userSeq += 1;
  const address = email || `tc.${label}.${RUN}.${userSeq}@thapar.edu`;
  const reg = await call('POST', '/api/auth/register', {
    body: { email: address, password: PASSWORD, name: `Test ${label}`, gender: 'Prefer not to say' },
  });
  assert.equal(reg.status, 201, `register ${address}: ${JSON.stringify(reg.body)}`);
  const otp = await latestOtp(address);
  const ver = await call('POST', '/api/auth/verify-otp', { body: { email: address, otp } });
  assert.equal(ver.status, 200);
  const login = await call('POST', '/api/auth/login', { body: { email: address, password: PASSWORD } });
  assert.equal(login.status, 200);
  return { email: address, token: login.body.token, id: login.body.user.id };
}

function inHours(h) {
  return new Date(Date.now() + h * 3600 * 1000).toISOString();
}

async function makeActivity(host, overrides = {}) {
  const res = await call('POST', '/api/activities', {
    token: host.token,
    body: {
      title: `Coffee at the Library Cafe ${RUN}`,
      category: 'Coffee',
      startsAt: inHours(24),
      durationMinutes: 60,
      maxPeople: 3,
      landmark: 'Library',
      ...overrides,
    },
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.activityId;
}

async function requestAndGetId(activityId, user, host) {
  const r = await call('POST', `/api/activities/${activityId}/request-join`, { token: user.token });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  const list = await call('GET', `/api/activities/${activityId}/requests`, { token: host.token });
  return list.body.requests.find((q) => q.userId === user.id || q.user?.id === user.id || q.requesterId === user.id)?.id
    ?? (await db.query(
      'SELECT id FROM activity_join_requests WHERE activity_id = ? AND user_id = ?', [activityId, user.id]
    ))[0][0].id;
}

// Tiny Socket.IO v4 client over Node's built-in WebSocket, enough for one
// authenticated connection, emits with acks, and listening for one event.
function openSocket(token) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`${API.replace(/^http/, 'ws')}/socket.io/?EIO=4&transport=websocket`);
    const acks = new Map();
    const listeners = new Map();
    let ackId = 0;
    const client = {
      emit(event, data) {
        return new Promise((res) => {
          const id = ackId++;
          acks.set(id, res);
          ws.send(`42${id}${JSON.stringify([event, data])}`);
        });
      },
      once(event) {
        return new Promise((res) => listeners.set(event, res));
      },
      close() {
        ws.close();
      },
    };
    ws.onmessage = ({ data }) => {
      const msg = String(data);
      if (msg.startsWith('0')) ws.send(`40${JSON.stringify({ token })}`);
      else if (msg === '2') ws.send('3');
      else if (msg.startsWith('40')) resolve(client);
      else if (msg.startsWith('44')) reject(new Error(JSON.parse(msg.slice(2)).message));
      else if (msg.startsWith('43')) {
        const m = msg.match(/^43(\d+)(.*)$/);
        acks.get(Number(m[1]))?.(JSON.parse(m[2])[0]);
      } else if (msg.startsWith('42')) {
        const [event, payload] = JSON.parse(msg.slice(2));
        const fn = listeners.get(event);
        if (fn) {
          listeners.delete(event);
          fn(payload);
        }
      }
    };
    ws.onerror = () => reject(new Error('socket error'));
  });
}

// ---------- authentication ----------

test('TC01 registration refuses a non-Thapar e-mail address', async () => {
  const r = await call('POST', '/api/auth/register', {
    body: { email: `someone.${RUN}@gmail.com`, password: PASSWORD, name: 'X', gender: 'Male' },
  });
  assert.equal(r.status, 400);
  assert.match(r.body.message, /@thapar\.edu/);
});

test('TC02 registration requires gender', async () => {
  const r = await call('POST', '/api/auth/register', {
    body: { email: `nogender.${RUN}@thapar.edu`, password: PASSWORD, name: 'X' },
  });
  assert.equal(r.status, 400);
  assert.match(r.body.message, /Gender/);
});

test('TC03 an unverified account cannot log in and is sent back to the code screen', async () => {
  const email = `unverified.${RUN}@thapar.edu`;
  const reg = await call('POST', '/api/auth/register', {
    body: { email, password: PASSWORD, name: 'Unverified', gender: 'Female' },
  });
  assert.equal(reg.status, 201);
  const login = await call('POST', '/api/auth/login', { body: { email, password: PASSWORD } });
  assert.equal(login.status, 403);
  assert.equal(login.body.requiresVerification, true);
});

test('TC04 a wrong one-time code is rejected and the right one verifies', async () => {
  const email = `otp.${RUN}@thapar.edu`;
  await call('POST', '/api/auth/register', { body: { email, password: PASSWORD, name: 'Otp', gender: 'Male' } });
  const code = await latestOtp(email);
  const wrong = code === '000000' ? '111111' : '000000';
  const bad = await call('POST', '/api/auth/verify-otp', { body: { email, otp: wrong } });
  assert.equal(bad.status, 400);
  assert.match(bad.body.message, /Incorrect/);
  const good = await call('POST', '/api/auth/verify-otp', { body: { email, otp: code } });
  assert.equal(good.status, 200);
});

test('TC05 an expired one-time code is rejected', async () => {
  const email = `expired.${RUN}@thapar.edu`;
  await call('POST', '/api/auth/register', { body: { email, password: PASSWORD, name: 'Exp', gender: 'Male' } });
  await db.query('UPDATE otp_verifications SET expires_at = NOW() - INTERVAL 1 MINUTE WHERE email = ?', [email]);
  const r = await call('POST', '/api/auth/verify-otp', { body: { email, otp: await latestOtp(email) } });
  assert.equal(r.status, 400);
  assert.match(r.body.message, /expired/);
});

test('TC06 resending a code inside the 60 s cooldown is refused', async () => {
  const email = `cooldown.${RUN}@thapar.edu`;
  await call('POST', '/api/auth/register', { body: { email, password: PASSWORD, name: 'Cd', gender: 'Male' } });
  const r = await call('POST', '/api/auth/resend-otp', { body: { email } });
  assert.equal(r.status, 429);
});

test('TC07 a verified address cannot be registered twice', async () => {
  const u = await makeUser('dup');
  const r = await call('POST', '/api/auth/register', {
    body: { email: u.email, password: PASSWORD, name: 'Again', gender: 'Male' },
  });
  assert.equal(r.status, 409);
});

test('TC08 login gives the same answer for a wrong password and an unknown address', async () => {
  const u = await makeUser('enum');
  const wrongPw = await call('POST', '/api/auth/login', { body: { email: u.email, password: 'nope-nope-1' } });
  const unknown = await call('POST', '/api/auth/login', {
    body: { email: `nobody.${RUN}@thapar.edu`, password: 'nope-nope-1' },
  });
  assert.equal(wrongPw.status, 401);
  assert.equal(unknown.status, 401);
  assert.equal(wrongPw.body.message, unknown.body.message);
});

test('TC09 password reset works, and forgot-password does not reveal who has an account', async () => {
  const u = await makeUser('reset');
  const known = await call('POST', '/api/auth/forgot-password', { body: { email: u.email } });
  const unknown = await call('POST', '/api/auth/forgot-password', { body: { email: `ghost.${RUN}@thapar.edu` } });
  assert.equal(known.status, 200);
  assert.equal(unknown.status, 200);
  assert.equal(known.body.message, unknown.body.message);

  const code = await latestOtp(u.email, 'reset_password');
  const short = await call('POST', '/api/auth/reset-password', { body: { email: u.email, otp: code, newPassword: 'short' } });
  assert.equal(short.status, 400);
  const ok = await call('POST', '/api/auth/reset-password', {
    body: { email: u.email, otp: code, newPassword: 'Newpass#456' },
  });
  assert.equal(ok.status, 200);
  const oldLogin = await call('POST', '/api/auth/login', { body: { email: u.email, password: PASSWORD } });
  assert.equal(oldLogin.status, 401);
  const newLogin = await call('POST', '/api/auth/login', { body: { email: u.email, password: 'Newpass#456' } });
  assert.equal(newLogin.status, 200);
});

test('TC10 a registration code cannot be used to reset a password', async () => {
  const email = `crossflow.${RUN}@thapar.edu`;
  await call('POST', '/api/auth/register', { body: { email, password: PASSWORD, name: 'Cross', gender: 'Male' } });
  const verifyCode = await latestOtp(email);
  const r = await call('POST', '/api/auth/reset-password', {
    body: { email, otp: verifyCode, newPassword: 'Hijack#789' },
  });
  assert.equal(r.status, 400);
});

test('TC11 protected routes refuse a missing or forged token', async () => {
  const none = await call('GET', '/api/activities');
  assert.equal(none.status, 401);
  const forged = await call('GET', '/api/activities', { token: 'eyJhbGciOiJIUzI1NiJ9.e30.bad' });
  assert.equal(forged.status, 401);
});

// ---------- hosting and joining ----------

test('TC12 hosting rejects an unknown category and a direct "Event" category', async () => {
  const host = await makeUser('cat');
  const unknown = await call('POST', '/api/activities', {
    token: host.token,
    body: { title: 'x', category: 'More...', startsAt: inHours(5), maxPeople: 2 },
  });
  assert.equal(unknown.status, 400);
  const event = await call('POST', '/api/activities', {
    token: host.token,
    body: { title: 'x', category: 'Event', startsAt: inHours(5), maxPeople: 2 },
  });
  assert.equal(event.status, 400);
});

test('TC13 hosting creates the activity, enrols the host and opens the group chat in one go', async () => {
  const host = await makeUser('host');
  const id = await makeActivity(host);
  const [[p]] = await db.query('SELECT COUNT(*) n FROM activity_participants WHERE activity_id = ? AND user_id = ?', [id, host.id]);
  const [[c]] = await db.query(
    `SELECT COUNT(*) n FROM conversations c JOIN conversation_participants cp ON cp.conversation_id = c.id
     WHERE c.activity_id = ? AND cp.user_id = ?`,
    [id, host.id]
  );
  assert.equal(p.n, 1);
  assert.equal(c.n, 1);
});

test('TC14 the host cannot request to join their own activity', async () => {
  const host = await makeUser('own');
  const id = await makeActivity(host);
  const r = await call('POST', `/api/activities/${id}/request-join`, { token: host.token });
  assert.equal(r.status, 400);
});

test('TC15 only the host can see and answer join requests', async () => {
  const host = await makeUser('h15');
  const guest = await makeUser('g15');
  const other = await makeUser('o15');
  const id = await makeActivity(host);
  const reqId = await requestAndGetId(id, guest, host);
  const peek = await call('GET', `/api/activities/${id}/requests`, { token: other.token });
  assert.equal(peek.status, 403);
  const hijack = await call('POST', `/api/activities/${id}/requests/${reqId}/accept`, { token: other.token });
  assert.equal(hijack.status, 403);
  const ok = await call('POST', `/api/activities/${id}/requests/${reqId}/accept`, { token: host.token });
  assert.equal(ok.status, 200);
});

test('TC16 accepting a request also admits the student to the group chat', async () => {
  const host = await makeUser('h16');
  const guest = await makeUser('g16');
  const id = await makeActivity(host);
  const reqId = await requestAndGetId(id, guest, host);
  await call('POST', `/api/activities/${id}/requests/${reqId}/accept`, { token: host.token });
  const [[c]] = await db.query(
    `SELECT COUNT(*) n FROM conversations c JOIN conversation_participants cp ON cp.conversation_id = c.id
     WHERE c.activity_id = ? AND cp.user_id = ?`,
    [id, guest.id]
  );
  assert.equal(c.n, 1);
});

test('TC17 a declined student cannot ask again for the same activity', async () => {
  const host = await makeUser('h17');
  const guest = await makeUser('g17');
  const id = await makeActivity(host);
  const reqId = await requestAndGetId(id, guest, host);
  const d = await call('POST', `/api/activities/${id}/requests/${reqId}/decline`, { token: host.token });
  assert.equal(d.status, 200);
  const again = await call('POST', `/api/activities/${id}/request-join`, { token: guest.token });
  assert.equal(again.status, 403);
});

test('TC18 a full activity refuses new requests', async () => {
  const host = await makeUser('h18');
  const guest = await makeUser('g18');
  const late = await makeUser('l18');
  const id = await makeActivity(host, { maxPeople: 2 });
  const reqId = await requestAndGetId(id, guest, host);
  await call('POST', `/api/activities/${id}/requests/${reqId}/accept`, { token: host.token });
  const r = await call('POST', `/api/activities/${id}/request-join`, { token: late.token });
  assert.equal(r.status, 409);
});

test('TC19 two accepts racing for the last place fill it exactly once', async () => {
  const host = await makeUser('h19');
  const a = await makeUser('a19');
  const b = await makeUser('b19');
  const id = await makeActivity(host, { maxPeople: 2 });
  const ra = await requestAndGetId(id, a, host);
  const rb = await requestAndGetId(id, b, host);
  const [x, y] = await Promise.all([
    call('POST', `/api/activities/${id}/requests/${ra}/accept`, { token: host.token }),
    call('POST', `/api/activities/${id}/requests/${rb}/accept`, { token: host.token }),
  ]);
  assert.deepEqual([x.status, y.status].sort(), [200, 409]);
  const [[n]] = await db.query('SELECT COUNT(*) n FROM activity_participants WHERE activity_id = ?', [id]);
  assert.equal(n.n, 2);
});

// ---------- ratings and reviews ----------

test('TC20 ratings are refused before the activity ends and checked after', async () => {
  const host = await makeUser('h20');
  const guest = await makeUser('g20');
  const outsider = await makeUser('x20');
  const id = await makeActivity(host);
  const reqId = await requestAndGetId(id, guest, host);
  await call('POST', `/api/activities/${id}/requests/${reqId}/accept`, { token: host.token });

  const early = await call('POST', `/api/activities/${id}/rate`, { token: guest.token, body: { ratedUserId: host.id, score: 4.5 } });
  assert.equal(early.status, 400);

  await db.query('UPDATE activities SET starts_at = NOW() - INTERVAL 3 HOUR WHERE id = ?', [id]);

  const self = await call('POST', `/api/activities/${id}/rate`, { token: guest.token, body: { ratedUserId: guest.id, score: 5 } });
  assert.equal(self.status, 400);
  const badScore = await call('POST', `/api/activities/${id}/rate`, { token: guest.token, body: { ratedUserId: host.id, score: 4.3 } });
  assert.equal(badScore.status, 400);
  const notThere = await call('POST', `/api/activities/${id}/rate`, { token: outsider.token, body: { ratedUserId: host.id, score: 3 } });
  assert.equal(notThere.status, 403);
  const ok = await call('POST', `/api/activities/${id}/rate`, {
    token: guest.token,
    body: { ratedUserId: host.id, score: 4.5, review: 'Showed up on time.', tags: ['Punctual', 'Not a real tag'] },
  });
  assert.equal(ok.status, 200);
  const [[row]] = await db.query('SELECT score, tags FROM ratings WHERE activity_id = ? AND rater_user_id = ?', [id, guest.id]);
  assert.equal(Number(row.score), 4.5);
  assert.equal(row.tags, 'Punctual');
});

test('TC21 a public profile shows ratings but never e-mail, phone or emergency contact', async () => {
  const u = await makeUser('pub');
  await call('PATCH', '/api/users/me/emergency-contact', { token: u.token, body: { name: 'Parent', phone: '+919999999999' } });
  const viewer = await makeUser('viewer');
  const r = await call('GET', `/api/users/${u.id}`, { token: viewer.token });
  assert.equal(r.status, 200);
  const text = JSON.stringify(r.body);
  assert.ok(!text.includes(u.email));
  assert.ok(!text.includes('+919999999999'));
});

// ---------- events ----------

test('TC22 events hold activities and teams with their own limits', async () => {
  const host = await makeUser('ev');
  const guest = await makeUser('evg');
  const outsider = await makeUser('evx');
  const ev = await call('POST', '/api/activities', {
    token: host.token,
    body: { title: `Fest ${RUN}`, isEvent: true, startsAt: inHours(48), durationMinutes: 2880, maxPeople: 500 },
  });
  assert.equal(ev.status, 201);
  const eventId = ev.body.activityId;

  const item = await call('POST', `/api/activities/${eventId}/event-activities`, {
    token: host.token,
    body: { name: 'Football', spots: 4, teamSize: 2 },
  });
  assert.ok([200, 201].includes(item.status), JSON.stringify(item.body));
  const [[it]] = await db.query('SELECT id FROM activity_teams WHERE activity_id = ? AND name = ?', [eventId, 'Football']);

  const notIn = await call('POST', `/api/activities/${eventId}/event-activities/${it.id}/join`, { token: outsider.token });
  assert.ok([400, 403].includes(notIn.status));

  const reqId = await requestAndGetId(eventId, guest, host);
  await call('POST', `/api/activities/${eventId}/requests/${reqId}/accept`, { token: host.token });
  const direct = await call('POST', `/api/activities/${eventId}/event-activities/${it.id}/join`, { token: guest.token });
  assert.equal(direct.status, 400, 'team activity must be joined through a team');
  const squad = await call('POST', `/api/activities/${eventId}/event-activities/${it.id}/teams`, {
    token: guest.token,
    body: { name: 'Red Hawks' },
  });
  assert.ok([200, 201].includes(squad.status), JSON.stringify(squad.body));
});

// ---------- chat ----------

test('TC23 a group message reaches the other member, and outsiders cannot join the room', async () => {
  const host = await makeUser('ch');
  const guest = await makeUser('chg');
  const outsider = await makeUser('chx');
  const id = await makeActivity(host);
  const reqId = await requestAndGetId(id, guest, host);
  await call('POST', `/api/activities/${id}/requests/${reqId}/accept`, { token: host.token });
  const [[conv]] = await db.query('SELECT id FROM conversations WHERE activity_id = ?', [id]);

  const hs = await openSocket(host.token);
  const gs = await openSocket(guest.token);
  const xs = await openSocket(outsider.token);
  try {
    assert.equal((await hs.emit('conversation:join', conv.id)).success, true);
    assert.equal((await gs.emit('conversation:join', conv.id)).success, true);
    assert.equal((await xs.emit('conversation:join', conv.id)).success, false);

    const arrived = gs.once('message:new');
    const sent = await hs.emit('message:send', { conversationId: conv.id, body: 'Meet at the gate' });
    assert.equal(sent.success, true);
    const msg = await arrived;
    assert.equal(msg.body, 'Meet at the gate');

    const sneaky = await xs.emit('message:send', { conversationId: conv.id, body: 'hi' });
    assert.equal(sneaky.success, false);
  } finally {
    hs.close();
    gs.close();
    xs.close();
  }
});

// ---------- safety and moderation ----------

test('TC24 SOS is refused until an emergency contact is saved', async () => {
  const u = await makeUser('sos');
  const r = await call('POST', '/api/sos', { token: u.token, body: { latitude: 30.3516, longitude: 76.3608 } });
  assert.equal(r.status, 400);
  assert.match(r.body.message, /emergency contact/);
});

test('TC25 ordinary users cannot use admin routes', async () => {
  const u = await makeUser('notadmin');
  const victim = await makeUser('victim');
  const r = await call('POST', `/api/admin/users/${victim.id}/ban`, { token: u.token, body: { reason: 'x' } });
  assert.equal(r.status, 403);
});

test('TC26 a ban takes effect at once, even on a token issued before it', async () => {
  // The admin account may already exist from an earlier run with another
  // password, so give it this run's password hash before logging in.
  const u = await makeUser('banned');
  await db.query(
    `INSERT INTO users (email, password_hash, name, is_verified)
       SELECT 'test.admin@thapar.edu', password_hash, 'Test Admin', TRUE FROM users WHERE id = ?
     ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash), is_verified = TRUE, is_banned = FALSE`,
    [u.id]
  );
  const adminLogin = await call('POST', '/api/auth/login', {
    body: { email: 'test.admin@thapar.edu', password: PASSWORD },
  });
  assert.equal(adminLogin.status, 200);
  assert.equal(adminLogin.body.user.isAdmin, true);
  const admin = { token: adminLogin.body.token, id: adminLogin.body.user.id };
  const ban = await call('POST', `/api/admin/users/${u.id}/ban`, { token: admin.token, body: { reason: 'Spam' } });
  assert.equal(ban.status, 200);
  const oldToken = await call('GET', '/api/users/me', { token: u.token });
  assert.equal(oldToken.status, 403);
  const login = await call('POST', '/api/auth/login', { body: { email: u.email, password: PASSWORD } });
  assert.equal(login.status, 403);
  assert.match(login.body.message, /suspended: Spam/);
  await assert.rejects(openSocket(u.token));
  const self = await call('POST', `/api/admin/users/${admin.id}/ban`, { token: admin.token, body: {} });
  assert.equal(self.status, 400);
});

// ---------- uploads and ID verification ----------

test('TC27 uploads over 5 MB or of the wrong type get a JSON error', async () => {
  const u = await makeUser('upload');
  const big = new FormData();
  big.append('avatar', new Blob([new Uint8Array(6 * 1024 * 1024)], { type: 'image/jpeg' }), 'big.jpg');
  const r1 = await call('POST', '/api/users/me/avatar', { token: u.token, form: big });
  assert.equal(r1.status, 400);
  assert.equal(r1.body.success, false);

  const txt = new FormData();
  txt.append('avatar', new Blob(['not an image'], { type: 'text/plain' }), 'notes.txt');
  const r2 = await call('POST', '/api/users/me/avatar', { token: u.token, form: txt });
  assert.equal(r2.status, 400);
  assert.equal(r2.body.success, false);
});

function cardPhotos() {
  const form = new FormData();
  form.append('idFront', new Blob([PNG_BLANK], { type: 'image/png' }), 'front.png');
  form.append('idBack', new Blob([PNG_BLANK], { type: 'image/png' }), 'back.png');
  return form;
}

test('TC28 ID verification needs both sides and rejects a photo that is not a Thapar card', async () => {
  // A student-format address, so the check gets as far as reading the card.
  const u = await makeUser('idcard', { email: `tcard${RUN.replace(/\d/g, '')}_be24@thapar.edu` });
  const one = new FormData();
  one.append('idFront', new Blob([PNG_BLANK], { type: 'image/png' }), 'front.png');
  const r1 = await call('POST', '/api/users/me/verify-id', { token: u.token, form: one });
  assert.equal(r1.status, 400);

  const r2 = await call('POST', '/api/users/me/verify-id', { token: u.token, form: cardPhotos() });
  assert.equal(r2.status, 422);
  assert.equal(r2.body.verified, false);
  assert.equal(r2.body.code, 'NOT_THAPAR_CARD');
  const [[row]] = await db.query('SELECT id_verification_status s FROM users WHERE id = ?', [u.id]);
  assert.equal(row.s, 'failed');
});

test('TC29 ID verification is only offered to student-format Thapar addresses', async () => {
  const staff = await makeUser('staffstyle');
  const r = await call('POST', '/api/users/me/verify-id', { token: staff.token, form: cardPhotos() });
  assert.equal(r.status, 422);
  assert.equal(r.body.code, 'EMAIL_FORMAT');
});

// A blank 64x64 PNG: valid image, no card on it.
const PNG_BLANK = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAXklEQVR4nO3PMQ0AMAzAsPInvYLYYVWKESTzjhsd8KsBrQGtAa0BrQGtAa0BrQGtAa0BrQGtAa0BrQGtAa0BrQGtAa0BrQGtAa0BrQGtAa0BrQGtAa0BrQGtAa0BbQHKU9LC7/CP1AAAAABJRU5ErkJggg==',
  'base64'
);
