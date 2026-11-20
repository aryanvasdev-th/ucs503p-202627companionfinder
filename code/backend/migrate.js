// migrate.js
// Brings an existing database up to date on server start. MySQL (unlike
// MariaDB) has no ADD COLUMN IF NOT EXISTS, so columns are checked against
// information_schema first. Every step is safe to re-run.
const pool = require('./db');
const { RENAMED_CATEGORIES } = require('./categories');

const NEW_COLUMNS = [
  // Added before migrate.js existed; listed so a users table created from
  // an old schema.sql still ends up complete.
  ['users', 'bio', 'TEXT NULL'],
  ['users', 'avatar_url', 'VARCHAR(512) NULL'],
  ['users', 'emergency_contact_name', 'VARCHAR(255) NULL'],
  ['users', 'emergency_contact_phone', 'VARCHAR(30) NULL'],
  ['users', 'gender', 'VARCHAR(30) NULL'],
  ['otp_verifications', 'purpose', "VARCHAR(20) NOT NULL DEFAULT 'verify_email'"],
  ['users', 'id_verification_status', "VARCHAR(20) NOT NULL DEFAULT 'none'"], // none | verified | failed
  ['users', 'id_verified_at', 'TIMESTAMP NULL'],
  ['users', 'id_roll_hash', 'CHAR(64) NULL'], // HMAC of the card's roll number
  ['activities', 'is_team_event', 'BOOLEAN NOT NULL DEFAULT FALSE'],
  ['activities', 'team_size', 'INT NULL'], // unused since events replaced team events
  ['activity_teams', 'starts_at', 'DATETIME NULL'], // optional time of an activity inside an event
  ['activity_teams', 'team_size', 'INT NULL'], // set = team activity (e.g. Football, teams of 11)
  ['activity_team_members', 'squad_id', 'INT NULL'], // the team this member is in, for team activities
  ['users', 'is_banned', 'BOOLEAN NOT NULL DEFAULT FALSE'], // set by an admin
  ['users', 'ban_reason', 'VARCHAR(255) NULL'],
  ['activities', 'is_featured', 'BOOLEAN NOT NULL DEFAULT FALSE'], // pinned to the top of Discover by an admin
  ['ratings', 'review_text', 'TEXT NULL'],
  ['ratings', 'tags', 'VARCHAR(255) NULL'], // comma-separated, from reviewTags.js
];

const NEW_TABLES = [
  `CREATE TABLE IF NOT EXISTS activity_teams (
     id INT AUTO_INCREMENT PRIMARY KEY,
     activity_id INT NOT NULL,
     name VARCHAR(60) NOT NULL,
     max_members INT NOT NULL,
     created_by_user_id INT NOT NULL,
     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
     FOREIGN KEY (activity_id) REFERENCES activities(id),
     FOREIGN KEY (created_by_user_id) REFERENCES users(id)
   )`,
  `CREATE TABLE IF NOT EXISTS activity_team_members (
     team_id INT NOT NULL,
     user_id INT NOT NULL,
     joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
     PRIMARY KEY (team_id, user_id),
     FOREIGN KEY (team_id) REFERENCES activity_teams(id),
     FOREIGN KEY (user_id) REFERENCES users(id)
   )`,
  `CREATE TABLE IF NOT EXISTS activity_squads (
     id INT AUTO_INCREMENT PRIMARY KEY,
     item_id INT NOT NULL,
     name VARCHAR(60) NOT NULL,
     created_by_user_id INT NOT NULL,
     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
     FOREIGN KEY (item_id) REFERENCES activity_teams(id),
     FOREIGN KEY (created_by_user_id) REFERENCES users(id)
   )`,
];

const NEW_UNIQUE_INDEXES = [
  // One Thapar ID card can verify only one account.
  ['users', 'uq_users_id_roll_hash', 'id_roll_hash'],
];

async function runMigrations() {
  // Tables first, so columns added to new tables below find them.
  for (const sql of NEW_TABLES) {
    await pool.query(sql);
  }
  for (const [table, column, definition] of NEW_COLUMNS) {
    const [rows] = await pool.query(
      `SELECT 1 FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
      [table, column]
    );
    if (rows.length === 0) {
      await pool.query(`ALTER TABLE \`${table}\` ADD COLUMN \`${column}\` ${definition}`);
      console.log(`migrate: added ${table}.${column}`);
    }
  }
  for (const [table, index, column] of NEW_UNIQUE_INDEXES) {
    const [rows] = await pool.query(
      `SELECT 1 FROM information_schema.STATISTICS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?`,
      [table, index]
    );
    if (rows.length === 0) {
      await pool.query(`ALTER TABLE \`${table}\` ADD UNIQUE INDEX \`${index}\` (\`${column}\`)`);
      console.log(`migrate: added unique index ${table}.${index}`);
    }
  }
  // Move activities off retired categories so Discover still has a chip
  // for every one of them.
  for (const [from, to] of Object.entries(RENAMED_CATEGORIES)) {
    const [result] = await pool.query('UPDATE activities SET category = ? WHERE category = ?', [to, from]);
    if (result.affectedRows > 0) {
      console.log(`migrate: moved ${result.affectedRows} activities from ${from} to ${to}`);
    }
  }
}

module.exports = { runMigrations };
