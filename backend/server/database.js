import initSqlJs from 'sql.js';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { v4 as uuidv4 } from 'uuid';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const dbDir = path.join(__dirname, '../data');
const dbPath = path.join(dbDir, 'auralis.db');

let db = null;

/**
 * Compatibility wrapper around sql.js to match better-sqlite3 API.
 * All route files use: db.prepare(sql).all(...params), .get(...params), .run(...params)
 * This wrapper provides exactly that interface using sql.js under the hood.
 */
class CompatDb {
  constructor(sqliteDb) {
    this._db = sqliteDb;
  }

  prepare(sql) {
    const database = this._db;
    const self = this;
    return {
      all(...params) {
        try {
          const stmt = database.prepare(sql);
          if (params.length > 0) stmt.bind(params);
          const results = [];
          while (stmt.step()) {
            results.push(stmt.getAsObject());
          }
          stmt.free();
          return results;
        } catch (e) {
          console.error('SQL all() error:', sql.substring(0, 80), e.message);
          throw e;
        }
      },
      get(...params) {
        try {
          const stmt = database.prepare(sql);
          if (params.length > 0) stmt.bind(params);
          let result = undefined;
          if (stmt.step()) {
            result = stmt.getAsObject();
          }
          stmt.free();
          return result;
        } catch (e) {
          console.error('SQL get() error:', sql.substring(0, 80), e.message);
          throw e;
        }
      },
      run(...params) {
        try {
          database.run(sql, params);
          const result = { changes: database.getRowsModified() };
          // Auto-save after writes (debounced via the outer class)
          if (self._saveTimer) clearTimeout(self._saveTimer);
          self._saveTimer = setTimeout(() => self._save(), 500);
          return result;
        } catch (e) {
          console.error('SQL run() error:', sql.substring(0, 80), e.message);
          throw e;
        }
      }
    };
  }

  exec(sql) {
    try {
      this._db.exec(sql);
    } catch (e) {
      console.error('SQL exec() error:', e.message);
      throw e;
    }
  }

  pragma(str) {
    try {
      this._db.exec(`PRAGMA ${str}`);
    } catch (e) {
      // Ignore pragma errors (WAL mode not supported in sql.js)
    }
  }

  close() {
    this._save();
    this._db.close();
  }

  _save() {
    try {
      const data = this._db.export();
      const buffer = Buffer.from(data);
      if (!fs.existsSync(dbDir)) {
        fs.mkdirSync(dbDir, { recursive: true });
      }
      fs.writeFileSync(dbPath, buffer);
    } catch (e) {
      console.error('Error saving database:', e.message);
    }
  }
}

/**
 * Initialize database (async — must be awaited)
 */
export async function initialize() {
  const SQL = await initSqlJs();

  let sqliteDb;
  if (fs.existsSync(dbPath)) {
    try {
      const fileBuffer = fs.readFileSync(dbPath);
      sqliteDb = new SQL.Database(fileBuffer);
    } catch (e) {
      console.log('Creating fresh database');
      sqliteDb = new SQL.Database();
    }
  } else {
    if (!fs.existsSync(dbDir)) {
      fs.mkdirSync(dbDir, { recursive: true });
    }
    sqliteDb = new SQL.Database();
  }

  db = new CompatDb(sqliteDb);
  db.pragma('foreign_keys = ON');

  createTables();
  seedDefaultData();
  db._save();

  return db;
}

/**
 * Get database instance (synchronous — call after initialize())
 */
export function getDb() {
  if (!db) {
    throw new Error('Database not initialized. Call initialize() first.');
  }
  return db;
}

// ─── Table Creation ───────────────────────────────────────────

function createTables() {
  db.exec(`CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT, avatar_initial TEXT,
    device_brand TEXT, device_model TEXT, hearing_loss_level TEXT DEFAULT 'Moderate',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  db.exec(`CREATE TABLE IF NOT EXISTS auth (
    id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL,
    user_id TEXT NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  )`);

  db.exec(`CREATE TABLE IF NOT EXISTS sound_alerts (
    id TEXT PRIMARY KEY, user_id TEXT NOT NULL, sound_type TEXT NOT NULL,
    confidence REAL DEFAULT 0.85, was_delivered BOOLEAN DEFAULT 0,
    delivery_reason TEXT, context_location TEXT, context_calendar TEXT,
    context_time_of_day TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  )`);

  db.exec(`CREATE TABLE IF NOT EXISTS iml_feedback (
    id TEXT PRIMARY KEY, alert_id TEXT NOT NULL, user_id TEXT NOT NULL,
    original_classification TEXT NOT NULL, is_correct BOOLEAN,
    corrected_classification TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (alert_id) REFERENCES sound_alerts(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
  )`);

  db.exec(`CREATE TABLE IF NOT EXISTS context_rules (
    id TEXT PRIMARY KEY, user_id TEXT NOT NULL, name TEXT NOT NULL,
    description TEXT, condition_type TEXT NOT NULL, condition_value TEXT NOT NULL,
    alert_action TEXT NOT NULL, priority INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  )`);

  db.exec(`CREATE TABLE IF NOT EXISTS hearing_programs (
    id TEXT PRIMARY KEY, user_id TEXT NOT NULL, name TEXT NOT NULL,
    description TEXT, icon TEXT, speech_enhancement INTEGER DEFAULT 75,
    noise_reduction INTEGER DEFAULT 60, forward_focus INTEGER DEFAULT 50,
    is_selected BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  )`);

  db.exec(`CREATE TABLE IF NOT EXISTS device_status (
    id TEXT PRIMARY KEY, user_id TEXT NOT NULL, device_name TEXT,
    battery_level INTEGER DEFAULT 100, is_connected BOOLEAN DEFAULT 1,
    current_program TEXT, last_seen_location TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  )`);

  db.exec(`CREATE TABLE IF NOT EXISTS transcription_sessions (
    id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
    started_at DATETIME DEFAULT CURRENT_TIMESTAMP, ended_at DATETIME,
    speaker_count INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
  )`);

  db.exec(`CREATE TABLE IF NOT EXISTS transcription_lines (
    id TEXT PRIMARY KEY, session_id TEXT NOT NULL, speaker_label TEXT,
    text TEXT NOT NULL, timestamp TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id) REFERENCES transcription_sessions(id)
  )`);

  db.exec(`CREATE TABLE IF NOT EXISTS implant_accounts (
    id TEXT PRIMARY KEY, user_id TEXT NOT NULL, provider TEXT NOT NULL,
    provider_account_id TEXT, display_name TEXT, device_model TEXT,
    battery_level INTEGER, firmware_version TEXT, is_connected BOOLEAN DEFAULT 0,
    last_synced_at DATETIME, features TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  )`);
}

// ─── Seed Data ────────────────────────────────────────────────

function seedDefaultData() {
  const uid = 'default-user';

  const existing = db.prepare('SELECT id FROM users WHERE id = ?').get(uid);
  if (existing) return;

  // User
  db.prepare(`INSERT INTO users (id,name,email,avatar_initial,device_brand,device_model,hearing_loss_level) VALUES (?,?,?,?,?,?,?)`)
    .run(uid, 'Maruthi', 'mkunchal@stevens.edu', 'M', 'Cochlear', 'Nucleus 7', 'Profound');

  // Auth (password: demo123)
  const hash = crypto.createHash('sha256').update('demo123').digest('hex');
  db.prepare(`INSERT INTO auth (id,email,password_hash,user_id) VALUES (?,?,?,?)`)
    .run(uuidv4(), 'mkunchal@stevens.edu', hash, uid);

  // Context rules
  const rules = [
    ['Meeting Mode', 'When calendar shows a meeting, suppress doorbell & name alerts.', 'calendar_event', 'in_meeting', 'suppress_non_critical', 0],
    ['Sleep Mode', 'Active 10PM-7AM. Only critical alerts.', 'time_range', '22:00-07:00', 'critical_only', 1],
    ['Outdoors Mode', 'Prioritize car horns and sirens near roads.', 'location', 'outdoors', 'prioritize_environmental', 2],
    ['Restaurant Mode', 'Boost name detection, suppress timer alerts.', 'location', 'restaurant', 'enhance_speech', 3]
  ];
  rules.forEach(([n, d, ct, cv, aa, p]) => {
    db.prepare(`INSERT INTO context_rules (id,user_id,name,description,condition_type,condition_value,alert_action,priority) VALUES (?,?,?,?,?,?,?,?)`)
      .run(uuidv4(), uid, n, d, ct, cv, aa, p);
  });

  // Hearing programs
  const progs = [
    ['Home / Quiet', 'Balanced, natural sound', 'home', 75, 60, 50, 1],
    ['Restaurant / Crowd', 'Focus on speech, reduce background', 'utensils', 90, 85, 70, 0],
    ['Music / Media', 'Rich audio, wide frequency range', 'music', 60, 40, 30, 0],
    ['Outdoors / Transit', 'Wind reduction, awareness mode', 'car', 70, 75, 60, 0],
    ['Sleep Mode', 'Alarms only, all other sounds muted', 'moon', 20, 90, 10, 0]
  ];
  progs.forEach(([n, d, ic, se, nr, ff, sel]) => {
    db.prepare(`INSERT INTO hearing_programs (id,user_id,name,description,icon,speech_enhancement,noise_reduction,forward_focus,is_selected) VALUES (?,?,?,?,?,?,?,?,?)`)
      .run(uuidv4(), uid, n, d, ic, se, nr, ff, sel);
  });

  // Device status
  db.prepare(`INSERT INTO device_status (id,user_id,device_name,battery_level,is_connected,current_program) VALUES (?,?,?,?,?,?)`)
    .run(uuidv4(), uid, 'Cochlear Nucleus 7', 72, 1, 'Home / Quiet');

  // Seed alerts
  const alertIds = [];
  const alerts = [
    ['doorbell', 0.94, 1, 'Home · Saturday morning → Delivered', 'home', null, 'morning'],
    ['name_called', 0.78, 0, 'Office · Meeting on calendar → Suppressed', 'office', 'Team Standup', 'morning'],
    ['fire_alarm', 0.99, 1, 'Critical → Always delivered', 'home', null, 'morning'],
    ['alarm_timer', 0.97, 1, 'Sleep mode → Delivered (alarm allowed)', 'home', null, 'night'],
    ['car_horn', 0.91, 1, 'Outdoors · Near road → High priority', 'street', null, 'afternoon']
  ];
  alerts.forEach(([type, conf, del, reason, loc, cal, tod]) => {
    const id = uuidv4();
    alertIds.push({ id, type });
    db.prepare(`INSERT INTO sound_alerts (id,user_id,sound_type,confidence,was_delivered,delivery_reason,context_location,context_calendar,context_time_of_day) VALUES (?,?,?,?,?,?,?,?,?)`)
      .run(id, uid, type, conf, del, reason, loc, cal, tod);
  });

  // IML feedback
  if (alertIds.length >= 3) {
    db.prepare(`INSERT INTO iml_feedback (id,alert_id,user_id,original_classification,is_correct,corrected_classification) VALUES (?,?,?,?,?,?)`)
      .run(uuidv4(), alertIds[0].id, uid, alertIds[0].type, 1, null);
    db.prepare(`INSERT INTO iml_feedback (id,alert_id,user_id,original_classification,is_correct,corrected_classification) VALUES (?,?,?,?,?,?)`)
      .run(uuidv4(), alertIds[2].id, uid, alertIds[2].type, 1, null);
  }

  // Implant account
  db.prepare(`INSERT INTO implant_accounts (id,user_id,provider,display_name,device_model,battery_level,firmware_version,is_connected,features) VALUES (?,?,?,?,?,?,?,?,?)`)
    .run(uuidv4(), uid, 'cochlear', 'My Cochlear Account', 'Nucleus 7', 72, 'v5.2.1', 1,
      JSON.stringify(['Remote control', 'Battery monitoring', 'Program switching', 'Bluetooth streaming', 'Find my device', 'Hearing health tracking']));

  // Seed test user (demo@demo.demo / demodemo)
  const testUserId = 'test-user-demo';
  const existing_test = db.prepare('SELECT id FROM users WHERE id = ?').get(testUserId);
  if (!existing_test) {
    db.prepare(`INSERT INTO users (id,name,email,avatar_initial,device_brand,device_model,hearing_loss_level) VALUES (?,?,?,?,?,?,?)`)
      .run(testUserId, 'Demo Tester', 'demo@demo.demo', 'D', 'Other', 'Test Device', 'Moderate');

    // Auth (password: demodemo)
    const testHash = crypto.createHash('sha256').update('demodemo').digest('hex');
    db.prepare(`INSERT INTO auth (id,email,password_hash,user_id) VALUES (?,?,?,?)`)
      .run(uuidv4(), 'demo@demo.demo', testHash, testUserId);

    // Device status
    db.prepare(`INSERT INTO device_status (id,user_id,device_name,battery_level,is_connected,current_program) VALUES (?,?,?,?,?,?)`)
      .run(uuidv4(), testUserId, 'Test Device', 85, 1, 'Home / Quiet');
  }
}

// ─── Utilities ────────────────────────────────────────────────

export function saveDb() {
  if (db) db._save();
}

export function closeDb() {
  if (db) {
    db.close();
    db = null;
  }
}

export default { initialize, getDb, closeDb, saveDb };
