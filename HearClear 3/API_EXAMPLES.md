# HearClear API Examples

Complete examples for all API endpoints. All examples use `curl`. Adjust `http://localhost:3001` if server runs on different URL/port.

## Health Check

```bash
curl http://localhost:3001/health
```

Response:
```json
{
  "status": "healthy",
  "timestamp": "2026-04-04T10:15:30.123Z",
  "uptime": 45.67
}
```

## Alerts API

### Create Alert

Basic alert:
```bash
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "soundType": "doorbell",
    "confidence": 0.92
  }'
```

With full context:
```bash
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "soundType": "name_called",
    "confidence": 0.85,
    "location": "restaurant",
    "calendarEvents": [
      {
        "type": "meeting",
        "title": "Lunch with team"
      }
    ],
    "timeOfDay": "afternoon"
  }'
```

Response:
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "user_id": "default-user",
    "sound_type": "doorbell",
    "confidence": 0.92,
    "was_delivered": 1,
    "delivery_reason": "Critical household sound",
    "context_location": "home",
    "context_calendar": null,
    "context_time_of_day": "afternoon",
    "created_at": "2026-04-04T10:15:30.123Z"
  },
  "decision": {
    "deliver": true,
    "reason": "Critical household sound",
    "appliedRule": null
  },
  "context": {
    "location": "home",
    "inMeeting": false,
    "inSleepMode": false,
    "timeOfDay": "afternoon"
  }
}
```

### Get Alerts

List all alerts:
```bash
curl http://localhost:3001/api/alerts
```

With pagination:
```bash
curl 'http://localhost:3001/api/alerts?limit=10&offset=0'
```

For specific user:
```bash
curl 'http://localhost:3001/api/alerts?userId=default-user&limit=20'
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "sound_type": "doorbell",
      "confidence": 0.92,
      "was_delivered": 1,
      "delivery_reason": "Critical household sound",
      "context_location": "home",
      "created_at": "2026-04-04T10:15:30.123Z"
    }
  ],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "total": 42,
    "hasMore": true
  }
}
```

### Get Single Alert

```bash
curl http://localhost:3001/api/alerts/550e8400-e29b-41d4-a716-446655440000
```

### Get Context Rules

```bash
curl http://localhost:3001/api/alerts/context-rules
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "user_id": "default-user",
      "name": "Meeting Mode",
      "description": "Active during calendar meetings",
      "condition_type": "calendar_event",
      "condition_value": "in_meeting",
      "alert_action": "suppress_non_critical",
      "priority": 0,
      "is_active": 1,
      "created_at": "2026-04-04T10:15:30.123Z"
    }
  ]
}
```

### Toggle Context Rule

Enable rule:
```bash
curl -X PUT http://localhost:3001/api/alerts/context-rules/550e8400-e29b-41d4-a716-446655440001 \
  -H "Content-Type: application/json" \
  -d '{"isActive": true}'
```

Disable rule:
```bash
curl -X PUT http://localhost:3001/api/alerts/context-rules/550e8400-e29b-41d4-a716-446655440001 \
  -H "Content-Type: application/json" \
  -d '{"isActive": false}'
```

### Simulate Sound Detection

Random sound:
```bash
curl -X POST http://localhost:3001/api/alerts/simulate
```

Specific sound:
```bash
curl -X POST http://localhost:3001/api/alerts/simulate \
  -H "Content-Type: application/json" \
  -d '{"soundType": "fire_alarm"}'
```

## Interactive ML API

### Get Pending Feedback

```bash
curl 'http://localhost:3001/api/iml/pending?limit=10'
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440002",
      "sound_type": "doorbell",
      "confidence": 0.85,
      "was_delivered": 1,
      "delivery_reason": "Critical household sound",
      "context_location": "home",
      "context_time_of_day": "afternoon",
      "created_at": "2026-04-04T10:15:30.123Z"
    }
  ],
  "pagination": {
    "limit": 10,
    "offset": 0,
    "hasMore": false
  }
}
```

### Get Reviewed Feedback

```bash
curl 'http://localhost:3001/api/iml/reviewed?limit=10'
```

### Get Model Stats

```bash
curl http://localhost:3001/api/iml/stats
```

Response:
```json
{
  "success": true,
  "data": {
    "overall": {
      "confirmed": 8,
      "corrected": 2,
      "accuracy": 80.0,
      "totalSamples": 10,
      "lastUpdated": "2026-04-04T10:15:30.123Z"
    },
    "byType": {
      "doorbell": {
        "correct": 3,
        "incorrect": 0,
        "total": 3,
        "accuracy": 100.0
      },
      "name_called": {
        "correct": 1,
        "incorrect": 1,
        "total": 2,
        "accuracy": 50.0
      }
    },
    "confusedPairs": [
      {
        "original_classification": "doorbell",
        "corrected_classification": "knock",
        "confusion_count": 1
      }
    ]
  }
}
```

### Get IML Analysis

```bash
curl http://localhost:3001/api/iml/analysis
```

Response includes insights:
```json
{
  "success": true,
  "data": {
    "overall": {...},
    "byType": {...},
    "confusedPairs": [...],
    "insights": {
      "strengths": [
        {
          "soundType": "fire_alarm",
          "accuracy": 95.0,
          "samples": 5
        }
      ],
      "weaknesses": [
        {
          "soundType": "name_called",
          "accuracy": 60.0,
          "samples": 3
        }
      ],
      "recommendations": [
        "Model often confuses 'doorbell' with 'knock'. Review these samples.",
        "Collect more feedback samples to improve model accuracy."
      ]
    }
  }
}
```

### Submit Feedback (Correct)

```bash
curl -X POST http://localhost:3001/api/iml/feedback \
  -H "Content-Type: application/json" \
  -d '{
    "alertId": "550e8400-e29b-41d4-a716-446655440000",
    "isCorrect": true
  }'
```

### Submit Feedback (Incorrect with Correction)

```bash
curl -X POST http://localhost:3001/api/iml/feedback \
  -H "Content-Type: application/json" \
  -d '{
    "alertId": "550e8400-e29b-41d4-a716-446655440000",
    "isCorrect": false,
    "correctedClassification": "knock"
  }'
```

Response:
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440003",
    "alertId": "550e8400-e29b-41d4-a716-446655440000",
    "userId": "default-user",
    "originalClassification": "doorbell",
    "isCorrect": false,
    "correctedClassification": "knock",
    "created": true
  },
  "message": "Feedback recorded successfully"
}
```

### Trigger Model Retraining

```bash
curl -X POST http://localhost:3001/api/iml/train
```

## Environment API

### Get Hearing Programs

```bash
curl http://localhost:3001/api/environment/programs
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440004",
      "user_id": "default-user",
      "name": "Home / Quiet",
      "description": "Optimized for quiet home environments",
      "icon": "home",
      "speech_enhancement": 75,
      "noise_reduction": 60,
      "forward_focus": 50,
      "is_selected": 1,
      "created_at": "2026-04-04T10:15:30.123Z"
    }
  ]
}
```

### Update Program Settings

Select program:
```bash
curl -X PUT http://localhost:3001/api/environment/programs/550e8400-e29b-41d4-a716-446655440004 \
  -H "Content-Type: application/json" \
  -d '{"isSelected": true}'
```

Update settings:
```bash
curl -X PUT http://localhost:3001/api/environment/programs/550e8400-e29b-41d4-a716-446655440004 \
  -H "Content-Type: application/json" \
  -d '{
    "speechEnhancement": 85,
    "noiseReduction": 75,
    "forwardFocus": 60
  }'
```

### Create Custom Program

```bash
curl -X POST http://localhost:3001/api/environment/programs \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Custom Program",
    "description": "Optimized for my specific needs",
    "speechEnhancement": 80,
    "noiseReduction": 70,
    "forwardFocus": 55,
    "icon": "cog"
  }'
```

### Get Current Environment

```bash
curl http://localhost:3001/api/environment/current
```

Response:
```json
{
  "success": true,
  "data": {
    "noiseLevel": 72,
    "soundProfile": "moderate",
    "frequencyContent": {
      "bass": 45.2,
      "mid": 62.1,
      "treble": 38.9
    },
    "suggestedProgram": "Restaurant / Crowd",
    "timestamp": "2026-04-04T10:15:30.123Z"
  }
}
```

### Update Fine-tuning Settings

```bash
curl -X PUT http://localhost:3001/api/environment/settings \
  -H "Content-Type: application/json" \
  -d '{
    "speechEnhancement": 80,
    "noiseReduction": 65,
    "forwardFocus": 55,
    "bassBoost": 3,
    "trebleBoost": -2
  }'
```

## Profile API

### Get User Profile

```bash
curl http://localhost:3001/api/profile
```

Response:
```json
{
  "success": true,
  "data": {
    "id": "default-user",
    "name": "Maruthi",
    "device_brand": "Cochlear",
    "device_model": "Nucleus 7",
    "hearing_loss_level": "Profound",
    "created_at": "2026-04-04T10:15:30.123Z"
  }
}
```

### Update Profile

```bash
curl -X PUT http://localhost:3001/api/profile \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Name",
    "deviceBrand": "Phonak",
    "deviceModel": "Paradise",
    "hearingLossLevel": "Severe"
  }'
```

### Get Device Status

```bash
curl http://localhost:3001/api/profile/device
```

Response:
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440005",
    "user_id": "default-user",
    "device_name": "Cochlear Nucleus 7 Left",
    "battery_level": 72,
    "is_connected": true,
    "current_program": "Home / Quiet",
    "last_seen_location": "home",
    "updated_at": "2026-04-04T10:15:30.123Z"
  }
}
```

### Update Device Status

```bash
curl -X PUT http://localhost:3001/api/profile/device \
  -H "Content-Type: application/json" \
  -d '{
    "batteryLevel": 45,
    "isConnected": true,
    "currentProgram": "Restaurant / Crowd",
    "lastSeenLocation": "restaurant"
  }'
```

### Get Profile Summary

```bash
curl http://localhost:3001/api/profile/summary
```

Response:
```json
{
  "success": true,
  "data": {
    "profile": {
      "id": "default-user",
      "name": "Maruthi",
      "device_brand": "Cochlear",
      "device_model": "Nucleus 7",
      "hearing_loss_level": "Profound"
    },
    "device": {
      "battery_level": 72,
      "is_connected": true,
      "current_program": "Home / Quiet"
    },
    "statistics": {
      "totalAlerts": 42,
      "feedbackProvided": 10,
      "activeContextRules": 4
    }
  }
}
```

## Transcription API

### Get Sessions

```bash
curl http://localhost:3001/api/transcribe/sessions
```

Active sessions only:
```bash
curl 'http://localhost:3001/api/transcribe/sessions?status=active'
```

Ended sessions only:
```bash
curl 'http://localhost:3001/api/transcribe/sessions?status=ended'
```

### Start Session

```bash
curl -X POST http://localhost:3001/api/transcribe/sessions \
  -H "Content-Type: application/json" \
  -d '{"speakerCount": 2}'
```

Response:
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440006",
    "user_id": "default-user",
    "started_at": "2026-04-04T10:15:30.123Z",
    "ended_at": null,
    "speaker_count": 2
  },
  "message": "Transcription session started"
}
```

### Add Transcription Line

```bash
curl -X POST http://localhost:3001/api/transcribe/sessions/550e8400-e29b-41d4-a716-446655440006/lines \
  -H "Content-Type: application/json" \
  -d '{
    "speakerLabel": "You",
    "text": "Hello, how are you today?",
    "timestamp": "00:00:05"
  }'
```

Response:
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440007",
    "session_id": "550e8400-e29b-41d4-a716-446655440006",
    "speaker_label": "You",
    "text": "Hello, how are you today?",
    "timestamp": "00:00:05",
    "created_at": "2026-04-04T10:15:30.123Z"
  },
  "message": "Transcription line added"
}
```

### Get Transcription Lines

```bash
curl 'http://localhost:3001/api/transcribe/sessions/550e8400-e29b-41d4-a716-446655440006/lines?limit=50'
```

### End Session

```bash
curl -X PUT http://localhost:3001/api/transcribe/sessions/550e8400-e29b-41d4-a716-446655440006 \
  -H "Content-Type: application/json" \
  -d '{"speakerCount": 2}'
```

### Export Session

As JSON:
```bash
curl 'http://localhost:3001/api/transcribe/sessions/550e8400-e29b-41d4-a716-446655440006/export?format=json'
```

As plain text:
```bash
curl 'http://localhost:3001/api/transcribe/sessions/550e8400-e29b-41d4-a716-446655440006/export?format=txt'
```

## Error Responses

### Validation Error

```bash
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{"confidence": 0.85}'
```

Response:
```json
{
  "success": false,
  "error": "soundType is required",
  "status": 400,
  "code": "VALIDATION_ERROR"
}
```

### Invalid Sound Type

```bash
curl -X POST http://localhost:3001/api/alerts \
  -H "Content-Type: application/json" \
  -d '{"soundType": "invalid_sound", "confidence": 0.85}'
```

Response:
```json
{
  "success": false,
  "error": "Invalid sound type: invalid_sound",
  "status": 400
}
```

### Not Found

```bash
curl http://localhost:3001/api/alerts/nonexistent-id
```

Response:
```json
{
  "success": false,
  "error": "Alert not found",
  "status": 404
}
```

### Server Error

```json
{
  "success": false,
  "error": "Failed to fetch alerts",
  "status": 500
}
```

## Testing Tips

1. Use `jq` for pretty JSON: `curl ... | jq`
2. Save response: `curl ... > response.json`
3. Use `-v` flag for verbose output: `curl -v ...`
4. Check status code: `curl -w "%{http_code}" ...`
5. Use `-d @file.json` to send JSON from file

Example with jq:
```bash
curl http://localhost:3001/api/profile | jq '.data.name'
```
