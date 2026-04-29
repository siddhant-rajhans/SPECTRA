import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../database.js';
import { asyncHandler } from '../middleware/errorHandler.js';

const router = express.Router();
const DEFAULT_USER_ID = 'default-user';

/**
 * GET /api/environment/programs
 * Get hearing programs for user
 */
router.get(
  '/programs',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || DEFAULT_USER_ID;

    try {
      const programs = db
        .prepare(`
          SELECT id, name, description, icon, speech_enhancement,
                 noise_reduction, forward_focus, is_selected, created_at, updated_at
          FROM hearing_programs
          WHERE user_id = ?
          ORDER BY created_at ASC
        `)
        .all(userId);

      res.json({
        success: true,
        data: programs
      });
    } catch (error) {
      console.error('Error fetching hearing programs:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch hearing programs'
      });
    }
  })
);

/**
 * PUT /api/environment/programs/:id
 * Update hearing program
 * Body: {
 *   isSelected?: boolean,
 *   speechEnhancement?: number (0-100),
 *   noiseReduction?: number (0-100),
 *   forwardFocus?: number (0-100),
 *   name?: string,
 *   description?: string
 * }
 */
router.put(
  '/programs/:id',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { id } = req.params;
    const userId = req.query.userId || req.body.userId || DEFAULT_USER_ID;
    const {
      isSelected,
      is_selected,
      speechEnhancement,
      speech_enhancement,
      noiseReduction,
      noise_reduction,
      forwardFocus,
      forward_focus,
      name,
      description
    } = req.body;

    // Accept both camelCase and snake_case
    const finalIsSelected = isSelected !== undefined ? isSelected : (is_selected !== undefined ? Boolean(is_selected) : undefined);
    const finalSpeechEnhancement = speechEnhancement !== undefined ? speechEnhancement : speech_enhancement;
    const finalNoiseReduction = noiseReduction !== undefined ? noiseReduction : noise_reduction;
    const finalForwardFocus = forwardFocus !== undefined ? forwardFocus : forward_focus;

    try {
      // Check if program exists
      const program = db
        .prepare('SELECT id FROM hearing_programs WHERE id = ? AND user_id = ?')
        .get(id, userId);

      if (!program) {
        return res.status(404).json({
          success: false,
          error: 'Program not found'
        });
      }

      // If selecting this program, deselect others
      if (finalIsSelected === true) {
        const updateOthers = db.prepare(`
          UPDATE hearing_programs
          SET is_selected = 0
          WHERE user_id = ? AND id != ?
        `);
        updateOthers.run(userId, id);
      }

      // Build update query
      const updates = [];
      const values = [];

      if (typeof finalIsSelected === 'boolean') {
        updates.push('is_selected = ?');
        values.push(finalIsSelected ? 1 : 0);
      }

      if (typeof finalSpeechEnhancement === 'number') {
        const val = Math.max(0, Math.min(100, finalSpeechEnhancement));
        updates.push('speech_enhancement = ?');
        values.push(val);
      }

      if (typeof finalNoiseReduction === 'number') {
        const val = Math.max(0, Math.min(100, finalNoiseReduction));
        updates.push('noise_reduction = ?');
        values.push(val);
      }

      if (typeof finalForwardFocus === 'number') {
        const val = Math.max(0, Math.min(100, finalForwardFocus));
        updates.push('forward_focus = ?');
        values.push(val);
      }

      if (typeof name === 'string' && name.trim()) {
        updates.push('name = ?');
        values.push(name);
      }

      if (typeof description === 'string') {
        updates.push('description = ?');
        values.push(description);
      }

      updates.push('updated_at = CURRENT_TIMESTAMP');

      if (updates.length > 1) {
        // At least one field to update
        const stmt = db.prepare(`
          UPDATE hearing_programs
          SET ${updates.join(', ')}
          WHERE id = ? AND user_id = ?
        `);

        stmt.run(...values, id, userId);
      }

      const updated = db.prepare('SELECT * FROM hearing_programs WHERE id = ?').get(id);

      res.json({
        success: true,
        data: updated,
        message: 'Program updated successfully'
      });
    } catch (error) {
      console.error('Error updating program:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to update program'
      });
    }
  })
);

/**
 * GET /api/environment/current
 * Get current environment reading (noise level, acoustic characteristics)
 * Returns simulated environmental data
 */
router.get(
  '/current',
  asyncHandler(async (req, res) => {
    try {
      // Simulate current environmental reading
      const noiseLevel = Math.floor(Math.random() * 40) + 50; // 50-90 dB
      const soundProfile = ['quiet', 'moderate', 'loud'][Math.floor(noiseLevel / 30) - 1] ||
        'quiet';

      const frequencyContent = {
        bass: Math.random() * 100,
        mid: Math.random() * 100,
        treble: Math.random() * 100
      };

      const suggestedProgram = noiseLevel > 75 ? 'Restaurant / Crowd' : 'Home / Quiet';

      res.json({
        success: true,
        data: {
          noiseLevel,
          soundProfile,
          frequencyContent,
          suggestedProgram,
          timestamp: new Date().toISOString()
        }
      });
    } catch (error) {
      console.error('Error getting current environment:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to get environment reading'
      });
    }
  })
);

/**
 * PUT /api/environment/settings
 * Update environment/fine-tuning settings
 * Body: {
 *   speechEnhancement?: number (0-100),
 *   noiseReduction?: number (0-100),
 *   forwardFocus?: number (0-100),
 *   bassBoost?: number (-20 to +20 dB),
 *   trebleBoost?: number (-20 to +20 dB)
 * }
 */
router.put(
  '/settings',
  asyncHandler(async (req, res) => {
    const userId = req.query.userId || req.body.userId || DEFAULT_USER_ID;
    const {
      speechEnhancement,
      noiseReduction,
      forwardFocus,
      bassBoost,
      trebleBoost
    } = req.body;

    // Validate inputs
    const settings = {};

    if (typeof speechEnhancement === 'number') {
      settings.speechEnhancement = Math.max(0, Math.min(100, speechEnhancement));
    }

    if (typeof noiseReduction === 'number') {
      settings.noiseReduction = Math.max(0, Math.min(100, noiseReduction));
    }

    if (typeof forwardFocus === 'number') {
      settings.forwardFocus = Math.max(0, Math.min(100, forwardFocus));
    }

    if (typeof bassBoost === 'number') {
      settings.bassBoost = Math.max(-20, Math.min(20, bassBoost));
    }

    if (typeof trebleBoost === 'number') {
      settings.trebleBoost = Math.max(-20, Math.min(20, trebleBoost));
    }

    try {
      // In a real app, these would be stored per-user in the database
      // For now, we return the validated settings
      res.json({
        success: true,
        data: {
          userId,
          settings,
          appliedAt: new Date().toISOString(),
          message: 'Settings updated and applied to device'
        }
      });
    } catch (error) {
      console.error('Error updating settings:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to update settings'
      });
    }
  })
);

/**
 * POST /api/environment/programs
 * Create a custom hearing program
 * Body: {
 *   name: string,
 *   description?: string,
 *   speechEnhancement: number (0-100),
 *   noiseReduction: number (0-100),
 *   forwardFocus: number (0-100),
 *   icon?: string
 * }
 */
router.post(
  '/programs',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || req.body.userId || DEFAULT_USER_ID;
    const {
      name,
      description,
      speechEnhancement,
      noiseReduction,
      forwardFocus,
      icon
    } = req.body;

    // Validate required fields
    if (!name || typeof name !== 'string') {
      return res.status(400).json({
        success: false,
        error: 'Program name is required'
      });
    }

    // Validate numeric fields
    const se = Math.max(0, Math.min(100, parseInt(speechEnhancement) || 75));
    const nr = Math.max(0, Math.min(100, parseInt(noiseReduction) || 60));
    const ff = Math.max(0, Math.min(100, parseInt(forwardFocus) || 50));

    try {
      const programId = uuidv4();
      const stmt = db.prepare(`
        INSERT INTO hearing_programs (
          id, user_id, name, description, icon,
          speech_enhancement, noise_reduction, forward_focus, is_selected
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
      `);

      stmt.run(
        programId,
        userId,
        name,
        description || null,
        icon || 'cog',
        se,
        nr,
        ff
      );

      const program = db.prepare('SELECT * FROM hearing_programs WHERE id = ?').get(programId);

      res.status(201).json({
        success: true,
        data: program,
        message: 'Custom program created successfully'
      });
    } catch (error) {
      console.error('Error creating program:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to create program'
      });
    }
  })
);

export default router;
