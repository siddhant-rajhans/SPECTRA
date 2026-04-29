import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../database.js';
import { asyncHandler } from '../middleware/errorHandler.js';

const router = express.Router();
const DEFAULT_USER_ID = 'default-user';

// Demo transcription lines for simulation
const DEMO_LINES = [
  { speaker: 'Speaker 1', text: 'Hi, how are you doing today?' },
  { speaker: 'You', text: "I'm doing well, thanks for asking." },
  { speaker: 'Speaker 1', text: "Great to hear! I wanted to discuss the project timeline." },
  { speaker: 'You', text: 'Sure, I had some thoughts about that.' },
  { speaker: 'Speaker 1', text: 'The deadline is next Friday. Do you think we can make it?' },
  { speaker: 'You', text: 'I think so, if we prioritize the core features first.' },
  { speaker: 'Speaker 1', text: 'Good idea. Let me check with the team and confirm.' },
  { speaker: 'Speaker 2', text: 'Hey, sorry I am late! What did I miss?' },
  { speaker: 'Speaker 1', text: 'We were just talking about the project deadline.' },
  { speaker: 'Speaker 2', text: 'Ah perfect, I have some updates on the design side.' },
  { speaker: 'You', text: "That's great, let's hear it." },
  { speaker: 'Speaker 2', text: 'The mockups are ready and the client approved them yesterday.' }
];

// Active simulation intervals
const activeSimulations = new Map();

function simulateTranscriptionLines(sessionId, userId) {
  let lineIndex = 0;
  let seconds = 0;

  const interval = setInterval(() => {
    if (lineIndex >= DEMO_LINES.length) {
      clearInterval(interval);
      activeSimulations.delete(sessionId);
      return;
    }

    try {
      const db = getDb();

      // Check if session is still active
      const session = db.prepare('SELECT ended_at FROM transcription_sessions WHERE id = ?').get(sessionId);
      if (!session || session.ended_at) {
        clearInterval(interval);
        activeSimulations.delete(sessionId);
        return;
      }

      const line = DEMO_LINES[lineIndex];
      seconds += 2 + Math.floor(Math.random() * 3);
      const mins = Math.floor(seconds / 60);
      const secs = seconds % 60;
      const timestamp = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;

      db.prepare(`
        INSERT INTO transcription_lines (id, session_id, speaker_label, text, timestamp)
        VALUES (?, ?, ?, ?, ?)
      `).run(uuidv4(), sessionId, line.speaker, line.text, timestamp);

      lineIndex++;
    } catch (err) {
      console.error('Error simulating transcription line:', err);
      clearInterval(interval);
      activeSimulations.delete(sessionId);
    }
  }, 2000 + Math.floor(Math.random() * 1500)); // every 2-3.5 seconds

  activeSimulations.set(sessionId, interval);
}

/**
 * GET /api/transcribe/sessions
 * Get transcription sessions for user
 * Query params: limit, offset, status (active/ended)
 */
router.get(
  '/sessions',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || DEFAULT_USER_ID;
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const offset = parseInt(req.query.offset) || 0;
    const status = req.query.status; // 'active', 'ended', or null for all

    try {
      let query = `
        SELECT id, user_id, started_at, ended_at, speaker_count
        FROM transcription_sessions
        WHERE user_id = ?
      `;

      const params = [userId];

      if (status === 'active') {
        query += ' AND ended_at IS NULL';
      } else if (status === 'ended') {
        query += ' AND ended_at IS NOT NULL';
      }

      query += ' ORDER BY started_at DESC LIMIT ? OFFSET ?';
      params.push(limit, offset);

      const sessions = db.prepare(query).all(...params);

      // Get total count
      let countQuery = 'SELECT COUNT(*) as count FROM transcription_sessions WHERE user_id = ?';
      const countParams = [userId];

      if (status === 'active') {
        countQuery += ' AND ended_at IS NULL';
      } else if (status === 'ended') {
        countQuery += ' AND ended_at IS NOT NULL';
      }

      const totalCount = db.prepare(countQuery).get(...countParams);

      res.json({
        success: true,
        data: sessions,
        pagination: {
          limit,
          offset,
          total: totalCount.count,
          hasMore: offset + limit < totalCount.count
        }
      });
    } catch (error) {
      console.error('Error fetching transcription sessions:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch transcription sessions'
      });
    }
  })
);

/**
 * POST /api/transcribe/sessions
 * Start a new transcription session
 * Body: {
 *   speakerCount?: number
 * }
 */
router.post(
  '/sessions',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || req.body.userId || DEFAULT_USER_ID;
    const { speakerCount } = req.body;

    try {
      const sessionId = uuidv4();
      const stmt = db.prepare(`
        INSERT INTO transcription_sessions (id, user_id, speaker_count)
        VALUES (?, ?, ?)
      `);

      stmt.run(sessionId, userId, parseInt(speakerCount) || 0);

      const session = db
        .prepare('SELECT * FROM transcription_sessions WHERE id = ?')
        .get(sessionId);

      // Start simulated transcription lines in background (demo mode)
      simulateTranscriptionLines(sessionId, userId);

      res.status(201).json({
        success: true,
        data: session,
        message: 'Transcription session started'
      });
    } catch (error) {
      console.error('Error creating transcription session:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to start transcription session'
      });
    }
  })
);

/**
 * PUT /api/transcribe/sessions/:id
 * End a transcription session
 * Body: {
 *   speakerCount?: number (update if needed)
 * }
 */
router.put(
  '/sessions/:id',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { id } = req.params;
    const userId = req.query.userId || req.body.userId || DEFAULT_USER_ID;
    const { speakerCount } = req.body;

    try {
      // Check if session exists
      const session = db
        .prepare('SELECT id FROM transcription_sessions WHERE id = ? AND user_id = ?')
        .get(id, userId);

      if (!session) {
        return res.status(404).json({
          success: false,
          error: 'Session not found'
        });
      }

      // Update session
      const updates = ['ended_at = CURRENT_TIMESTAMP'];
      const values = [];

      if (typeof speakerCount === 'number') {
        updates.push('speaker_count = ?');
        values.push(speakerCount);
      }

      const stmt = db.prepare(`
        UPDATE transcription_sessions
        SET ${updates.join(', ')}
        WHERE id = ? AND user_id = ?
      `);

      stmt.run(...values, id, userId);

      const updated = db
        .prepare('SELECT * FROM transcription_sessions WHERE id = ?')
        .get(id);

      res.json({
        success: true,
        data: updated,
        message: 'Transcription session ended'
      });
    } catch (error) {
      console.error('Error ending transcription session:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to end transcription session'
      });
    }
  })
);

/**
 * GET /api/transcribe/sessions/:id/lines
 * Get transcription lines for a session
 * Query params: limit, offset
 */
router.get(
  '/sessions/:id/lines',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { id } = req.params;
    const userId = req.query.userId || DEFAULT_USER_ID;
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const offset = parseInt(req.query.offset) || 0;

    try {
      // Verify session belongs to user
      const session = db
        .prepare('SELECT id FROM transcription_sessions WHERE id = ? AND user_id = ?')
        .get(id, userId);

      if (!session) {
        return res.status(404).json({
          success: false,
          error: 'Session not found'
        });
      }

      const lines = db
        .prepare(`
          SELECT id, session_id, speaker_label, text, timestamp, created_at
          FROM transcription_lines
          WHERE session_id = ?
          ORDER BY created_at ASC
          LIMIT ? OFFSET ?
        `)
        .all(id, limit, offset);

      const totalCount = db
        .prepare('SELECT COUNT(*) as count FROM transcription_lines WHERE session_id = ?')
        .get(id);

      res.json({
        success: true,
        data: lines,
        pagination: {
          limit,
          offset,
          total: totalCount.count,
          hasMore: offset + limit < totalCount.count
        }
      });
    } catch (error) {
      console.error('Error fetching transcription lines:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch transcription lines'
      });
    }
  })
);

/**
 * POST /api/transcribe/sessions/:id/lines
 * Add a transcription line to a session
 * Body: {
 *   speakerLabel: string (optional, e.g., 'Speaker 1', 'You', 'Person A'),
 *   text: string,
 *   timestamp?: string (e.g., "00:15:32")
 * }
 */
router.post(
  '/sessions/:id/lines',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { id } = req.params;
    const userId = req.query.userId || req.body.userId || DEFAULT_USER_ID;
    const { speakerLabel, text, timestamp } = req.body;

    // Validate input
    if (!text || typeof text !== 'string') {
      return res.status(400).json({
        success: false,
        error: 'Text is required'
      });
    }

    try {
      // Check if session exists
      const session = db
        .prepare('SELECT id FROM transcription_sessions WHERE id = ? AND user_id = ?')
        .get(id, userId);

      if (!session) {
        return res.status(404).json({
          success: false,
          error: 'Session not found'
        });
      }

      const lineId = uuidv4();
      const stmt = db.prepare(`
        INSERT INTO transcription_lines (id, session_id, speaker_label, text, timestamp)
        VALUES (?, ?, ?, ?, ?)
      `);

      stmt.run(lineId, id, speakerLabel || null, text.trim(), timestamp || null);

      const line = db.prepare('SELECT * FROM transcription_lines WHERE id = ?').get(lineId);

      res.status(201).json({
        success: true,
        data: line,
        message: 'Transcription line added'
      });
    } catch (error) {
      console.error('Error adding transcription line:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to add transcription line'
      });
    }
  })
);

/**
 * GET /api/transcribe/sessions/:id/export
 * Export transcription session as text
 */
router.get(
  '/sessions/:id/export',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { id } = req.params;
    const userId = req.query.userId || DEFAULT_USER_ID;
    const format = req.query.format || 'txt'; // 'txt' or 'json'

    try {
      // Verify session belongs to user
      const session = db
        .prepare('SELECT * FROM transcription_sessions WHERE id = ? AND user_id = ?')
        .get(id, userId);

      if (!session) {
        return res.status(404).json({
          success: false,
          error: 'Session not found'
        });
      }

      const lines = db
        .prepare(`
          SELECT speaker_label, text, timestamp
          FROM transcription_lines
          WHERE session_id = ?
          ORDER BY created_at ASC
        `)
        .all(id);

      if (format === 'json') {
        return res.json({
          success: true,
          data: {
            session,
            lines
          }
        });
      }

      // Plain text format
      let text = `Transcription Session\n`;
      text += `Started: ${session.started_at}\n`;
      if (session.ended_at) {
        text += `Ended: ${session.ended_at}\n`;
      }
      text += `Speakers: ${session.speaker_count}\n`;
      text += `\n${'='.repeat(50)}\n\n`;

      lines.forEach(line => {
        const timestamp = line.timestamp ? `[${line.timestamp}] ` : '';
        const speaker = line.speaker_label ? `${line.speaker_label}: ` : '';
        text += `${timestamp}${speaker}${line.text}\n`;
      });

      res.type('text/plain').send(text);
    } catch (error) {
      console.error('Error exporting transcription:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to export transcription'
      });
    }
  })
);

export default router;
