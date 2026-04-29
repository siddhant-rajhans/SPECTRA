import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../database.js';
import { asyncHandler, validators } from '../middleware/errorHandler.js';
import {
  evaluateContext,
  applyContextualDecision,
  getActiveRules
} from '../services/contextEngine.js';
import { classifySound, simulateAmbientListening } from '../services/soundClassifier.js';
import { broadcastAlert } from '../websocket.js';

const router = express.Router();
const DEFAULT_USER_ID = 'default-user';

/**
 * GET /api/alerts
 * Get all alerts for user with pagination
 */
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || DEFAULT_USER_ID;
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const offset = parseInt(req.query.offset) || 0;

    try {
      const alerts = db
        .prepare(`
          SELECT id, sound_type, confidence, was_delivered, delivery_reason,
                 context_location, context_calendar, context_time_of_day, created_at
          FROM sound_alerts
          WHERE user_id = ?
          ORDER BY created_at DESC
          LIMIT ? OFFSET ?
        `)
        .all(userId, limit, offset);

      const totalCount = db
        .prepare('SELECT COUNT(*) as count FROM sound_alerts WHERE user_id = ?')
        .get(userId);

      res.json({
        success: true,
        data: alerts,
        pagination: {
          limit,
          offset,
          total: totalCount.count,
          hasMore: offset + limit < totalCount.count
        }
      });
    } catch (error) {
      console.error('Error fetching alerts:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch alerts'
      });
    }
  })
);

/**
 * GET /api/alerts/context-rules
 * Get context rules for user
 * MUST be defined BEFORE /:id to avoid route conflict
 */
router.get(
  '/context-rules',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || DEFAULT_USER_ID;

    try {
      const rules = db
        .prepare(`
          SELECT id, name, description, condition_type, condition_value,
                 alert_action, priority, is_active, created_at, updated_at
          FROM context_rules
          WHERE user_id = ?
          ORDER BY priority ASC
        `)
        .all(userId);

      res.json({
        success: true,
        data: rules
      });
    } catch (error) {
      console.error('Error fetching context rules:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch context rules'
      });
    }
  })
);

/**
 * PUT /api/alerts/context-rules/:id
 * Update context rule (toggle active status)
 * Body: { isActive: boolean } or { is_active: boolean }
 */
router.put(
  '/context-rules/:id',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { id } = req.params;
    const userId = req.query.userId || req.body.userId || DEFAULT_USER_ID;
    const isActive = req.body.isActive !== undefined ? req.body.isActive : req.body.is_active;

    if (typeof isActive !== 'boolean') {
      return res.status(400).json({
        success: false,
        error: 'isActive must be a boolean'
      });
    }

    try {
      const rule = db
        .prepare('SELECT id FROM context_rules WHERE id = ? AND user_id = ?')
        .get(id, userId);

      if (!rule) {
        return res.status(404).json({
          success: false,
          error: 'Rule not found'
        });
      }

      const stmt = db.prepare(`
        UPDATE context_rules
        SET is_active = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND user_id = ?
      `);

      stmt.run(isActive ? 1 : 0, id, userId);

      const updated = db.prepare('SELECT * FROM context_rules WHERE id = ?').get(id);

      res.json({
        success: true,
        data: updated,
        message: `Rule ${isActive ? 'activated' : 'deactivated'}`
      });
    } catch (error) {
      console.error('Error updating context rule:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to update context rule'
      });
    }
  })
);

/**
 * POST /api/alerts/simulate
 * Simulate a sound detection for demo/testing
 * Body: { soundType?: string }
 * MUST be defined BEFORE /:id to avoid route conflict
 */
router.post(
  '/simulate',
  asyncHandler(async (req, res) => {
    const userId = req.query.userId || req.body.userId || DEFAULT_USER_ID;
    const { soundType, type } = req.body;
    const sType = soundType || type;

    try {
      let classification;

      if (sType) {
        // Use specified sound type
        if (!validators.isValidSoundType(sType)) {
          return res.status(400).json({
            success: false,
            error: `Invalid sound type: ${sType}`
          });
        }
        classification = {
          type: sType,
          confidence: 0.75 + Math.random() * 0.2 // 0.75-0.95
        };
      } else {
        // Simulate random ambient listening
        classification = simulateAmbientListening();
      }

      // Create alert using existing POST handler logic
      const context = evaluateContext();
      const decision = applyContextualDecision(
        userId,
        classification.type,
        classification.confidence,
        context
      );

      const db = getDb();
      const alertId = uuidv4();
      const stmt = db.prepare(`
        INSERT INTO sound_alerts (
          id, user_id, sound_type, confidence, was_delivered,
          delivery_reason, context_location, context_time_of_day
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `);

      stmt.run(
        alertId,
        userId,
        classification.type,
        classification.confidence,
        decision.deliver ? 1 : 0,
        decision.reason,
        context.location,
        context.timeOfDay
      );

      const alert = db.prepare('SELECT * FROM sound_alerts WHERE id = ?').get(alertId);

      if (decision.deliver) {
        broadcastAlert(alert);
      }

      res.status(201).json({
        success: true,
        data: alert,
        classification: {
          type: classification.type,
          confidence: classification.confidence
        },
        decision: {
          deliver: decision.deliver,
          reason: decision.reason
        }
      });
    } catch (error) {
      console.error('Error simulating sound:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to simulate sound'
      });
    }
  })
);

/**
 * GET /api/alerts/:id
 * Get single alert details
 * MUST be after /context-rules and /simulate to avoid catching those as :id
 */
router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { id } = req.params;
    const userId = req.query.userId || DEFAULT_USER_ID;

    try {
      const alert = db
        .prepare(`
          SELECT * FROM sound_alerts
          WHERE id = ? AND user_id = ?
        `)
        .get(id, userId);

      if (!alert) {
        return res.status(404).json({
          success: false,
          error: 'Alert not found'
        });
      }

      res.json({
        success: true,
        data: alert
      });
    } catch (error) {
      console.error('Error fetching alert:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch alert'
      });
    }
  })
);

/**
 * POST /api/alerts
 * Create a new alert with context-aware delivery decision
 */
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.body.userId || DEFAULT_USER_ID;
    const { soundType, confidence, audioFeatures, location, calendarEvents, timeOfDay } =
      req.body;

    // Validate input
    if (!soundType) {
      return res.status(400).json({
        success: false,
        error: 'soundType is required'
      });
    }

    if (!validators.isValidSoundType(soundType)) {
      return res.status(400).json({
        success: false,
        error: `Invalid sound type: ${soundType}`
      });
    }

    const confidenceScore = parseFloat(confidence) || 0.85;

    if (!validators.isValidConfidence(confidenceScore)) {
      return res.status(400).json({
        success: false,
        error: 'Confidence must be between 0 and 1'
      });
    }

    try {
      // Evaluate context
      const context = evaluateContext(location, calendarEvents, timeOfDay);

      // Get delivery decision from context engine
      const decision = applyContextualDecision(userId, soundType, confidenceScore, context);

      // Create alert record
      const alertId = uuidv4();
      const stmt = db.prepare(`
        INSERT INTO sound_alerts (
          id, user_id, sound_type, confidence, was_delivered,
          delivery_reason, context_location, context_calendar, context_time_of_day
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);

      stmt.run(
        alertId,
        userId,
        soundType,
        confidenceScore,
        decision.deliver ? 1 : 0,
        decision.reason,
        context.location,
        context.calendarEvents[0]?.title || null,
        context.timeOfDay
      );

      const alert = db.prepare('SELECT * FROM sound_alerts WHERE id = ?').get(alertId);

      if (decision.deliver) {
        broadcastAlert(alert);
      }

      res.status(201).json({
        success: true,
        data: alert,
        decision: {
          deliver: decision.deliver,
          reason: decision.reason,
          appliedRule: decision.appliedRule || null
        },
        context: {
          location: context.location,
          inMeeting: context.inMeeting,
          inSleepMode: context.inSleepMode,
          timeOfDay: context.timeOfDay
        }
      });
    } catch (error) {
      console.error('Error creating alert:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to create alert'
      });
    }
  })
);

export default router;
