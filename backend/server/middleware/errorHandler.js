/**
 * Global error handling middleware
 * Catches and formats errors with proper HTTP status codes
 */

/**
 * Validation error handler
 * Format validation errors consistently
 */
export function handleValidationError(errors) {
  return {
    status: 400,
    code: 'VALIDATION_ERROR',
    message: 'Validation failed',
    errors: errors
  };
}

/**
 * Not found error handler
 */
export function handleNotFound(req, res) {
  res.status(404).json({
    status: 404,
    code: 'NOT_FOUND',
    message: `Route ${req.method} ${req.path} not found`
  });
}

/**
 * Global error handler middleware
 * Should be the last middleware in the app
 */
export function globalErrorHandler(err, req, res, next) {
  console.error('Error:', {
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    ip: req.ip
  });

  // Default error response
  let status = err.status || err.statusCode || 500;
  let code = err.code || 'INTERNAL_SERVER_ERROR';
  let message = err.message || 'Internal server error';

  // Handle specific error types
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    status = 400;
    code = 'INVALID_JSON';
    message = 'Invalid JSON in request body';
  }

  if (err.name === 'ValidationError') {
    status = 400;
    code = 'VALIDATION_ERROR';
    message = err.message;
  }

  if (err.message && err.message.includes('not found')) {
    status = 404;
    code = 'NOT_FOUND';
  }

  if (err.code === 'SQLITE_ERROR') {
    status = 500;
    code = 'DATABASE_ERROR';
    message = 'Database operation failed';
  }

  // Send error response
  res.status(status).json({
    status,
    code,
    message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
}

/**
 * Wrapper to catch async errors in route handlers
 * @param {Function} fn - Async function to wrap
 * @returns {Function} Express middleware function
 */
export function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

/**
 * Validation helpers
 */
export const validators = {
  /**
   * Validate required fields
   */
  requireFields: (obj, fields) => {
    const missing = fields.filter(field => !obj[field]);
    if (missing.length > 0) {
      return {
        valid: false,
        errors: missing.map(field => `${field} is required`)
      };
    }
    return { valid: true };
  },

  /**
   * Validate user ID format
   */
  isValidUserId: (userId) => {
    return typeof userId === 'string' && userId.length > 0;
  },

  /**
   * Validate sound type
   */
  isValidSoundType: (soundType) => {
    const validTypes = [
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
    return validTypes.includes(soundType);
  },

  /**
   * Validate confidence score
   */
  isValidConfidence: (confidence) => {
    const num = parseFloat(confidence);
    return !isNaN(num) && num >= 0 && num <= 1;
  },

  /**
   * Validate context location
   */
  isValidLocation: (location) => {
    const validLocations = [
      'home',
      'office',
      'restaurant',
      'outdoors',
      'street',
      'car',
      'transit',
      'school',
      'hospital',
      'gym',
      'park',
      'other'
    ];
    return validLocations.includes(location.toLowerCase());
  },

  /**
   * Validate time of day
   */
  isValidTimeOfDay: (timeOfDay) => {
    const validTimes = ['morning', 'afternoon', 'evening', 'night'];
    return validTimes.includes(timeOfDay.toLowerCase());
  }
};

export default {
  handleValidationError,
  handleNotFound,
  globalErrorHandler,
  asyncHandler,
  validators
};
