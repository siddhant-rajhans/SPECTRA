import express from 'express';
import { asyncHandler, validators } from '../middleware/errorHandler.js';
import {
  recordFeedback,
  getModelStats,
  getPendingFeedback,
  getReviewedFeedback,
  updateModelWeights,
  getFeedbackBySoundType,
  getMostConfusedPairs
} from '../services/imlService.js';

const router = express.Router();
const DEFAULT_USER_ID = 'default-user';

/**
 * GET /api/iml/pending
 * Get alerts pending user feedback
 * Query params: limit, offset
 */
router.get(
  '/pending',
  asyncHandler(async (req, res) => {
    const userId = req.query.userId || DEFAULT_USER_ID;
    const limit = Math.min(parseInt(req.query.limit) || 10, 50);
    const offset = parseInt(req.query.offset) || 0;

    try {
      const pending = getPendingFeedback(userId, limit, offset);

      res.json({
        success: true,
        data: pending,
        pagination: {
          limit,
          offset,
          hasMore: pending.length === limit
        }
      });
    } catch (error) {
      console.error('Error fetching pending feedback:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch pending feedback'
      });
    }
  })
);

/**
 * GET /api/iml/reviewed
 * Get alerts with user feedback already provided
 * Query params: limit, offset
 */
router.get(
  '/reviewed',
  asyncHandler(async (req, res) => {
    const userId = req.query.userId || DEFAULT_USER_ID;
    const limit = Math.min(parseInt(req.query.limit) || 10, 50);
    const offset = parseInt(req.query.offset) || 0;

    try {
      const reviewed = getReviewedFeedback(userId, limit, offset);

      res.json({
        success: true,
        data: reviewed,
        pagination: {
          limit,
          offset,
          hasMore: reviewed.length === limit
        }
      });
    } catch (error) {
      console.error('Error fetching reviewed feedback:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch reviewed feedback'
      });
    }
  })
);

/**
 * GET /api/iml/stats
 * Get model accuracy statistics
 */
router.get(
  '/stats',
  asyncHandler(async (req, res) => {
    const userId = req.query.userId || DEFAULT_USER_ID;

    try {
      const stats = getModelStats(userId);
      const byType = getFeedbackBySoundType(userId);
      const confusions = getMostConfusedPairs(userId, 5);

      res.json({
        success: true,
        data: {
          overall: stats,
          byType,
          confusedPairs: confusions
        }
      });
    } catch (error) {
      console.error('Error fetching model stats:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch model statistics'
      });
    }
  })
);

/**
 * POST /api/iml/feedback
 * Submit feedback on a sound alert
 * Body: {
 *   alertId: string,
 *   isCorrect: boolean,
 *   correctedClassification?: string (if isCorrect is false)
 * }
 */
router.post(
  '/feedback',
  asyncHandler(async (req, res) => {
    const userId = req.query.userId || req.body.userId || DEFAULT_USER_ID;
    const { alertId, isCorrect, correctedClassification } = req.body;

    // Validate input
    if (!alertId) {
      return res.status(400).json({
        success: false,
        error: 'alertId is required'
      });
    }

    if (typeof isCorrect !== 'boolean') {
      return res.status(400).json({
        success: false,
        error: 'isCorrect must be a boolean'
      });
    }

    // If correcting, ensure valid sound type
    if (!isCorrect && correctedClassification) {
      if (!validators.isValidSoundType(correctedClassification)) {
        return res.status(400).json({
          success: false,
          error: `Invalid sound type for correction: ${correctedClassification}`
        });
      }
    }

    try {
      const feedback = recordFeedback(alertId, userId, isCorrect, correctedClassification);

      res.status(201).json({
        success: true,
        data: feedback,
        message: 'Feedback recorded successfully'
      });
    } catch (error) {
      if (error.message === 'Alert not found') {
        return res.status(404).json({
          success: false,
          error: 'Alert not found'
        });
      }

      console.error('Error recording feedback:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to record feedback'
      });
    }
  })
);

/**
 * POST /api/iml/train
 * Trigger model retraining based on feedback
 * In production, this would initiate actual model retraining
 */
router.post(
  '/train',
  asyncHandler(async (req, res) => {
    const userId = req.query.userId || req.body.userId || DEFAULT_USER_ID;

    try {
      const result = updateModelWeights(userId);

      res.json({
        success: true,
        data: result,
        message: 'Model training completed'
      });
    } catch (error) {
      console.error('Error training model:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to train model'
      });
    }
  })
);

/**
 * GET /api/iml/analysis
 * Get detailed IML analysis and insights
 */
router.get(
  '/analysis',
  asyncHandler(async (req, res) => {
    const userId = req.query.userId || DEFAULT_USER_ID;

    try {
      const stats = getModelStats(userId);
      const byType = getFeedbackBySoundType(userId);
      const confusions = getMostConfusedPairs(userId, 10);

      // Calculate insights
      const insights = {
        strengths: [],
        weaknesses: [],
        recommendations: []
      };

      // Find strongest classifications
      Object.entries(byType).forEach(([soundType, stats]) => {
        if (stats.accuracy >= 90 && stats.total >= 3) {
          insights.strengths.push({
            soundType,
            accuracy: stats.accuracy,
            samples: stats.total
          });
        }
      });

      // Find weakest classifications
      Object.entries(byType).forEach(([soundType, stats]) => {
        if (stats.accuracy < 75 && stats.total >= 2) {
          insights.weaknesses.push({
            soundType,
            accuracy: stats.accuracy,
            samples: stats.total
          });
        }
      });

      // Generate recommendations
      if (confusions.length > 0) {
        insights.recommendations.push(
          `Model often confuses "${confusions[0].original_classification}" with "${confusions[0].corrected_classification}". Consider reviewing these samples.`
        );
      }

      if (stats.totalSamples < 10) {
        insights.recommendations.push(
          `Collect more feedback samples (${10 - stats.totalSamples} more) to improve model accuracy.`
        );
      }

      if (stats.accuracy < 80) {
        insights.recommendations.push(
          'Model accuracy is below 80%. Review misclassified samples to identify patterns.'
        );
      }

      res.json({
        success: true,
        data: {
          overall: stats,
          byType,
          confusedPairs: confusions,
          insights
        }
      });
    } catch (error) {
      console.error('Error generating analysis:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to generate analysis'
      });
    }
  })
);

export default router;
