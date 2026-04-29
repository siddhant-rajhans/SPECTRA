/**
 * Sound Classifier Service
 * Simulates on-device ML sound classification
 * In production, this would interface with an actual ML model
 */

const SOUND_TYPES = [
  'doorbell',
  'fire_alarm',
  'name_called',
  'car_horn',
  'alarm_timer',
  'baby_crying',
  'speech',
  'background_noise',
  'knock',
  'microwave',
  'phone_ring',
  'smoke_detector',
  'siren',
  'motorcycle',
  'intruder_alarm'
];

/**
 * Confidence thresholds for different sound types
 * Higher threshold = more certainty required before classification
 */
const CONFIDENCE_THRESHOLDS = {
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
  background_noise: 0.90,
  motorcycle: 0.80,
  intruder_alarm: 0.75
};

/**
 * Classify audio features into a sound type and confidence
 * Simulates ML model classification
 * @param {Object} audioFeatures - Audio features object
 * @param {number} audioFeatures.frequency - Dominant frequency (Hz)
 * @param {number} audioFeatures.amplitude - Overall amplitude (0-1)
 * @param {number} audioFeatures.mfcc - Mel-frequency cepstral coefficients (0-1)
 * @param {string} audioFeatures.pattern - Sound pattern ('continuous', 'burst', 'rhythmic', 'speech')
 * @returns {Object} { type: string, confidence: number }
 */
export function classifySound(audioFeatures = {}) {
  // Default features if not provided
  const features = {
    frequency: audioFeatures.frequency || Math.random() * 8000,
    amplitude: audioFeatures.amplitude || Math.random(),
    mfcc: audioFeatures.mfcc || Math.random(),
    pattern: audioFeatures.pattern || 'continuous'
  };

  let classification = simulateMLClassification(features);

  return {
    type: classification.type,
    confidence: classification.confidence,
    features: features,
    timestamp: new Date().toISOString()
  };
}

/**
 * Simulate ML-based sound classification using audio features
 * @param {Object} features - Extracted audio features
 * @returns {Object} { type: string, confidence: number }
 */
function simulateMLClassification(features) {
  const { frequency, amplitude, mfcc, pattern } = features;

  // Rule-based simulation that mimics ML behavior
  // In production, this would be an actual neural network

  // Fire alarm: high frequency (3000-4000 Hz), burst pattern, high amplitude
  if (frequency > 2500 && frequency < 4500 && amplitude > 0.6 && pattern === 'burst') {
    return {
      type: 'fire_alarm',
      confidence: 0.85 + Math.random() * 0.15
    };
  }

  // Car horn: moderate-high frequency (800-2000 Hz), continuous, high amplitude
  if (frequency > 600 && frequency < 2200 && amplitude > 0.7 && pattern === 'continuous') {
    return {
      type: 'car_horn',
      confidence: 0.82 + Math.random() * 0.15
    };
  }

  // Doorbell: high frequency (2000-3500 Hz), rhythmic pattern, medium amplitude
  if (frequency > 1800 && frequency < 3700 && pattern === 'rhythmic' && amplitude > 0.5) {
    return {
      type: 'doorbell',
      confidence: 0.80 + Math.random() * 0.15
    };
  }

  // Phone ring: high frequency (1000-2000 Hz), rhythmic burst pattern
  if (frequency > 800 && frequency < 2100 && pattern === 'rhythmic' && amplitude > 0.6) {
    return {
      type: 'phone_ring',
      confidence: 0.82 + Math.random() * 0.15
    };
  }

  // Alarm timer: high frequency (2000-3000 Hz), continuous rhythmic
  if (frequency > 1800 && frequency < 3100 && pattern === 'rhythmic' && amplitude > 0.7) {
    return {
      type: 'alarm_timer',
      confidence: 0.81 + Math.random() * 0.15
    };
  }

  // Baby crying: high frequency (500-2000 Hz), speech pattern, high amplitude
  if (frequency > 400 && frequency < 2100 && amplitude > 0.7 && pattern === 'speech') {
    return {
      type: 'baby_crying',
      confidence: 0.78 + Math.random() * 0.15
    };
  }

  // Speech/name called: moderate frequency (100-4000 Hz), speech pattern
  if (pattern === 'speech' && mfcc > 0.4) {
    return {
      type: 'name_called',
      confidence: 0.75 + Math.random() * 0.15
    };
  }

  // Knock: low-moderate frequency (100-500 Hz), burst pattern
  if (frequency < 600 && pattern === 'burst' && amplitude > 0.5) {
    return {
      type: 'knock',
      confidence: 0.75 + Math.random() * 0.15
    };
  }

  // Microwave: moderate frequency (500-1500 Hz), continuous with small variations
  if (frequency > 400 && frequency < 1600 && amplitude > 0.4 && amplitude < 0.8) {
    return {
      type: 'microwave',
      confidence: 0.72 + Math.random() * 0.15
    };
  }

  // Siren: sweeping frequency, high amplitude, burst pattern
  if (amplitude > 0.8 && pattern === 'burst') {
    return {
      type: 'siren',
      confidence: 0.83 + Math.random() * 0.15
    };
  }

  // Motorcycle: low frequency (200-1000 Hz), high amplitude, continuous
  if (frequency > 150 && frequency < 1100 && amplitude > 0.75 && pattern === 'continuous') {
    return {
      type: 'motorcycle',
      confidence: 0.79 + Math.random() * 0.15
    };
  }

  // Default: background noise or low confidence match
  return {
    type: 'background_noise',
    confidence: 0.5 + Math.random() * 0.35
  };
}

/**
 * Get confidence threshold for a sound type
 * @param {string} soundType - Type of sound
 * @returns {number} Confidence threshold 0-1
 */
export function getConfidenceThreshold(soundType) {
  return CONFIDENCE_THRESHOLDS[soundType] || 0.85;
}

/**
 * Generate random sound event for ambient listening simulation
 * Used for demo and testing purposes
 * @returns {Object} Random sound classification
 */
export function simulateAmbientListening() {
  const randomSoundType = SOUND_TYPES[Math.floor(Math.random() * SOUND_TYPES.length)];

  // Generate random but realistic audio features
  const features = {
    frequency: Math.random() * 8000, // 0-8000 Hz
    amplitude: Math.random(),
    mfcc: Math.random(),
    pattern: ['continuous', 'burst', 'rhythmic', 'speech'][
      Math.floor(Math.random() * 4)
    ]
  };

  // Bias toward the selected sound type
  let confidence = CONFIDENCE_THRESHOLDS[randomSoundType] + (Math.random() * 0.1 - 0.05);
  confidence = Math.max(0.5, Math.min(1.0, confidence)); // Clamp to 0.5-1.0

  return {
    type: randomSoundType,
    confidence: confidence,
    features: features,
    source: 'ambient_listening',
    timestamp: new Date().toISOString()
  };
}

/**
 * Get list of all supported sound types
 * @returns {Array} Array of sound type strings
 */
export function getSupportedSoundTypes() {
  return [...SOUND_TYPES];
}

/**
 * Validate if a sound type is supported
 * @param {string} soundType - Sound type to validate
 * @returns {boolean} True if sound type is supported
 */
export function isValidSoundType(soundType) {
  return SOUND_TYPES.includes(soundType);
}

/**
 * Get all confidence thresholds
 * @returns {Object} Map of sound types to thresholds
 */
export function getAllThresholds() {
  return { ...CONFIDENCE_THRESHOLDS };
}

export default {
  classifySound,
  getConfidenceThreshold,
  simulateAmbientListening,
  getSupportedSoundTypes,
  isValidSoundType,
  getAllThresholds
};
