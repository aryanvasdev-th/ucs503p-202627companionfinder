-- schema.sql
-- Full schema for the Campus Companion database. Run against an empty
-- `campus_companion` database to set up from scratch. Every table carries all
-- of its columns, so the file runs as-is on MySQL 8+ and MariaDB.
--
-- An older database is brought up to date by migrate.js when the server
-- starts. That is the only upgrade path: MySQL has no ADD COLUMN IF NOT
-- EXISTS, so this file used to stop at its first ALTER on a fresh MySQL
-- install and left most of the tables uncreated.

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  bio TEXT NULL,
  avatar_url VARCHAR(512) NULL,
  emergency_contact_name VARCHAR(255) NULL,
  emergency_contact_phone VARCHAR(30) NULL, -- E.164 format, e.g. +91XXXXXXXXXX; required before SOS can fire
  gender VARCHAR(30) NULL,
  -- Thapar ID card verification (see idCardService.js)
  id_verification_status VARCHAR(20) NOT NULL DEFAULT 'none', -- none | verified | failed
  id_verified_at TIMESTAMP NULL,
  id_roll_hash CHAR(64) NULL, -- HMAC of the card's roll number
  is_banned BOOLEAN NOT NULL DEFAULT FALSE, -- set by an admin
  ban_reason VARCHAR(255) NULL,
  UNIQUE KEY uq_users_id_roll_hash (id_roll_hash)
);

CREATE TABLE IF NOT EXISTS otp_verifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  otp_code VARCHAR(6) NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  -- 'purpose' distinguishes registration-verification OTPs from password-reset
  -- OTPs so a code issued for one flow can't be replayed to satisfy the other.
  purpose VARCHAR(20) NOT NULL DEFAULT 'verify_email'
);

CREATE TABLE IF NOT EXISTS activities (
  id INT AUTO_INCREMENT PRIMARY KEY,
  host_user_id INT NOT NULL,
  title VARCHAR(255) NOT NULL,
  category VARCHAR(50) NOT NULL,
  description TEXT,
  landmark VARCHAR(255),
  starts_at DATETIME NOT NULL,
  duration_minutes INT NULL, -- optional; when set, rating is gated on starts_at + this
  max_people INT NOT NULL,
  is_team_event BOOLEAN NOT NULL DEFAULT FALSE, -- TRUE = event (e.g. a fest) with activities inside it
  is_featured BOOLEAN NOT NULL DEFAULT FALSE, -- pinned to the top of Discover by an admin
  team_size INT NULL, -- unused since events replaced team events
  banner_url VARCHAR(512) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (host_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS activity_join_requests (
  id INT AUTO_INCREMENT PRIMARY KEY,
  activity_id INT NOT NULL,
  user_id INT NOT NULL,
  status ENUM('pending','accepted','declined') NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  responded_at TIMESTAMP NULL,
  UNIQUE KEY uq_request (activity_id, user_id),
  FOREIGN KEY (activity_id) REFERENCES activities(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS activity_participants (
  id INT AUTO_INCREMENT PRIMARY KEY,
  activity_id INT NOT NULL,
  user_id INT NOT NULL,
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_activity_user (activity_id, user_id),
  FOREIGN KEY (activity_id) REFERENCES activities(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS conversations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  activity_id INT NULL, -- NULL = direct 1:1 DM, set = activity group chat
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (activity_id) REFERENCES activities(id)
);

CREATE TABLE IF NOT EXISTS conversation_participants (
  conversation_id INT NOT NULL,
  user_id INT NOT NULL,
  PRIMARY KEY (conversation_id, user_id),
  FOREIGN KEY (conversation_id) REFERENCES conversations(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  conversation_id INT NOT NULL,
  sender_user_id INT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (conversation_id) REFERENCES conversations(id),
  FOREIGN KEY (sender_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS ratings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  activity_id INT NOT NULL,
  rater_user_id INT NOT NULL,
  rated_user_id INT NOT NULL,
  score DECIMAL(2,1) NOT NULL, -- 1.0-5.0 in 0.5 steps
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  review_text TEXT NULL,
  tags VARCHAR(255) NULL, -- comma-separated, from reviewTags.js
  UNIQUE KEY uq_rating (activity_id, rater_user_id, rated_user_id),
  FOREIGN KEY (activity_id) REFERENCES activities(id),
  FOREIGN KEY (rater_user_id) REFERENCES users(id),
  FOREIGN KEY (rated_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS notifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  type VARCHAR(40) NOT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT NULL,
  activity_id INT NULL,
  read_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (activity_id) REFERENCES activities(id)
);

CREATE TABLE IF NOT EXISTS sos_alerts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  activity_id INT NULL,
  latitude DECIMAL(10,7) NOT NULL,
  longitude DECIMAL(10,7) NOT NULL,
  notified_contact_phone VARCHAR(30),
  triggered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (activity_id) REFERENCES activities(id)
);

-- Activities inside an event (e.g. Football and Quiz at a fest), added by
-- the event's host. Attendees sign up via activity_team_members. (Named
-- "teams" because the feature started as team events.)
CREATE TABLE IF NOT EXISTS activity_teams (
  id INT AUTO_INCREMENT PRIMARY KEY,
  activity_id INT NOT NULL,
  name VARCHAR(60) NOT NULL,
  max_members INT NOT NULL, -- spots; the host isn't counted
  starts_at DATETIME NULL,
  team_size INT NULL, -- set = team activity, played in teams of this size
  created_by_user_id INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (activity_id) REFERENCES activities(id),
  FOREIGN KEY (created_by_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS activity_team_members (
  team_id INT NOT NULL,
  user_id INT NOT NULL,
  squad_id INT NULL, -- their team, when the activity is a team activity
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (team_id, user_id),
  FOREIGN KEY (team_id) REFERENCES activity_teams(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Teams inside a team activity at an event (e.g. "Red Hawks" for Football).
-- Attendees start one or join one with space; members point here through
-- activity_team_members.squad_id.
CREATE TABLE IF NOT EXISTS activity_squads (
  id INT AUTO_INCREMENT PRIMARY KEY,
  item_id INT NOT NULL,
  name VARCHAR(60) NOT NULL,
  created_by_user_id INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (item_id) REFERENCES activity_teams(id),
  FOREIGN KEY (created_by_user_id) REFERENCES users(id)
);
