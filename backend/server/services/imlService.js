import { getDb } from '../database.js';
import { v4 as uuidv4 } from 'uuid';

/**
 * Record user feedback on a sound alert
 * Allows users to confirm or correct sound classifications
 * @param {string} alertId - Alert ID to provide feedback on
 * @param {string} userId - User ID
 * @param {boolean} isCorrect - Whether the original classification was correct
 * @param {string} correctedClassification - Corrected sound type if isCorrect is false
 * @returns {Object} Feedback record
 */
export function recordFeedback(alertId, userId, isCorrect, correctedClassification = null) {
  const db = getDb();

  try {
    // Get the alert
    const alert = db
      .prepare('SELECT sound_type FROM sound_alerts WHERE id = ? AND user_id = ?')
      .get(alertId, userId);

    if (!alert) {
      throw new Error('Alert not found');
    }

    // Check if feedback already exists
    const existing = db
      .prepare('SELECT id FROM iml_feedback WHERE alert_id = ? AND user_id = ?')
      .get(alertId, userId);

    if (existing) {
      // Update existing feedback
      const stmt = db.prepare(`
        UPDATE iml_feedback
        SET is_correct = ?, corrected_classification = ?
        WHERE alert_id = ? AND user_id = ?
      `);

      stmt.run(isCorrect ? 1 : 0, correctedClassification || null, alertId, userId);

      return {
        id: existing.id,
        alertId,
        userId,
        originalClassification: alert.sound_type,
        isCorrect,
        correctedClassification,
        updated: true
      };
    }

    // Create new feedback record
    const feedbackId = uuidv4();
    const stmt = db.prepare(`
      INSERT INTO iml_feedback (id, alert_id, user_id, original_classification, is_correct, corrected_classification)
      VALUES (?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      feedbackId,
      alertId,
      userId,
      alert.sound_type,
      isCorrect ? 1 : 0,
      correctedClassification || null
    );

    return {
      id: feedbackId,
      alertId,
      userId,
      originalClassification: alert.sound_type,
      isCorrect,
      correctedClassification,
      created: true
    };
  } catch (error) {
    console.error('Error recording feedback:', error);
    throw error;
  }
}

/**
 * Get model accuracy statistics for a user
 * @param {string} userId - User ID
 * @returns {Object} { confirmed: number, corrected: number, accuracy: number, totalSamples: number }
 */
export function getModelStats(userId) {
  const db = getDb();

  try {
    const stats = db
      .prepare(`
        SELECT
          SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) as confirmed,
          SUM(CASE WHEN is_correct = 0 THEN 1 ELSE 0 END) as corrected,
          COUNT(*) as total
        FROM iml_feedback
        WHERE user_id = ?
      `)
      .get(userId);

    const confirmed = stats.confirmed || 0;
    const corrected = stats.corrected || 0;
    const total = stats.total || 0;

    const accuracy = total > 0 ? (confirmed / total) * 100 : 0;

    return {
      confirmed,
      corrected,
      accuracy: Math.round(accuracy * 10) / 10, // Round to 1 decimal
      totalSamples: total,
      lastUpdated: new Date().toISOString()
    };
  } catch (error) {
    console.error('Error getting model stats:', error);
    return {
      confirmed: 0,
      corrected: 0,
      accuracy: 0,
      totalSamples: 0
    };
  }
}

/**
 * Get pending feedback (alerts without feedback yet)
 * @param {string} userId - User ID
 * @param {number} limit - Maximum number of results
 * @param {number} offset - Offset for pagination
 * @returns {Array} Alerts pending feedback
 */
export function getPendingFeedback(userId, limit = 10, offset = 0) {
  const db = getDb();

  try {
    const pendingAlerts = db
      .prepare(`
        SELECT
          sa.id,
          sa.sound_type,
          sa.confidence,
          sa.was_delivered,
          sa.delivery_reason,
          sa.context_location,
          sa.context_time_of_day,
          sa.created_at
        FROM sound_alerts sa
        LEFT JOIN iml_feedback imf ON sa.id = imf.alert_id
        WHERE sa.user_id = ? AND imf.id IS NULL
        ORDER BY sa.created_at DESC
        LIMIT ? OFFSET ?
      `)
      .all(userId, limit, offset);

    return pendingAlerts;
  } catch (error) {
    console.error('Error getting pending feedback:', error);
    return [];
  }
}

/**
 * Get reviewed feedback (alerts with feedback provided)
 * @param {string} userId - User ID
 * @param {number} limit - Maximum number of results
 * @param {number} offset - Offset for pagination
 * @returns {Array} Alerts with feedback
 */
export function getReviewedFeedback(userId, limit = 10, offset = 0) {
  const db = getDb();

  try {
    const reviewedAlerts = db
      .prepare(`
        SELECT
          sa.id,
          sa.sound_type as original_classification,
          sa.confidence,
          sa.was_delivered,
          sa.delivery_reason,
          sa.context_location,
          imf.is_correct,
          imf.corrected_classification,
          imf.created_at as feedback_created_at,
          sa.created_at as alert_created_at
        FROM sound_alerts sa
        JOIN iml_feedback imf ON sa.id = imf.alert_id
        WHERE sa.user_id = ? AND imf.user_id = ?
        ORDER BY imf.created_at DESC
        LIMIT ? OFFSET ?
      `)
      .all(userId, userId, limit, offset);

    return reviewedAlerts;
  } catch (error) {
    console.error('Error getting reviewed feedback:', error);
    return [];
  }
}

/**
 * Update model weights based on feedback accumulation
 * In a real system, this would trigger retraining of the ML model
 * For simulation, we track improvements over time
 * @param {string} userId - User ID
 * @returns {Object} Model training result
 */
export function updateModelWeights(userId) {
  const db = getDb();

  try {
    // Get current stats
    const stats = getModelStats(userId);

    // In production, this would:
    // 1. Collect all feedback
    // 2. Prepare training data
    // 3. Retrain the model
    // 4. Update model weights on device
    // 5. Calculate new accuracy metrics

    // For simulation, we just return success
    return {
      userId,
      trained: true,
      samplesUsed: stats.totalSamples,
      newAccuracy: stats.accuracy,
      improvementPercentage: Math.random() * 5, // Simulated improvement 0-5%
      trainingTimestamp: new Date().toISOString(),
      message: `Model retrained with ${stats.totalSamples} feedback samples`
    };
  } catch (error) {
    console.error('Error updating model weights:', error);
    throw error;
  }
}

/**
 * Get feedback summary by sound type
 * Shows which sounds are correctly classified vs. misclassified
 * @param {string} userId - User ID
 * @returns {Object} Map of sound types to feedback stats
 */
export function getFeedbackBySoundType(userId) {
  const db = getDb();

  try {
    const feedback = db
      .prepare(`
        SELECT
          original_classification,
          is_correct,
          COUNT(*) as count
        FROM iml_feedback
        WHERE user_id = ?
        GROUP BY original_classification, is_correct
        ORDER BY original_classification
      `)
      .all(userId);

    const summary = {};

    feedback.forEach(row => {
      if (!summary[row.original_classification]) {
        summary[row.original_classification] = {
          correct: 0,
          incorrect: 0,
          total: 0,
          accuracy: 0
        };
      }

      if (row.is_correct) {
        summary[row.original_classification].correct += row.count;
      } else {
        summary[row.original_classification].incorrect += row.count;
      }

      summary[row.original_classification].total += row.count;
    });

    // Calculate accuracy per sound type
    Object.keys(summary).forEach(soundType => {
      const stats = summary[soundType];
      stats.accuracy = Math.round((stats.correct / stats.total) * 1000) / 10; // 1 decimal
    });

    return summary;
  } catch (error) {
    console.error('Error getting feedback by sound type:', error);
    return {};
  }
}

/**
 * Get most confused sound pairs (sounds often misclassified as each other)
 * @param {string} userId - User ID
 * @param {number} limit - Max results to return
 * @returns {Array} Array of confusion pairs
 */
export function getMostConfusedPairs(userId, limit = 5) {
  const db = getDb();

  try {
    const pairs = db
      .prepare(`
        SELECT
          original_classification,
          corrected_classification,
          COUNT(*) as confusion_count
        FROM iml_feedback
        WHERE user_id = ? AND is_correct = 0 AND corrected_classification IS NOT NULL
        GROUP BY original_classification, corrected_classification
        ORDER BY confusion_count DESC
        LIMIT ?
      `)
      .all(userId, limit);

    return pairs;
  } catch (error) {
    console.error('Error getting confusion pairs:', error);
    return [];
  }
}

export default {
  recordFeedback,
  getModelStats,
  getPendingFeedback,
  getReviewedFeedback,
  updateModelWeights,
  getFeedbackBySoundType,
  getMostConfusedPairs
};
