# HearClear Backend - Development Guide

## Architecture Overview

HearClear backend uses a layered architecture:

```
┌─────────────────────────────────────────────┐
│         Express.js HTTP Server              │
├─────────────────────────────────────────────┤
│     Routes (API endpoints)                  │
├─────────────────────────────────────────────┤
│  Services (Business Logic)                  │
│  - ContextEngine                            │
│  - SoundClassifier                          │
│  - IMLService                               │
├─────────────────────────────────────────────┤
│    Database Layer (SQLite)                  │
├─────────────────────────────────────────────┤
│    WebSocket Server (Real-time updates)     │
└─────────────────────────────────────────────┘
```

## File Organization

```
server/
├── index.js                 # Express app, HTTP/WebSocket setup
├── database.js              # SQLite initialization and utilities
├── middleware/
│   └── errorHandler.js      # Global error handling
├── services/
│   ├── contextEngine.js     # Alert filtering logic
│   ├── soundClassifier.js   # ML sound classification
│   └── imlService.js        # Interactive ML feedback
└── routes/
    ├── alerts.js            # Alert endpoints
    ├── iml.js               # IML endpoints
    ├── environment.js       # Hearing programs
    ├── profile.js           # User profile
    └── transcribe.js        # Transcription
```

## Core Components

### 1. ContextEngine (server/services/contextEngine.js)

Determines whether an alert should be delivered based on context.

**Key Functions**:
- `evaluateContext(location, calendarEvents, timeOfDay)` - Analyzes current context
- `shouldDeliverAlert(soundType, confidence, context)` - Makes delivery decision
- `getActiveRules(userId, context)` - Gets applicable rules
- `applyContextualDecision(userId, soundType, confidence, context)` - Full decision logic

**Decision Logic Flow**:
1. Check if critical safety sound (always deliver)
2. Evaluate sleep mode (10 PM - 7 AM)
3. Check meeting context
4. Check outdoor context
5. Check restaurant context
6. Apply user custom rules
7. Compare confidence vs threshold

**Example**: Fire alarm with 98% confidence always delivers, regardless of context.

### 2. SoundClassifier (server/services/soundClassifier.js)

Simulates on-device ML sound classification.

**Key Functions**:
- `classifySound(audioFeatures)` - Classifies sound with confidence
- `simulateAmbientListening()` - Random sound for testing
- `getConfidenceThreshold(soundType)` - Gets threshold for sound type
- `isValidSoundType(soundType)` - Validates sound

**Audio Features**:
- Frequency (Hz) - 0 to 8000
- Amplitude (0-1) - Volume level
- MFCC (0-1) - Timbral characteristics
- Pattern - continuous, burst, rhythmic, speech

**In Production**: Replace with actual ML model (TensorFlow.js, ONNX, etc.)

### 3. IMLService (server/services/imlService.js)

Collects user feedback to improve sound classification.

**Key Functions**:
- `recordFeedback(alertId, userId, isCorrect, correctedClassification)`
- `getModelStats(userId)` - Overall accuracy
- `getPendingFeedback(userId)` - Awaiting user input
- `getReviewedFeedback(userId)` - User has reviewed
- `updateModelWeights(userId)` - Trigger retraining
- `getFeedbackBySoundType(userId)` - Per-sound accuracy
- `getMostConfusedPairs(userId)` - Misclassification patterns

**Workflow**:
1. User sees pending alert without feedback
2. User confirms correct or provides correction
3. Feedback recorded to database
4. Model accuracy recalculated
5. Periodic retraining can be triggered

### 4. Database (server/database.js)

SQLite database with 8 tables.

**Key Tables**:
- `users` - User profiles
- `sound_alerts` - Detected sounds
- `iml_feedback` - User feedback
- `context_rules` - Custom filtering rules
- `hearing_programs` - Customizable programs
- `device_status` - Real-time device info
- `transcription_sessions` - Recording sessions
- `transcription_lines` - Transcribed text

**Important Features**:
- Foreign key constraints
- WAL mode for concurrency
- Parameterized queries (SQL injection prevention)
- Automatic timestamps

## Adding New Features

### Adding a New Sound Type

1. **Update soundClassifier.js**:
```javascript
const SOUND_TYPES = [
  // ...existing types...
  'new_sound_type'
];

const CONFIDENCE_THRESHOLDS = {
  // ...
  new_sound_type: 0.80
};
```

2. **Update contextEngine.js** if special handling needed:
```javascript
// In shouldDeliverAlert()
if (soundType === 'new_sound_type') {
  // Custom logic
}
```

3. **Test in routes/alerts.js**:
```javascript
POST /api/alerts
{
  "soundType": "new_sound_type",
  "confidence": 0.85
}
```

### Adding a New Endpoint

1. **Create/update route file** in `server/routes/`:
```javascript
import express from 'express';
import { getDb } from '../database.js';
import { asyncHandler } from '../middleware/errorHandler.js';

const router = express.Router();
const DEFAULT_USER_ID = 'default-user';

// GET example
router.get('/', asyncHandler(async (req, res) => {
  const db = getDb();
  try {
    const data = db.prepare('SELECT * FROM table').all();
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
}));

export default router;
```

2. **Mount in server/index.js**:
```javascript
import newRouter from './routes/new.js';
app.use('/api/new', newRouter);
```

3. **Test**:
```bash
curl http://localhost:3001/api/new
```

### Adding Database Table

1. **Create table in database.js**:
```javascript
function createTables() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS new_table (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      field_name TYPE DEFAULT value,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `);
}
```

2. **Add to seed if default data needed**:
```javascript
function seedDefaultData() {
  const stmt = db.prepare('INSERT INTO new_table (...) VALUES (...)');
  stmt.run(...values);
}
```

## Testing

### Manual Testing with cURL

```bash
# Test GET
curl http://localhost:3001/api/alerts

# Test POST
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{"soundType": "doorbell", "confidence": 0.92}'

# Test with pagination
curl 'http://localhost:3001/api/alerts?limit=10&offset=0'

# Test with query params
curl 'http://localhost:3001/api/alerts?userId=default-user'
```

### Testing WebSocket

```javascript
const ws = new WebSocket('ws://localhost:3001/ws');

ws.onopen = () => {
  console.log('Connected');
  ws.send(JSON.stringify({ type: 'subscribe', channel: 'alerts' }));
};

ws.onmessage = (event) => {
  console.log('Message:', JSON.parse(event.data));
};

ws.onerror = (error) => {
  console.error('WebSocket error:', error);
};
```

### Testing Context Evaluation

```bash
# Test in meeting (doorbell should be suppressed)
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "soundType": "doorbell",
    "confidence": 0.92,
    "calendarEvents": [{"type": "meeting", "title": "Team Standup"}],
    "location": "office"
  }'

# Test at night (timer should be suppressed in sleep mode)
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "soundType": "alarm_timer",
    "confidence": 0.91,
    "timeOfDay": "night"
  }'
```

### Testing IML Feedback

```bash
# Get pending feedback
curl http://localhost:3001/api/iml/pending

# Submit feedback (correct)
curl -X POST http://localhost:3001/api/iml/feedback \
  -H "Content-Type: application/json" \
  -d '{"alertId": "ALERT_UUID", "isCorrect": true}'

# Submit feedback (incorrect, with correction)
curl -X POST http://localhost:3001/api/iml/feedback \
  -H "Content-Type: application/json" \
  -d '{
    "alertId": "ALERT_UUID",
    "isCorrect": false,
    "correctedClassification": "knock"
  }'

# Get stats
curl http://localhost:3001/api/iml/stats
```

## Debugging

### Enable Detailed Logging

Edit `server/index.js`:
```javascript
// Add detailed logging
app.use((req, res, next) => {
  console.log('Incoming:', {
    method: req.method,
    path: req.path,
    body: req.body,
    query: req.query
  });
  next();
});
```

### Database Debugging

```javascript
// In route handler
const db = getDb();
const result = db.prepare('SELECT * FROM users').all();
console.log('Query result:', result);
```

### Check Database State

```bash
# Install sqlite3 CLI if not available
sqlite3 data/hearclear.db

# In SQLite shell
sqlite> .schema
sqlite> SELECT COUNT(*) FROM sound_alerts;
sqlite> SELECT * FROM sound_alerts LIMIT 1;
sqlite> .exit
```

### Clear and Reset Database

```bash
# Remove database
rm -rf data/

# Server will recreate on startup
npm run dev
```

## Common Development Tasks

### Viewing Request/Response

Add logging middleware:
```javascript
app.use((req, res, next) => {
  const originalJson = res.json;
  res.json = function(body) {
    console.log('Response:', body);
    return originalJson.call(this, body);
  };
  next();
});
```

### Testing Error Handling

```bash
# Invalid sound type
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{"soundType": "invalid_sound", "confidence": 0.85}'

# Missing required field
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{"confidence": 0.85}'

# Invalid confidence
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{"soundType": "doorbell", "confidence": 1.5}'
```

### Adding Debug Logs

```javascript
// In services/contextEngine.js
export function shouldDeliverAlert(soundType, confidence, context = {}) {
  console.log('shouldDeliverAlert:', { soundType, confidence, context });
  // ... rest of function
  console.log('Decision:', { deliver, reason });
}
```

## Performance Optimization

### Database Queries

Current optimizations:
- Parameterized queries
- Limited pagination (max 100 per page)
- WAL mode for concurrency
- Proper use of LIMIT/OFFSET

To optimize further:
```javascript
// Add indexes
CREATE INDEX idx_user_id ON table_name(user_id);
CREATE INDEX idx_created_at ON table_name(created_at);
```

### WebSocket Broadcasting

Current implementation:
- Connected clients stored in Map
- Filtering by subscription
- JSON serialization once

Potential improvements:
- Implement room/channel system
- Add message compression
- Batch broadcasts

## Production Readiness Checklist

- [x] All routes have error handling
- [x] Database queries use parameters
- [x] Input validation on endpoints
- [x] HTTP status codes correct
- [x] Environment variables used
- [x] Database normalized
- [x] Foreign keys enabled
- [x] Graceful shutdown
- [x] CORS properly configured
- [x] Health check endpoint
- [x] Logging implemented
- [x] WebSocket support
- [x] Static file serving
- [x] Database initialization

## Deployment Considerations

1. **Database**: SQLite works for small deployments. For scale, migrate to PostgreSQL.
2. **WebSocket**: Works with single server. For multiple servers, use Redis pub/sub.
3. **Static Files**: Serve via CDN in production.
4. **Security**: Add authentication, rate limiting, input sanitization.
5. **Monitoring**: Add error tracking (Sentry), APM (New Relic).
6. **Scaling**: Consider horizontal scaling with load balancer.

## Future Enhancements

1. **Authentication**: JWT tokens, OAuth integration
2. **API Documentation**: OpenAPI/Swagger
3. **Rate Limiting**: Prevent abuse
4. **Caching**: Redis for frequently accessed data
5. **Analytics**: Track usage patterns
6. **Testing**: Unit tests, integration tests
7. **Monitoring**: Health metrics, performance monitoring
8. **ML Integration**: Real neural network model
9. **Mobile Sync**: Device-to-server synchronization
10. **Offline Support**: Offline-first architecture

## Support & Resources

- Express.js: https://expressjs.com
- better-sqlite3: https://github.com/WiseLibs/better-sqlite3
- WebSocket: https://developer.mozilla.org/en-US/docs/Web/API/WebSocket
- SQLite: https://www.sqlite.org/docs.html

## Code Style

- Use async/await (not callbacks)
- Use arrow functions for callbacks
- Parameter validation at function entry
- Descriptive variable names
- Comments for complex logic
- JSDoc for public functions
- Try-catch in async functions
- Consistent indentation (2 spaces)
