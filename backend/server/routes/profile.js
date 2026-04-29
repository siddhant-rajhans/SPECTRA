import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../database.js';
import { asyncHandler } from '../middleware/errorHandler.js';

const router = express.Router();
const DEFAULT_USER_ID = 'default-user';

/**
 * GET /api/profile
 * Get user profile information
 */
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || DEFAULT_USER_ID;

    try {
      const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: 'User not found'
        });
      }

      res.json({
        success: true,
        data: user
      });
    } catch (error) {
      console.error('Error fetching profile:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch profile'
      });
    }
  })
);

/**
 * PUT /api/profile
 * Update user profile
 * Body: {
 *   name?: string,
 *   deviceBrand?: string,
 *   deviceModel?: string,
 *   hearingLossLevel?: string
 * }
 */
router.put(
  '/',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || req.body.userId || DEFAULT_USER_ID;
    const { name, deviceBrand, deviceModel, hearingLossLevel } = req.body;

    try {
      // Check if user exists
      const user = db.prepare('SELECT id FROM users WHERE id = ?').get(userId);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: 'User not found'
        });
      }

      // Build update query
      const updates = [];
      const values = [];

      if (typeof name === 'string' && name.trim()) {
        updates.push('name = ?');
        values.push(name);
      }

      if (typeof deviceBrand === 'string') {
        updates.push('device_brand = ?');
        values.push(deviceBrand || null);
      }

      if (typeof deviceModel === 'string') {
        updates.push('device_model = ?');
        values.push(deviceModel || null);
      }

      if (typeof hearingLossLevel === 'string') {
        updates.push('hearing_loss_level = ?');
        values.push(hearingLossLevel || null);
      }

      updates.push('updated_at = CURRENT_TIMESTAMP');

      if (updates.length > 1) {
        const stmt = db.prepare(`
          UPDATE users
          SET ${updates.join(', ')}
          WHERE id = ?
        `);

        stmt.run(...values, userId);
      }

      const updated = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);

      res.json({
        success: true,
        data: updated,
        message: 'Profile updated successfully'
      });
    } catch (error) {
      console.error('Error updating profile:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to update profile'
      });
    }
  })
);

/**
 * GET /api/profile/device
 * Get device status
 */
router.get(
  '/device',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || DEFAULT_USER_ID;

    try {
      const deviceStatus = db
        .prepare(`
          SELECT id, user_id, device_name, battery_level, is_connected,
                 current_program, last_seen_location, updated_at
          FROM device_status
          WHERE user_id = ?
          LIMIT 1
        `)
        .get(userId);

      if (!deviceStatus) {
        return res.status(404).json({
          success: false,
          error: 'Device status not found'
        });
      }

      // Convert boolean fields to actual booleans
      deviceStatus.is_connected = Boolean(deviceStatus.is_connected);

      res.json({
        success: true,
        data: deviceStatus
      });
    } catch (error) {
      console.error('Error fetching device status:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch device status'
      });
    }
  })
);

/**
 * PUT /api/profile/device
 * Update device status
 * Body: {
 *   deviceName?: string,
 *   batteryLevel?: number (0-100),
 *   isConnected?: boolean,
 *   currentProgram?: string,
 *   lastSeenLocation?: string
 * }
 */
router.put(
  '/device',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || req.body.userId || DEFAULT_USER_ID;
    const {
      deviceName,
      batteryLevel,
      isConnected,
      currentProgram,
      lastSeenLocation
    } = req.body;

    try {
      // Check if device exists
      const device = db
        .prepare('SELECT id FROM device_status WHERE user_id = ?')
        .get(userId);

      if (!device) {
        // Create device status if it doesn't exist
        const deviceId = uuidv4();
        const stmt = db.prepare(`
          INSERT INTO device_status (
            id, user_id, device_name, battery_level, is_connected,
            current_program, last_seen_location
          )
          VALUES (?, ?, ?, ?, ?, ?, ?)
        `);

        stmt.run(
          deviceId,
          userId,
          deviceName || 'Hearing Device',
          Math.max(0, Math.min(100, batteryLevel || 100)),
          isConnected ? 1 : 0,
          currentProgram || 'Home / Quiet',
          lastSeenLocation || null
        );

        const newDevice = db
          .prepare('SELECT * FROM device_status WHERE id = ?')
          .get(deviceId);

        return res.status(201).json({
          success: true,
          data: newDevice,
          message: 'Device created and status updated'
        });
      }

      // Update existing device
      const updates = [];
      const values = [];

      if (typeof deviceName === 'string') {
        updates.push('device_name = ?');
        values.push(deviceName);
      }

      if (typeof batteryLevel === 'number') {
        updates.push('battery_level = ?');
        values.push(Math.max(0, Math.min(100, batteryLevel)));
      }

      if (typeof isConnected === 'boolean') {
        updates.push('is_connected = ?');
        values.push(isConnected ? 1 : 0);
      }

      if (typeof currentProgram === 'string') {
        updates.push('current_program = ?');
        values.push(currentProgram);
      }

      if (typeof lastSeenLocation === 'string') {
        updates.push('last_seen_location = ?');
        values.push(lastSeenLocation);
      }

      updates.push('updated_at = CURRENT_TIMESTAMP');

      if (updates.length > 1) {
        const stmt = db.prepare(`
          UPDATE device_status
          SET ${updates.join(', ')}
          WHERE user_id = ?
        `);

        stmt.run(...values, userId);
      }

      const updated = db
        .prepare('SELECT * FROM device_status WHERE user_id = ?')
        .get(userId);

      // Convert boolean fields
      updated.is_connected = Boolean(updated.is_connected);

      res.json({
        success: true,
        data: updated,
        message: 'Device status updated'
      });
    } catch (error) {
      console.error('Error updating device status:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to update device status'
      });
    }
  })
);

/**
 * GET /api/profile/summary
 * Get complete profile summary with device and stats
 */
router.get(
  '/summary',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || DEFAULT_USER_ID;

    try {
      const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: 'User not found'
        });
      }

      const device = db
        .prepare('SELECT * FROM device_status WHERE user_id = ?')
        .get(userId);

      const alertCount = db
        .prepare('SELECT COUNT(*) as count FROM sound_alerts WHERE user_id = ?')
        .get(userId);

      const feedbackCount = db
        .prepare('SELECT COUNT(*) as count FROM iml_feedback WHERE user_id = ?')
        .get(userId);

      const activeRules = db
        .prepare(
          'SELECT COUNT(*) as count FROM context_rules WHERE user_id = ? AND is_active = 1'
        )
        .get(userId);

      res.json({
        success: true,
        data: {
          profile: user,
          device: device ? { ...device, is_connected: Boolean(device.is_connected) } : null,
          statistics: {
            totalAlerts: alertCount.count,
            feedbackProvided: feedbackCount.count,
            activeContextRules: activeRules.count
          }
        }
      });
    } catch (error) {
      console.error('Error fetching profile summary:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch profile summary'
      });
    }
  })
);

export default router;
