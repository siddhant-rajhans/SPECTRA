import { getDb } from '../database.js';

/**
 * Evaluate current context based on location, calendar, and time
 * @param {string} location - Current location (e.g., 'home', 'office', 'restaurant', 'outdoors')
 * @param {Array} calendarEvents - Array of current/upcoming calendar events
 * @param {string} timeOfDay - Time of day ('morning', 'afternoon', 'evening', 'night')
 * @returns {Object} Context object with location, calendar, time info
 */
export function evaluateContext(location = 'home', calendarEvents = [], timeOfDay = 'afternoon') {
  const currentHour = new Date().getHours();

  // Determine time of day if not provided
  let determinedTimeOfDay = timeOfDay;
  if (!timeOfDay || timeOfDay === 'auto') {
    if (currentHour >= 5 && currentHour < 12) {
      determinedTimeOfDay = 'morning';
    } else if (currentHour >= 12 && currentHour < 17) {
      determinedTimeOfDay = 'afternoon';
    } else if (currentHour >= 17 && currentHour < 22) {
      determinedTimeOfDay = 'evening';
    } else {
      determinedTimeOfDay = 'night';
    }
  }

  // Check if in sleep mode (10 PM - 7 AM)
  const inSleepMode = currentHour >= 22 || currentHour < 7;

  // Determine if in meeting
  const inMeeting = calendarEvents.some(
    event =>
      event.type === 'meeting' ||
      event.title?.toLowerCase().includes('meeting') ||
      event.title?.toLowerCase().includes('call')
  );

  return {
    location: location.toLowerCase(),
    inMeeting,
    inSleepMode,
    timeOfDay: determinedTimeOfDay,
    currentHour,
    calendarEvents: calendarEvents || [],
    evaluatedAt: new Date().toISOString()
  };
}

/**
 * Determine if an alert should be delivered based on sound type and context
 * @param {string} soundType - Type of sound detected
 * @param {number} confidence - Confidence score 0-1
 * @param {Object} context - Context object from evaluateContext
 * @returns {Object} { deliver: boolean, reason: string }
 */
export function shouldDeliverAlert(soundType, confidence, context = {}) {
  // Always deliver critical safety sounds
  const criticalSounds = ['fire_alarm', 'smoke_detector', 'intruder_alarm', 'siren'];
  if (criticalSounds.includes(soundType)) {
    return {
      deliver: true,
      reason: 'Critical safety alert - always deliver'
    };
  }

  // In sleep mode: only critical sounds and baby crying/alarms
  if (context.inSleepMode) {
    const sleepModeAllowed = ['baby_crying', 'alarm_timer', 'fire_alarm', 'smoke_detector', 'siren'];
    if (!sleepModeAllowed.includes(soundType)) {
      return {
        deliver: false,
        reason: 'Sleep mode active - non-critical sounds suppressed'
      };
    }
  }

  // In meeting: suppress non-critical household sounds
  if (context.inMeeting) {
    const meetingSuppressed = ['doorbell', 'alarm_timer', 'microwave', 'phone_ring'];
    if (meetingSuppressed.includes(soundType)) {
      return {
        deliver: false,
        reason: 'Meeting context - non-critical sounds suppressed'
      };
    }
    // Allow names, car horns, and alarms during meetings
  }

  // Outdoor context: prioritize safety sounds
  if (context.location === 'outdoors' || context.location === 'street') {
    const outdoorPriority = ['car_horn', 'siren', 'alarm', 'fire_alarm', 'motorcycle'];
    if (outdoorPriority.includes(soundType)) {
      return {
        deliver: true,
        reason: 'Safety-critical outdoor sound'
      };
    }
    // Suppress less important sounds outdoors
    const outdoorSuppressed = ['doorbell', 'microwave'];
    if (outdoorSuppressed.includes(soundType)) {
      return {
        deliver: false,
        reason: 'Outdoor context - household sounds suppressed'
      };
    }
  }

  // Restaurant context: boost speech detection, suppress timer
  if (context.location === 'restaurant') {
    if (soundType === 'alarm_timer') {
      return {
        deliver: false,
        reason: 'Restaurant context - timer suppressed'
      };
    }
    if (soundType === 'name_called' || soundType === 'speech') {
      return {
        deliver: true,
        reason: 'Restaurant context - speech detection prioritized'
      };
    }
  }

  // Default behavior: deliver if confidence is above threshold
  const threshold = getConfidenceThreshold(soundType);
  if (confidence >= threshold) {
    return {
      deliver: true,
      reason: `Confidence ${(confidence * 100).toFixed(1)}% meets threshold of ${(threshold * 100).toFixed(1)}%`
    };
  }

  return {
    deliver: false,
    reason: `Confidence ${(confidence * 100).toFixed(1)}% below threshold of ${(threshold * 100).toFixed(1)}%`
  };
}

/**
 * Get confidence threshold for different sound types
 * @param {string} soundType - Type of sound
 * @returns {number} Confidence threshold 0-1
 */
function getConfidenceThreshold(soundType) {
  const thresholds = {
    fire_alarm: 0.70,
    smoke_detector: 0.70,
    siren: 0.75,
    car_horn: 0.80,
    baby_crying: 0.75,
    doorbell: 0.85,
    name_called: 0.80,
    speech: 0.75,
    alarm_timer: 0.85,
    phone_ring: 0.85,
    microwave: 0.80,
    knock: 0.80,
    background_noise: 0.90
  };

  return thresholds[soundType] || 0.85;
}

/**
 * Get active context rules for a user based on current context
 * @param {string} userId - User ID
 * @param {Object} currentContext - Current context from evaluateContext
 * @returns {Array} Array of active rules that match current context
 */
export function getActiveRules(userId, currentContext = {}) {
  const db = getDb();

  try {
    const rules = db
      .prepare(`
        SELECT id, name, description, condition_type, condition_value, alert_action, priority
        FROM context_rules
        WHERE user_id = ? AND is_active = 1
        ORDER BY priority ASC
      `)
      .all(userId);

    // Filter rules based on current context
    return rules.filter(rule => {
      const conditionType = rule.condition_type;
      const conditionValue = rule.condition_value;

      switch (conditionType) {
        case 'time_range': {
          const [startTime, endTime] = conditionValue.split('-');
          const [startHour] = startTime.split(':').map(Number);
          const [endHour] = endTime.split(':').map(Number);
          const currentHour = currentContext.currentHour || new Date().getHours();

          // Handle overnight ranges (e.g., 22:00-07:00)
          if (startHour > endHour) {
            return currentHour >= startHour || currentHour < endHour;
          }
          return currentHour >= startHour && currentHour < endHour;
        }

        case 'location':
          return currentContext.location === conditionValue.toLowerCase();

        case 'calendar_event':
          if (conditionValue === 'in_meeting') {
            return currentContext.inMeeting;
          }
          return false;

        case 'time_of_day':
          return currentContext.timeOfDay === conditionValue;

        default:
          return false;
      }
    });
  } catch (error) {
    console.error('Error getting active rules:', error);
    return [];
  }
}

/**
 * Apply context rules to a sound alert
 * @param {string} userId - User ID
 * @param {string} soundType - Type of sound
 * @param {number} confidence - Confidence score
 * @param {Object} context - Context object
 * @returns {Object} Decision with delivery flag and reasoning
 */
export function applyContextualDecision(userId, soundType, confidence, context = {}) {
  // First check hard rules
  const hardDecision = shouldDeliverAlert(soundType, confidence, context);
  if (!hardDecision.deliver && hardDecision.reason.includes('Critical')) {
    // Critical alarms override everything
    return hardDecision;
  }

  // Get user's context rules
  const userRules = getActiveRules(userId, context);

  // Apply user rules
  for (const rule of userRules) {
    if (rule.alert_action === 'suppress_non_critical') {
      const nonCritical = ['doorbell', 'alarm_timer', 'microwave', 'phone_ring'];
      if (nonCritical.includes(soundType)) {
        return {
          deliver: false,
          reason: `Rule "${rule.name}" suppressed this sound`,
          appliedRule: rule.id
        };
      }
    }

    if (rule.alert_action === 'critical_only') {
      const critical = ['fire_alarm', 'smoke_detector', 'siren', 'baby_crying'];
      if (!critical.includes(soundType)) {
        return {
          deliver: false,
          reason: `Rule "${rule.name}" - only critical sounds allowed`,
          appliedRule: rule.id
        };
      }
    }

    if (rule.alert_action === 'prioritize_environmental') {
      const environmental = ['car_horn', 'siren', 'alarm', 'motorcycle'];
      if (environmental.includes(soundType)) {
        return {
          deliver: true,
          reason: `Rule "${rule.name}" - environmental sound prioritized`,
          appliedRule: rule.id
        };
      }
    }

    if (rule.alert_action === 'enhance_speech') {
      if (soundType === 'name_called' || soundType === 'speech') {
        return {
          deliver: true,
          reason: `Rule "${rule.name}" - speech detection enhanced`,
          appliedRule: rule.id
        };
      }
    }
  }

  // Fall back to default decision
  return hardDecision;
}

export default {
  evaluateContext,
  shouldDeliverAlert,
  getActiveRules,
  applyContextualDecision
};
