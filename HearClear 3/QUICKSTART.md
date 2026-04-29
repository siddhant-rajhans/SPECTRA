# HearClear Backend - Quick Start Guide

## 5-Minute Setup

### 1. Install Dependencies
```bash
cd /path/to/HearClear
npm install
```

### 2. Start Server
```bash
npm run dev
```

You should see:
```
╔════════════════════════════════════════════════════════╗
║  HearClear Backend Server Started                      ║
╠════════════════════════════════════════════════════════╣
║  Environment: development                              ║
║  HTTP Server: http://localhost:3001                    ║
║  WebSocket: ws://localhost:3001                        ║
╚════════════════════════════════════════════════════════╝
```

### 3. Test Server
```bash
curl http://localhost:3001/health
```

Expected response:
```json
{"status":"healthy","timestamp":"2026-04-04T...","uptime":0.5}
```

## First API Calls

### Get User Profile
```bash
curl http://localhost:3001/api/profile
```

### Get Hearing Programs
```bash
curl http://localhost:3001/api/environment/programs
```

### Create Alert
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

### Get Alerts
```bash
curl http://localhost:3001/api/alerts
```

### Check Model Stats
```bash
curl http://localhost:3001/api/iml/stats
```

## Key Endpoints at a Glance

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/alerts` | Create new alert with context evaluation |
| GET | `/api/alerts` | List recent alerts |
| GET | `/api/iml/pending` | Alerts awaiting user feedback |
| POST | `/api/iml/feedback` | Submit feedback on alert |
| GET | `/api/environment/programs` | List hearing programs |
| PUT | `/api/environment/programs/:id` | Update program |
| GET | `/api/profile` | Get user profile |
| GET | `/api/transcribe/sessions` | List transcription sessions |

## Understanding the Default User

The app comes pre-configured with a default user:

- **User ID**: `default-user` (automatically used if not specified)
- **Name**: Maruthi
- **Device**: Cochlear Nucleus 7
- **Hearing Loss**: Profound

This user has sample data:
- 5 sample alerts
- 4 context rules
- 5 hearing programs
- Device status

## Database

SQLite database is created automatically at:
```
./data/hearclear.db
```

To reset:
```bash
rm -rf data/
npm run dev  # Restart server to recreate
```

## WebSocket Connection

Connect to real-time alerts:

```javascript
const ws = new WebSocket('ws://localhost:3001/ws');

ws.onopen = () => {
  console.log('Connected');
  // Subscribe to alerts
  ws.send(JSON.stringify({ type: 'subscribe', channel: 'alerts' }));
};

ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  if (message.type === 'alert') {
    console.log('New alert:', message.data);
  }
};
```

## Simulating Sound Detection

Test the sound classification system:

```bash
# Random sound
curl -X POST http://localhost:3001/api/alerts/simulate

# Specific sound
curl -X POST http://localhost:3001/api/alerts/simulate \
  -H "Content-Type: application/json" \
  -d '{"soundType": "fire_alarm"}'
```

## Testing Context Rules

Create an alert with different contexts:

```bash
# In a meeting
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "soundType": "doorbell",
    "confidence": 0.85,
    "location": "office",
    "calendarEvents": [{"type": "meeting", "title": "Team Standup"}]
  }'

# At night (sleep mode)
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "soundType": "alarm_timer",
    "confidence": 0.91,
    "timeOfDay": "night"
  }'

# Outdoors (should prioritize safety sounds)
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "soundType": "car_horn",
    "confidence": 0.88,
    "location": "outdoors"
  }'
```

## IML Feedback Loop

1. View pending alerts:
```bash
curl http://localhost:3001/api/iml/pending
```

2. Submit feedback (confirming classification):
```bash
curl -X POST http://localhost:3001/api/iml/feedback \
  -H "Content-Type: application/json" \
  -d '{
    "alertId": "ALERT_ID",
    "isCorrect": true
  }'
```

3. Submit feedback (correcting classification):
```bash
curl -X POST http://localhost:3001/api/iml/feedback \
  -H "Content-Type: application/json" \
  -d '{
    "alertId": "ALERT_ID",
    "isCorrect": false,
    "correctedClassification": "knock"
  }'
```

4. Check model stats:
```bash
curl http://localhost:3001/api/iml/stats
```

## Hearing Program Customization

Get programs:
```bash
curl http://localhost:3001/api/environment/programs
```

Update program settings:
```bash
curl -X PUT http://localhost:3001/api/environment/programs/PROGRAM_ID \
  -H "Content-Type: application/json" \
  -d '{
    "isSelected": true,
    "speechEnhancement": 85,
    "noiseReduction": 75,
    "forwardFocus": 60
  }'
```

Create custom program:
```bash
curl -X POST http://localhost:3001/api/environment/programs \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Custom Program",
    "description": "Optimized for my home setup",
    "speechEnhancement": 80,
    "noiseReduction": 70,
    "forwardFocus": 55,
    "icon": "cog"
  }'
```

## Transcription Sessions

Start session:
```bash
curl -X POST http://localhost:3001/api/transcribe/sessions \
  -H "Content-Type: application/json" \
  -d '{"speakerCount": 2}'
```

Add transcription:
```bash
curl -X POST http://localhost:3001/api/transcribe/sessions/SESSION_ID/lines \
  -H "Content-Type: application/json" \
  -d '{
    "speakerLabel": "You",
    "text": "Hello, how are you today?",
    "timestamp": "00:00:05"
  }'
```

End session:
```bash
curl -X PUT http://localhost:3001/api/transcribe/sessions/SESSION_ID \
  -H "Content-Type: application/json" \
  -d '{"speakerCount": 2}'
```

Export session:
```bash
curl http://localhost:3001/api/transcribe/sessions/SESSION_ID/export
```

## Supported Sound Types

The system recognizes these sounds:
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

## Context Modes

### Sleep Mode (automatic 10 PM - 7 AM)
Only critical sounds delivered:
- fire_alarm, smoke_detector, siren, baby_crying

### Meeting Mode
Suppressed sounds:
- doorbell, alarm_timer, microwave, phone_ring

### Outdoor Mode
Prioritized sounds:
- car_horn, siren, alarm

### Restaurant Mode
Enhanced for speech:
- name_called, speech (prioritized)
- alarm_timer (suppressed)

## Troubleshooting

### "Cannot find module 'better-sqlite3'"
```bash
npm install --build-from-source
```

### "Port 3001 already in use"
```bash
# Change port
PORT=3002 npm run dev

# Or kill process
lsof -ti:3001 | xargs kill -9
```

### "Database locked"
```bash
# Ensure only one server instance
# Check: ps aux | grep node
rm -rf data/hearclear.db data/hearclear.db-*
```

### "Cannot POST /api/alerts"
Ensure:
1. Server is running (`npm run dev`)
2. Port is 3001
3. Content-Type header is set to `application/json`
4. Request body contains required `soundType`

## Development vs Production

### Development
```bash
npm run dev
# Uses nodemon for hot reload
# PORT=3001 (or from .env)
# Detailed error messages
```

### Production
```bash
npm start
# Standard Node.js process
# Set PORT=3001 (or other)
# Minimal error details
```

## Next Steps

1. Read full documentation: `README.md`
2. Explore API endpoints: `README.md#api-endpoints`
3. Check architecture: `BACKEND_SUMMARY.md`
4. Review database schema: `server/database.js`
5. Understand context engine: `server/services/contextEngine.js`

## Common Tasks

### View all alerts
```bash
curl http://localhost:3001/api/alerts?limit=50
```

### Get context rules
```bash
curl http://localhost:3001/api/alerts/context-rules
```

### Toggle context rule
```bash
curl -X PUT http://localhost:3001/api/alerts/context-rules/RULE_ID \
  -H "Content-Type: application/json" \
  -d '{"isActive": false}'
```

### Get IML analysis
```bash
curl http://localhost:3001/api/iml/analysis
```

### Get device status
```bash
curl http://localhost:3001/api/profile/device
```

### Update device battery (simulation)
```bash
curl -X PUT http://localhost:3001/api/profile/device \
  -H "Content-Type: application/json" \
  -d '{"batteryLevel": 45}'
```

That's it! You now have a fully functional HearClear backend running.
