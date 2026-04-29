# HearClear Backend

A context-aware hearing aid companion app backend built with Express.js, SQLite, and WebSocket support.

## Features

- Context-aware sound alert filtering using location, calendar, and time of day
- Interactive Machine Learning (IML) feedback system for model improvement
- Real-time alerts via WebSocket
- Hearing program customization with fine-tuning controls
- Transcription session management
- Device status tracking
- RESTful API with comprehensive error handling

## Tech Stack

- **Runtime**: Node.js 18+
- **Framework**: Express.js
- **Database**: SQLite 3 (better-sqlite3)
- **Real-time**: WebSocket (ws)
- **Utilities**: UUID, CORS, dotenv

## Getting Started

### Prerequisites

- Node.js 18.0.0 or higher
- npm or yarn

### Installation

```bash
# Install dependencies
npm install

# Create data directory (if not exists)
mkdir -p data

# Start development server
npm run dev

# Or start production server
npm start
```

The server will start on `http://localhost:3001` by default.

## Project Structure

```
HearClear/
├── server/
│   ├── index.js              # Main Express server
│   ├── database.js           # SQLite setup and initialization
│   ├── middleware/
│   │   └── errorHandler.js   # Global error handling
│   ├── services/
│   │   ├── contextEngine.js  # Context evaluation and alert filtering
│   │   ├── soundClassifier.js # Sound classification simulation
│   │   └── imlService.js     # Interactive ML feedback
│   └── routes/
│       ├── alerts.js         # Alert endpoints
│       ├── iml.js            # IML feedback endpoints
│       ├── environment.js    # Hearing programs & settings
│       ├── profile.js        # User profile & device status
│       └── transcribe.js     # Transcription sessions
├── data/
│   └── hearclear.db         # SQLite database (created on first run)
├── package.json
├── .env
└── README.md
```

## Database Schema

### Core Tables

- **users**: User profiles and hearing device information
- **sound_alerts**: Detected sounds with context and delivery decisions
- **iml_feedback**: User feedback on sound classifications
- **context_rules**: User-defined context-aware filtering rules
- **hearing_programs**: Customizable hearing assistance programs
- **device_status**: Real-time device connection and battery info
- **transcription_sessions**: Conversation recording sessions
- **transcription_lines**: Individual transcribed lines within sessions

## API Endpoints

### Health Check
- `GET /health` - Server health status

### Alerts
- `GET /api/alerts` - List alerts (paginated)
- `GET /api/alerts/:id` - Get single alert
- `POST /api/alerts` - Create new alert with context evaluation
- `GET /api/alerts/context-rules` - Get user's context rules
- `PUT /api/alerts/context-rules/:id` - Toggle context rule
- `POST /api/alerts/simulate` - Simulate sound detection

### Interactive ML
- `GET /api/iml/pending` - Get pending feedback alerts
- `GET /api/iml/reviewed` - Get reviewed feedback
- `GET /api/iml/stats` - Get model accuracy statistics
- `GET /api/iml/analysis` - Get detailed IML insights
- `POST /api/iml/feedback` - Submit feedback on alert
- `POST /api/iml/train` - Trigger model retraining

### Environment
- `GET /api/environment/programs` - Get hearing programs
- `POST /api/environment/programs` - Create custom program
- `PUT /api/environment/programs/:id` - Update program settings
- `GET /api/environment/current` - Get current environment reading
- `PUT /api/environment/settings` - Update fine-tuning settings

### Profile
- `GET /api/profile` - Get user profile
- `PUT /api/profile` - Update user profile
- `GET /api/profile/device` - Get device status
- `PUT /api/profile/device` - Update device status
- `GET /api/profile/summary` - Get complete profile summary

### Transcription
- `GET /api/transcribe/sessions` - List transcription sessions
- `POST /api/transcribe/sessions` - Start new session
- `PUT /api/transcribe/sessions/:id` - End session
- `GET /api/transcribe/sessions/:id/lines` - Get transcription lines
- `POST /api/transcribe/sessions/:id/lines` - Add transcription line
- `GET /api/transcribe/sessions/:id/export` - Export session

## Context-Aware Alert Filtering

The system uses a context engine to intelligently filter alerts:

### Context Factors
- **Location**: home, office, restaurant, outdoors, car, transit, etc.
- **Calendar**: Meeting/busy status
- **Time of Day**: morning, afternoon, evening, night
- **Sleep Mode**: Automatic 10 PM - 7 AM

### Default Filtering Rules
- **Fire alarms/Sirens**: Always delivered (critical safety)
- **In Meeting**: Suppresses doorbells, timers, phone rings
- **Sleep Mode**: Only allows critical sounds and alarms
- **Outdoors**: Prioritizes car horns and sirens
- **Restaurant**: Boosts speech detection, suppresses timers

### User Custom Rules
Users can create custom rules with conditions:
- Time ranges (e.g., 10 PM - 7 AM)
- Location-based (e.g., "at home")
- Calendar-based (e.g., "in meeting")
- Alert actions: suppress, prioritize, enhance

## Interactive ML System

Users can provide feedback on sound classifications to improve model accuracy:

1. **View Pending**: See alerts awaiting classification feedback
2. **Confirm/Correct**: User confirms if classification was correct
3. **Track Stats**: Monitor overall model accuracy by sound type
4. **Model Insights**: Identify misclassification patterns
5. **Retrain**: Trigger periodic model retraining

## WebSocket Events

Real-time updates via WebSocket (`ws://localhost:3001/ws`):

### Message Types

```javascript
// Connection established
{ type: 'connection', message: 'Connected to HearClear server' }

// New alert delivered
{ type: 'alert', data: { ...alert }, timestamp: '...' }

// Device status update
{ type: 'device_status', data: { ...device }, timestamp: '...' }

// Context change
{ type: 'context_update', data: { location, inMeeting, ... }, timestamp: '...' }
```

### Subscribing to Alerts

```javascript
// Send subscription request
ws.send(JSON.stringify({ type: 'subscribe', channel: 'alerts' }))

// Receive confirmation
{ type: 'subscribed', channel: 'alerts' }

// Receive alert notifications
{ type: 'alert', data: {...}, timestamp: '...' }
```

## Sound Types Supported

- doorbell
- fire_alarm
- name_called
- car_horn
- alarm_timer
- baby_crying
- speech
- background_noise
- knock
- microwave
- phone_ring
- smoke_detector
- siren
- motorcycle
- intruder_alarm

## Configuration

### Environment Variables

```env
NODE_ENV=development          # development or production
PORT=3001                     # Server port
DATABASE_PATH=./data/hearclear.db  # Database file location
LOG_LEVEL=info               # debug, info, warn, error
CORS_ORIGIN=...              # Comma-separated CORS origins
```

## Default User

For development, a default user is automatically created:
- **User ID**: `default-user`
- **Name**: Maruthi
- **Device**: Cochlear Nucleus 7
- **Hearing Loss Level**: Profound

Seeded with sample alerts, rules, programs, and feedback.

## Error Handling

All errors follow a consistent format:

```json
{
  "success": false,
  "error": "Error message",
  "status": 400,
  "code": "ERROR_CODE"
}
```

HTTP Status Codes:
- `200`: Success
- `201`: Created
- `400`: Bad Request / Validation Error
- `404`: Not Found
- `500`: Internal Server Error

## Production Deployment

For production:

```bash
# Set environment
export NODE_ENV=production
export PORT=3001

# Install dependencies
npm install --production

# Start server
npm start
```

## Development

```bash
# Install with dev dependencies
npm install

# Start with hot reload
npm run dev

# Note: Database is auto-initialized on startup
# Clear data: rm -rf data/hearclear.db
```

## API Example: Creating an Alert

```bash
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "soundType": "doorbell",
    "confidence": 0.92,
    "location": "home",
    "timeOfDay": "afternoon"
  }'
```

## Performance Considerations

- Database uses WAL (Write-Ahead Logging) for better concurrency
- Foreign keys enabled for referential integrity
- Parameterized queries prevent SQL injection
- WebSocket connections pooled efficiently
- Pagination on all list endpoints

## Security Features

- CORS properly configured
- Input validation on all endpoints
- Error messages don't leak sensitive info
- Database queries use parameterized statements
- XSS protection via JSON serialization

## Troubleshooting

### Database locked error
- SQLite uses file locking; ensure only one server instance is running
- Check for orphaned processes: `lsof | grep hearclear.db`

### WebSocket connection refused
- Verify server is running on correct port
- Check CORS origin configuration
- Ensure firewall allows WebSocket connections

### High memory usage
- Check for memory leaks in long-running processes
- Monitor number of connected WebSocket clients
- Review database query performance

## Future Enhancements

- Real ML model integration (TensorFlow.js)
- User authentication system
- Multi-device synchronization
- Advanced analytics and reporting
- Custom sound training via audio uploads
- Integration with hearing device APIs
- Push notifications
- Offline-first sync

## License

Proprietary - HearClear
