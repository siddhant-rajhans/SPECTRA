import express from 'express';
import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../database.js';
import { asyncHandler } from '../middleware/errorHandler.js';

const router = express.Router();
const DEFAULT_USER_ID = 'default-user';

/**
 * Provider configuration with features
 */
const PROVIDERS = [
  {
    id: 'cochlear',
    name: 'Cochlear',
    logo: '🔵',
    models: ['Nucleus 7', 'Nucleus 8', 'Kanso 2', 'Baha 6 Max'],
    features: ['Remote control', 'Battery monitoring', 'Program switching', 'Bluetooth streaming', 'Find my device']
  },
  {
    id: 'phonak',
    name: 'Phonak',
    logo: '🟢',
    models: ['Paradise', 'Lumity', 'Audeo', 'Naida'],
    features: ['Remote control', 'Battery monitoring', 'SpeechEnhancer', 'Bluetooth streaming', 'Tap Control']
  },
  {
    id: 'oticon',
    name: 'Oticon',
    logo: '🔴',
    models: ['More', 'Real', 'Own', 'Xceed'],
    features: ['Remote control', 'Battery monitoring', 'OpenSound Navigator', 'Bluetooth streaming', 'Hearing health']
  },
  {
    id: 'resound',
    name: 'ReSound',
    logo: '🟡',
    models: ['Nexia', 'Omnia', 'ONE', 'ENZO Q'],
    features: ['Remote control', 'Battery monitoring', 'All Access Directionality', 'Bluetooth streaming', 'Find my hearing aid']
  },
  {
    id: 'starkey',
    name: 'Starkey',
    logo: '🟣',
    models: ['Genesis AI', 'Evolv AI', 'Livio Edge AI'],
    features: ['Remote control', 'Battery monitoring', 'Edge Mode', 'Bluetooth streaming', 'Health monitoring', 'Fall detection']
  },
  {
    id: 'widex',
    name: 'Widex',
    logo: '🟠',
    models: ['SmartRic', 'Moment', 'Magnify'],
    features: ['Remote control', 'Battery monitoring', 'SoundSense', 'Bluetooth streaming', 'ZEN tinnitus therapy']
  }
];

/**
 * Get features for a specific provider
 */
function getProviderFeatures(providerId) {
  const provider = PROVIDERS.find(p => p.id === providerId);
  return provider ? provider.features : [];
}

/**
 * Generate simulated firmware version
 */
function generateFirmwareVersion() {
  const major = Math.floor(Math.random() * 10) + 1;
  const minor = Math.floor(Math.random() * 10);
  const patch = Math.floor(Math.random() * 5);
  return `v${major}.${minor}.${patch}`;
}

/**
 * Generate simulated battery level
 */
function generateBatteryLevel() {
  return Math.floor(Math.random() * (95 - 60 + 1) + 60);
}

/**
 * GET /api/implants/providers
 * Return list of supported providers
 */
router.get(
  '/providers',
  asyncHandler(async (req, res) => {
    try {
      res.json({
        success: true,
        providers: PROVIDERS
      });
    } catch (error) {
      console.error('Error fetching providers:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch providers'
      });
    }
  })
);

/**
 * GET /api/implants/connected
 * Return all connected implant accounts for the user
 */
router.get(
  '/connected',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || DEFAULT_USER_ID;

    try {
      const implants = db
        .prepare(`
          SELECT id, user_id, provider, provider_account_id, display_name,
                 device_model, battery_level, firmware_version, is_connected,
                 last_synced_at, features, created_at, updated_at
          FROM implant_accounts
          WHERE user_id = ? AND is_connected = 1
          ORDER BY created_at DESC
        `)
        .all(userId);

      // Parse JSON features field
      const implantData = implants.map(implant => ({
        ...implant,
        is_connected: Boolean(implant.is_connected),
        features: implant.features ? JSON.parse(implant.features) : []
      }));

      res.json({
        success: true,
        implants: implantData
      });
    } catch (error) {
      console.error('Error fetching connected implants:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch connected implants'
      });
    }
  })
);

/**
 * POST /api/implants/connect
 * Connect a new implant account
 * Body: { provider, accountId (optional), displayName, deviceModel }
 */
router.post(
  '/connect',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const userId = req.query.userId || DEFAULT_USER_ID;
    const { provider, accountId, displayName, deviceModel } = req.body;

    try {
      // Validate required fields
      if (!provider || !displayName || !deviceModel) {
        return res.status(400).json({
          success: false,
          error: 'Provider, displayName, and deviceModel are required'
        });
      }

      // Validate provider
      const validProvider = PROVIDERS.find(p => p.id === provider);
      if (!validProvider) {
        return res.status(400).json({
          success: false,
          error: 'Invalid provider'
        });
      }

      // Check if user exists
      const user = db
        .prepare('SELECT id FROM users WHERE id = ?')
        .get(userId);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: 'User not found'
        });
      }

      // Create new implant account
      const implantId = uuidv4();
      const batteryLevel = generateBatteryLevel();
      const firmwareVersion = generateFirmwareVersion();
      const features = getProviderFeatures(provider);

      const stmt = db.prepare(`
        INSERT INTO implant_accounts
        (id, user_id, provider, provider_account_id, display_name, device_model,
         battery_level, firmware_version, is_connected, features)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);

      stmt.run(
        implantId,
        userId,
        provider,
        accountId || null,
        displayName,
        deviceModel,
        batteryLevel,
        firmwareVersion,
        1,
        JSON.stringify(features)
      );

      const implant = db
        .prepare('SELECT * FROM implant_accounts WHERE id = ?')
        .get(implantId);

      res.status(201).json({
        success: true,
        implant: {
          ...implant,
          is_connected: Boolean(implant.is_connected),
          features: JSON.parse(implant.features)
        },
        message: 'Implant account connected successfully'
      });
    } catch (error) {
      console.error('Error connecting implant:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to connect implant account'
      });
    }
  })
);

/**
 * DELETE /api/implants/:id/disconnect
 * Disconnect an implant account
 */
router.delete(
  '/:id/disconnect',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { id } = req.params;

    try {
      // Check if implant exists
      const implant = db
        .prepare('SELECT id FROM implant_accounts WHERE id = ?')
        .get(id);

      if (!implant) {
        return res.status(404).json({
          success: false,
          error: 'Implant account not found'
        });
      }

      // Disconnect the implant
      const stmt = db.prepare(`
        UPDATE implant_accounts
        SET is_connected = 0, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `);

      stmt.run(id);

      const updated = db
        .prepare('SELECT * FROM implant_accounts WHERE id = ?')
        .get(id);

      res.json({
        success: true,
        implant: {
          ...updated,
          is_connected: Boolean(updated.is_connected),
          features: updated.features ? JSON.parse(updated.features) : []
        },
        message: 'Implant account disconnected'
      });
    } catch (error) {
      console.error('Error disconnecting implant:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to disconnect implant account'
      });
    }
  })
);

/**
 * GET /api/implants/:id/status
 * Get device status for specific implant
 */
router.get(
  '/:id/status',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { id } = req.params;

    try {
      const implant = db
        .prepare('SELECT * FROM implant_accounts WHERE id = ?')
        .get(id);

      if (!implant) {
        return res.status(404).json({
          success: false,
          error: 'Implant account not found'
        });
      }

      // Simulate slight battery drain (0-2%)
      let batteryLevel = implant.battery_level;
      if (batteryLevel > 0) {
        batteryLevel = Math.max(0, batteryLevel - Math.floor(Math.random() * 3));
      }

      res.json({
        success: true,
        status: {
          id: implant.id,
          provider: implant.provider,
          display_name: implant.display_name,
          device_model: implant.device_model,
          battery_level: batteryLevel,
          firmware_version: implant.firmware_version,
          is_connected: Boolean(implant.is_connected),
          last_synced_at: implant.last_synced_at,
          features: implant.features ? JSON.parse(implant.features) : [],
          updated_at: implant.updated_at
        }
      });
    } catch (error) {
      console.error('Error fetching implant status:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch implant status'
      });
    }
  })
);

/**
 * POST /api/implants/:id/sync
 * Sync implant and update battery level
 */
router.post(
  '/:id/sync',
  asyncHandler(async (req, res) => {
    const db = getDb();
    const { id } = req.params;

    try {
      // Check if implant exists
      const implant = db
        .prepare('SELECT * FROM implant_accounts WHERE id = ?')
        .get(id);

      if (!implant) {
        return res.status(404).json({
          success: false,
          error: 'Implant account not found'
        });
      }

      // Simulate battery level refresh (random 50-100)
      const newBatteryLevel = Math.floor(Math.random() * (100 - 50 + 1) + 50);

      // Update last_synced_at and battery level
      const stmt = db.prepare(`
        UPDATE implant_accounts
        SET last_synced_at = CURRENT_TIMESTAMP,
            battery_level = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `);

      stmt.run(newBatteryLevel, id);

      const updated = db
        .prepare('SELECT * FROM implant_accounts WHERE id = ?')
        .get(id);

      res.json({
        success: true,
        implant: {
          ...updated,
          is_connected: Boolean(updated.is_connected),
          features: updated.features ? JSON.parse(updated.features) : []
        },
        message: 'Implant account synced successfully'
      });
    } catch (error) {
      console.error('Error syncing implant:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to sync implant account'
      });
    }
  })
);

export default router;
