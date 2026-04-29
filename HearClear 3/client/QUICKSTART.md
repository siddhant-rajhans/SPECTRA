# HearClear Frontend - Quick Start Guide

## Prerequisites

- Node.js 16+ and npm installed
- Backend API running on `http://localhost:3001`

## Installation & Running

### 1. Install Dependencies
```bash
cd client
npm install
```

### 2. Start Development Server
```bash
npm run dev
```

The app will start on `http://localhost:5173` with hot module reload enabled.

### 3. Open in Browser
Navigate to `http://localhost:5173` and you'll see the HearClear app in a phone-sized frame.

## First Steps

### Enable Backend
Make sure your backend is running and listening on `http://localhost:3001`:
- `GET /api/device/status` - Device info
- `GET /api/profile` - User profile
- `WS /ws` - WebSocket for alerts

### Explore the Screens

1. **Home** (🏠) - Overview of device status and recent alerts
   - Shows battery level, location, current time
   - Quick action buttons
   - Visual pipeline (Audio → Classify → Context → Filter → Alert)

2. **Alerts** (🔔) - Manage sound detection
   - Toggle monitoring for: doorbell, fire alarm, car horn, name, timer, baby
   - View context rules (Meeting, Sleep, Outdoors, Restaurant)
   - See alert history with confidence scores

3. **Transcribe** (📝) - Real-time speech-to-text
   - Click "Start" to begin recording
   - Transcript appears with speaker labels
   - Download or copy transcript
   - Waveform animates while listening

4. **Train AI** (🤖) - Interactive Machine Learning
   - Review unconfirmed sound classifications
   - Confirm or correct classifications
   - See your accuracy stats
   - This trains the SPECTRA model with your feedback

5. **Settings** (⚙️) - Audio environment control
   - View noise level gauge
   - Select hearing program (Home, Restaurant, Music, Outdoors, Sleep)
   - Fine-tune with 3 sliders:
     * Speech Enhancement (0-100%)
     * Background Noise Reduction (0-100%)
     * Forward Focus (0-100%)

6. **Profile** (👤) - User and device settings
   - View user info and avatar
   - Device settings (battery, Bluetooth, Find My)
   - Smart alerts (smartwatch, flash notifications, calendar)
   - ML model stats

## Testing Features

### Simulate an Alert
1. Go to **Home** screen
2. Click "Test Alert" button
3. A doorbell notification will appear
4. Click "Was this right?" to go to the IML screen

### Test Monitored Sounds
1. Go to **Alerts** screen
2. Toggle sound types on/off (except fire alarm)
3. See toggles update in real-time

### Test Transcription
1. Go to **Transcribe** screen
2. Click "▶️ Start" button
3. Speak or wait for mock data
4. Transcript lines appear with speaker labels
5. Click "⏹️ Stop" to end

### Test ML Training
1. Go to **Train AI** screen
2. See pending sound classifications
3. Click "Yes, correct" to confirm
4. Click "No, it was..." to pick the correct sound
5. Stats update after feedback

### Test Settings
1. Go to **Settings** screen
2. Select different hearing programs
3. Drag sliders to adjust audio settings
4. Changes save to API automatically (debounced)

## API Integration

### Expected API Responses

**GET /api/device/status**
```json
{
  "id": "hearing-aid-001",
  "name": "ReSound Ote Plus",
  "connected": true,
  "battery": 85
}
```

**GET /api/profile**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "modelVersion": "SPECTRA-v2"
}
```

**GET /api/alerts**
```json
[
  {
    "id": "alert-1",
    "type": "doorbell",
    "timestamp": "2024-01-15T10:30:00Z",
    "confidence": 0.95,
    "delivered": true,
    "contextReasoning": "You are at home. Normal context to alert.",
    "location": "Office"
  }
]
```

**WebSocket Messages**
```json
{
  "type": "alert",
  "soundType": "fire-alarm",
  "title": "Fire Alarm Detected",
  "description": "High-frequency alarm detected",
  "contextReasoning": "Fire alarm override - critical alert always delivered",
  "icon": "🚨"
}
```

See `/client/src/services/api.js` for all 30+ endpoint functions.

## Building for Production

### Create Optimized Build
```bash
npm run build
```

Output in `dist/` directory:
- Minified JavaScript
- Optimized CSS
- Compressed assets

### Preview Build
```bash
npm run preview
```

Test the production build locally on `http://localhost:4173`

## Troubleshooting

### API Not Connecting
- Check backend is running on `http://localhost:3001`
- Check browser Network tab for failed requests
- Look for CORS errors (backend may need CORS headers)

### WebSocket Not Connecting
- Check backend WebSocket is on `/ws`
- Check browser console for connection errors
- Reconnection happens automatically (up to 5 attempts)

### Styles Not Loading
- Ensure CSS is imported in `src/main.jsx`
- Check browser DevTools for CSS errors
- Hard refresh (Ctrl+Shift+R) to clear cache

### Hot Reload Not Working
- Vite is watching for changes in `src/` directory
- Save files to trigger reload
- Check terminal for any build errors

## Project Structure Quick Reference

```
src/
├── App.jsx                # Main component
├── main.jsx               # Entry point
├── context/AppContext.jsx # Global state
├── hooks/useWebSocket.js  # WebSocket hook
├── services/api.js        # API client
├── components/
│   ├── StatusBar.jsx
│   ├── TabBar.jsx
│   ├── PhoneFrame.jsx
│   ├── NotificationOverlay.jsx
│   └── screens/           # 6 screens
└── styles/app.css         # All styling (1400+ lines)
```

## Key Files to Modify

### Add a New Screen
1. Create `src/components/screens/MyScreen.jsx`
2. Import in `src/App.jsx`
3. Add to screens array
4. Add tab in `src/components/TabBar.jsx`
5. Add styles in `src/styles/app.css`

### Customize Colors
Edit CSS variables in `src/styles/app.css`:
```css
:root {
  --primary: #6C5CE7;        /* Your color */
  --accent: #00CEC9;
  /* ... */
}
```

### Modify API Base URL
Edit `src/services/api.js`:
```js
const API_BASE = '/api'  // Change if needed
```

## Support & Resources

- React Docs: https://react.dev
- Vite Docs: https://vitejs.dev
- MDN CSS Guide: https://developer.mozilla.org/en-US/docs/Web/CSS
- WebSocket API: https://developer.mozilla.org/en-US/docs/Web/API/WebSocket

## Commands Summary

| Command | Purpose |
|---------|---------|
| `npm install` | Install dependencies |
| `npm run dev` | Start dev server (HMR) |
| `npm run build` | Create production build |
| `npm run preview` | Preview production build |

## Next Steps

1. ✓ Frontend is ready
2. → Run backend API on localhost:3001
3. → Configure API endpoints
4. → Test each screen
5. → Customize styling as needed
6. → Deploy to production

Good luck with HearClear!
