# HearClear Flutter App — Backend & ML Integration Guide

This guide documents how to connect the Flutter app to the existing Node.js backend
and integrate ML models for sound classification.

## Current State

The app currently runs with **mock data** defined in `lib/services/mock_data.dart`.
All data operations go through `lib/providers/app_provider.dart` which can be
refactored to call real API services.

---

## Backend API Reference

The backend runs on `http://localhost:3001` with WebSocket at `ws://localhost:3001/ws`.

### Authentication
```
POST /api/auth/login     { email, password }          → { success, user }
POST /api/auth/signup    { name, email, password, … } → { success, user }
```

### Alerts
```
GET    /api/alerts                   → List of alerts (paginated)
GET    /api/alerts/:id               → Single alert
POST   /api/alerts                   → Create alert with context evaluation
GET    /api/alerts/context-rules     → User context rules
PUT    /api/alerts/context-rules/:id → Toggle context rule
POST   /api/alerts/simulate          → Simulate sound detection
```

### Interactive ML (SPECTRA)
```
GET    /api/iml/pending   → Alerts awaiting feedback
GET    /api/iml/reviewed  → Reviewed feedback
GET    /api/iml/stats     → Model accuracy statistics
GET    /api/iml/analysis  → Detailed IML insights
POST   /api/iml/feedback  → Submit feedback { alertId, isCorrect, correctedClassification }
POST   /api/iml/train     → Trigger model retraining
```

### Environment & Hearing Programs
```
GET    /api/environment/programs     → List hearing programs
POST   /api/environment/programs     → Create custom program
PUT    /api/environment/programs/:id → Update program settings
GET    /api/environment/current      → Current environment reading
PUT    /api/environment/settings     → Update fine-tuning settings
```

### Profile & Device
```
GET    /api/profile          → User profile
PUT    /api/profile          → Update profile
GET    /api/profile/device   → Device status
PUT    /api/profile/device   → Update device status
GET    /api/profile/summary  → Complete profile summary
```

### Transcription
```
GET    /api/transcribe/sessions           → List sessions
POST   /api/transcribe/sessions           → Start new session
PUT    /api/transcribe/sessions/:id       → End session
GET    /api/transcribe/sessions/:id/lines → Get transcription lines
POST   /api/transcribe/sessions/:id/lines → Add transcription line
GET    /api/transcribe/sessions/:id/export → Export session
```

---

## How to Replace Mock Services

### Step 1: Add HTTP package

Already included in `pubspec.yaml` as a transitive dependency via `google_fonts`.
For explicit usage:

```yaml
dependencies:
  http: ^1.6.0
```

### Step 2: Create an API client

```dart
// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // TODO: Update with your actual backend URL
  static const String baseUrl = 'http://localhost:3001/api';
  static String? _userId;

  static void setUserId(String id) => _userId = id;

  static Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return jsonDecode(response.body);
  }
}
```

### Step 3: Replace provider methods

Example — replacing `alerts` in `AppProvider`:

```dart
// Before (mock):
final List<SoundAlert> _alerts = List.from(MockData.alerts);

// After (API):
List<SoundAlert> _alerts = [];

Future<void> loadAlerts() async {
  final response = await ApiClient.get('/alerts');
  _alerts = (response['data'] as List)
      .map((json) => SoundAlert.fromJson(json))
      .toList();
  notifyListeners();
}
```

---

## WebSocket Integration

For real-time alerts, connect to the WebSocket server:

```dart
// lib/services/websocket_service.dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static const String wsUrl = 'ws://localhost:3001/ws';
  WebSocketChannel? _channel;

  void connect({required Function(Map<String, dynamic>) onAlert}) {
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel!.stream.listen((data) {
      final message = jsonDecode(data);
      if (message['type'] == 'alert') {
        onAlert(message['data']);
      }
    });

    // Subscribe to alerts
    _channel!.sink.add(jsonEncode({
      'type': 'subscribe',
      'channel': 'alerts',
    }));
  }

  void dispose() {
    _channel?.sink.close();
  }
}
```

Add `web_socket_channel` to dependencies:
```yaml
dependencies:
  web_socket_channel: ^3.0.0
```

---

## ML Model Integration Points

### 1. Sound Classification (On-Device)

The app is designed to integrate TensorFlow Lite models for real-time sound classification.

**Where to integrate:**
- Create `lib/services/sound_classifier.dart`
- Use `tflite_flutter` package for on-device inference
- The model should output one of the 15 supported sound types
- Feed the classification results into the alert system

```yaml
dependencies:
  tflite_flutter: ^0.11.0
```

```dart
// lib/services/sound_classifier.dart
class SoundClassifier {
  // TODO: Load TFLite model
  // TODO: Process audio input from microphone
  // TODO: Run inference and return classification

  Future<SoundClassification> classify(List<double> audioFeatures) async {
    // 1. Preprocess audio (MFCC, mel-spectrogram)
    // 2. Run TFLite inference
    // 3. Return top prediction with confidence
    throw UnimplementedError('ML model not yet integrated');
  }
}
```

### 2. Microphone Input

For capturing audio:

```yaml
dependencies:
  record: ^5.1.2
```

### 3. Speech-to-Text (Transcription)

For the transcription screen:

```yaml
dependencies:
  speech_to_text: ^7.0.0
```

### 4. IML Feedback Loop

The existing IML screen sends feedback to `POST /api/iml/feedback`.
On the backend, this data is used to retrain the model.
The Flutter app's `submitFeedback()` method in `AppProvider` should be
connected to this endpoint.

---

## Environment Setup

### Backend `.env`
```
NODE_ENV=development
PORT=3001
DATABASE_PATH=./data/hearclear.db
LOG_LEVEL=info
CORS_ORIGIN=http://localhost:3000
```

### Flutter Configuration

For Android/iOS to connect to localhost:
- **Android Emulator**: Use `10.0.2.2:3001` instead of `localhost`
- **iOS Simulator**: `localhost:3001` works directly
- **Physical device**: Use your machine's local IP (e.g., `192.168.1.x:3001`)

---

## File Reference

| File | Purpose |
|------|---------|
| `lib/providers/app_provider.dart` | Central state — replace mock calls with API calls |
| `lib/services/mock_data.dart` | All mock data — reference for data shapes |
| `lib/models/*.dart` | Data models — add `.fromJson()` / `.toJson()` for API |
| `lib/screens/*.dart` | UI screens — no changes needed for backend integration |
| `lib/widgets/*.dart` | Reusable widgets — no changes needed |

---

## Recommended Integration Order

1. **Authentication** — Replace mock login with real `/api/auth` endpoints
2. **Profile & Device** — Fetch real user data and device status
3. **Alerts** — Connect to `/api/alerts` + WebSocket for real-time
4. **IML/SPECTRA** — Wire feedback to `/api/iml/feedback`
5. **Environment** — Fetch programs from `/api/environment/programs`
6. **Transcription** — Integrate `speech_to_text` + `/api/transcribe`
7. **Sound Classification** — Add TFLite model for on-device inference
