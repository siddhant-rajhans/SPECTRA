import express from 'express';
import crypto from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../database.js';
import { asyncHandler } from '../middleware/errorHandler.js';

const router = express.Router();

/**
 * Hash password using SHA256 (simple for demo - not production)
 */
function hashPassword(password) {
  return crypto
    .createHash('sha256')
    .update(password)
    .digest('hex');
}

/**
 * Create default context rules and hearing programs for a new user
 */
function seedUserDefaults(db, userId) {
  try {
    // Create default context rules
    const rulesData = [
      {
        name: 'Meeting Mode',
        description: 'Active during calendar meetings',
        conditionType: 'calendar_event',
        conditionValue: 'in_meeting',
        alertAction: 'suppress_non_critical'
      },
      {
        name: 'Sleep Mode',
        description: 'Active 10 PM to 7 AM',
        conditionType: 'time_range',
        conditionValue: '22:00-07:00',
        alertAction: 'critical_only'
      },
      {
        name: 'Outdoors Mode',
        description: 'Active when detected outdoors',
        conditionType: 'location',
        conditionValue: 'outdoors',
        alertAction: 'prioritize_environmental'
      },
      {
        name: 'Restaurant Mode',
        description: 'Active in restaurant settings',
        conditionType: 'location',
        conditionValue: 'restaurant',
        alertAction: 'enhance_speech'
      }
    ];

    const ruleStmt = db.prepare(`
      INSERT INTO context_rules (id, user_id, name, description, condition_type, condition_value, alert_action, priority)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);

    rulesData.forEach((rule, index) => {
      ruleStmt.run(
        uuidv4(),
        userId,
        rule.name,
        rule.description,
        rule.conditionType,
        rule.conditionValue,
        rule.alertAction,
        index
      );
    });

    // Create default hearing programs
    const programsData = [
      {
        name: 'Home / Quiet',
        description: 'Optimized for quiet home environments',
        icon: 'home',
        speechEnhancement: 75,
        noiseReduction: 60,
        forwardFocus: 50,
        isSelected: 1
      },
      {
        name: 'Restaurant / Crowd',
        description: 'Enhanced speech in noisy social settings',
        icon: 'utensils',
        speechEnhancement: 90,
        noiseReduction: 85,
        forwardFocus: 70,
        isSelected: 0
      },
      {
        name: 'Music / Media',
        description: 'Optimized for entertainment',
        icon: 'music',
        speechEnhancement: 60,
        noiseReduction: 40,
        forwardFocus: 30,
        isSelected: 0
      },
      {
        name: 'Outdoors / Transit',
        description: 'For outdoor and transportation settings',
        icon: 'car',
        speechEnhancement: 70,
        noiseReduction: 75,
        forwardFocus: 60,
        isSelected: 0
      },
      {
        name: 'Sleep Mode',
        description: 'Minimal amplification for sleeping',
        icon: 'moon',
        speechEnhancement: 20,
        noiseReduction: 90,
        forwardFocus: 10,
        isSelected: 0
      }
    ];

    const programStmt = db.prepare(`
      INSERT INTO hearing_programs (id, user_id, name, description, icon, speech_enhancement, noise_reduction, forward_focus, is_selected)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    programsData.forEach(program => {
      programStmt.run(
        uuidv4(),
        userId,
        program.name,
        program.description,
        program.icon,
        program.speechEnhancement,
        program.noiseReduction,
        program.forwardFocus,
        program.isSelected
      );
    });

    // Create default device status
    const deviceStmt = db.prepare(`
      INSERT INTO device_status (id, user_id, device_name, battery_level, is_connected, current_program)
      VALUES (?, ?, ?, ?, ?, ?)
    `);

    deviceStmt.run(
      uuidv4(),
      userId,
      'Hearing Device',
      100,
      1,
      'Home / Quiet'
    );

    // Create demo sound alerts so IML has pending items
    const alertsData = [
      { soundType: 'doorbell', confidence: 0.94, wasDelivered: 1, reason: 'Home · Saturday morning → Delivered', location: 'home', timeOfDay: 'morning' },
      { soundType: 'name_called', confidence: 0.78, wasDelivered: 0, reason: 'Office · Meeting on calendar → Suppressed', location: 'office', timeOfDay: 'morning' },
      { soundType: 'fire_alarm', confidence: 0.99, wasDelivered: 1, reason: 'Critical → Always delivered', location: 'home', timeOfDay: 'morning' },
      { soundType: 'alarm_timer', confidence: 0.97, wasDelivered: 1, reason: 'Sleep mode → Delivered (alarm allowed)', location: 'home', timeOfDay: 'night' },
      { soundType: 'car_horn', confidence: 0.91, wasDelivered: 1, reason: 'Outdoors · Near road → High priority', location: 'street', timeOfDay: 'afternoon' }
    ];

    const alertStmt = db.prepare(`
      INSERT INTO sound_alerts (id, user_id, sound_type, confidence, was_delivered, delivery_reason, context_location, context_time_of_day)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);

    alertsData.forEach(a => {
      alertStmt.run(uuidv4(), userId, a.soundType, a.confidence, a.wasDelivered, a.reason, a.location, a.timeOfDay);
    });

    // Pre-seed 2 IML feedback items so stats show data, leaving 3 alerts pending
    const seededAlerts = db.prepare('SELECT id, sound_type FROM sound_alerts WHERE user_id = ? ORDER BY created_at ASC LIMIT 2').all(userId);
    const feedbackStmt = db.prepare(`
      INSERT INTO iml_feedback (id, alert_id, user_id, original_classification, is_correct, corrected_classification)
      VALUES (?, ?, ?, ?, ?, ?)
    `);

    seededAlerts.forEach(a => {
      feedbackStmt.run(uuidv4(), a.id, userId, a.sound_type, 1, null);
    });
  } catch (error) {
    console.error('Error seeding user defaults:', error);
    throw error;
  }
}

/**
 * POST /api/auth/signup
 * Create a new user account
 * Body: { name, email, password, hearingLossLevel, deviceBrand, deviceModel }
 */
router.post(
  '/signup',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { name, email, password, hearingLossLevel, deviceBrand, deviceModel } = req.body;

    try {
      // Validate required fields
      if (!name || !email || !password) {
        return res.status(400).json({
          success: false,
          error: 'Name, email, and password are required'
        });
      }

      // Check if email already exists
      const existingEmail = db
        .prepare('SELECT id FROM auth WHERE email = ?')
        .get(email);

      if (existingEmail) {
        return res.status(409).json({
          success: false,
          error: 'Email already in use'
        });
      }

      // Create new user
      const userId = uuidv4();
      const userStmt = db.prepare(`
        INSERT INTO users (id, name, email, avatar_initial, device_brand, device_model, hearing_loss_level)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `);

      userStmt.run(
        userId,
        name,
        email,
        name.charAt(0).toUpperCase(),
        deviceBrand || null,
        deviceModel || null,
        hearingLossLevel || 'Moderate'
      );

      // Create auth record
      const passwordHash = hashPassword(password);
      const authStmt = db.prepare(`
        INSERT INTO auth (id, email, password_hash, user_id)
        VALUES (?, ?, ?, ?)
      `);

      authStmt.run(
        uuidv4(),
        email,
        passwordHash,
        userId
      );

      // Seed default context rules, hearing programs, and device status
      seedUserDefaults(db, userId);

      res.status(201).json({
        success: true,
        user: {
          id: userId,
          name,
          email,
          avatar_initial: name.charAt(0).toUpperCase()
        },
        message: 'Account created successfully'
      });
    } catch (error) {
      console.error('Error creating account:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to create account'
      });
    }
  })
);

/**
 * POST /api/auth/login
 * Authenticate user and return profile
 * Body: { email, password }
 */
router.post(
  '/login',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { email, password } = req.body;

    try {
      // Validate required fields
      if (!email || !password) {
        return res.status(400).json({
          success: false,
          error: 'Email and password are required'
        });
      }

      // Look up auth record
      const authRecord = db
        .prepare('SELECT * FROM auth WHERE email = ?')
        .get(email);

      if (!authRecord) {
        return res.status(401).json({
          success: false,
          error: 'Invalid email or password'
        });
      }

      // Verify password
      const passwordHash = hashPassword(password);
      if (passwordHash !== authRecord.password_hash) {
        return res.status(401).json({
          success: false,
          error: 'Invalid email or password'
        });
      }

      // Get user profile
      const user = db
        .prepare('SELECT id, name, email, avatar_initial FROM users WHERE id = ?')
        .get(authRecord.user_id);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: 'User profile not found'
        });
      }

      res.json({
        success: true,
        user
      });
    } catch (error) {
      console.error('Error during login:', error);
      res.status(500).json({
        success: false,
        error: 'Login failed'
      });
    }
  })
);

/**
 * GET /api/auth/user/:userId
 * Get user profile by user ID
 */
router.get(
  '/user/:userId',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { userId } = req.params;

    try {
      const user = db
        .prepare('SELECT id, name, email, avatar_initial, device_brand, device_model, hearing_loss_level, created_at, updated_at FROM users WHERE id = ?')
        .get(userId);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: 'User not found'
        });
      }

      res.json({
        success: true,
        user
      });
    } catch (error) {
      console.error('Error fetching user profile:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch user profile'
      });
    }
  })
);

export default router;
