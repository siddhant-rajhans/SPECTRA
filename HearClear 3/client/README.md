# HearClear Frontend

A context-aware hearing aid companion app built with React 18 + Vite.

## Project Structure

```
client/
├── src/
│   ├── components/
│   │   ├── NotificationOverlay.jsx    # Alert notification popup
│   │   ├── PhoneFrame.jsx              # Phone frame wrapper
│   │   ├── StatusBar.jsx               # Top status bar with time/icons
│   │   ├── TabBar.jsx                  # Bottom navigation (6 tabs)
│   │   └── screens/
│   │       ├── AlertsScreen.jsx        # Monitor sounds & context rules
│   │       ├── EnvironmentScreen.jsx   # Hearing programs & fine tuning
│   │       ├── HomeScreen.jsx          # Device status & quick actions
│   │       ├── IMLScreen.jsx           # Interactive ML feedback
│   │       ├── ProfileScreen.jsx       # User profile & settings
│   │       └── TranscribeScreen.jsx    # Transcription interface
│   ├── context/
│   │   └── AppContext.jsx              # Global state (activeTab, notification)
│   ├── hooks/
│   │   └── useWebSocket.js             # WebSocket connection with reconnect
│   ├── services/
│   │   └── api.js                      # API client (fetch-based)
│   ├── styles/
│   │   └── app.css                     # Complete styling with dark theme
│   ├── App.jsx                         # Main app component
│   └── main.jsx                        # React entry point
├── index.html                          # HTML template
├── package.json                        # Dependencies & scripts
└── vite.config.js                      # Vite configuration

```

## Setup & Installation

1. **Install dependencies:**
   ```bash
   cd client
   npm install
   ```

2. **Start development server:**
   ```bash
   npm run dev
   ```
   The app will run on `http://localhost:5173`

3. **Build for production:**
   ```bash
   npm run build
   ```

4. **Preview production build:**
   ```bash
   npm run preview
   ```

## Features

### 6 Main Screens

1. **Home** - Device status, context info, quick actions, pipeline visualization
2. **Alerts** - Monitor sound types, context rules, alert history
3. **Transcribe** - Real-time transcription with speaker labels
4. **Train AI** - Interactive ML feedback to improve sound classification (SPECTRA)
5. **Settings** (Environment) - Hearing programs, noise gauge, fine-tuning sliders
6. **Profile** - User info, device settings, model stats

### Key Technologies

- **React 18** - Component-based UI with hooks
- **Vite** - Fast build tool with HMR
- **Plain CSS** - Dark theme with CSS variables, animations, responsive design
- **Fetch API** - REST API calls to backend
- **WebSocket** - Real-time alert notifications

### API Integration

- Base URL: `/api` (proxied to `http://localhost:3001`)
- WebSocket: `/ws` (proxied to `ws://localhost:3001`)

**Available Endpoints:**
- Alerts: `GET/POST /api/alerts`, `/api/alerts/{id}`, `/api/alerts/simulate`
- Context: `GET/PATCH /api/context-rules`, `/api/monitored-sounds`
- IML: `GET /api/iml/pending`, `POST /api/iml/feedback`
- Programs: `GET /api/programs`, `POST /api/programs/{id}/select`
- Transcription: `POST /api/transcription/start`, `GET /api/transcription/{id}/lines`
- Profile: `GET /api/profile`, `GET /api/device/status`

## Architecture

### State Management

Global state via React Context:
- `activeTab` - Current screen index (0-5)
- `notification` - Alert popup data
- `deviceStatus` - Device connection & battery
- `showNotification()` / `hideNotification()` - Notification control

### WebSocket Events

Expected incoming messages:
```json
{
  "type": "alert",
  "soundType": "doorbell",
  "title": "Doorbell Detected",
  "description": "Someone is at your door",
  "contextReasoning": "You are at home. Normal context to alert.",
  "icon": "🔔"
}
```

### Styling

- **Dark theme** with accent colors (purple primary, cyan accent)
- **CSS Grid/Flexbox** layouts
- **Animations** for notifications, waveforms, transitions
- **Phone-like frame** (390x844px) with notch, status bar, tab bar
- **Responsive design** for smaller screens

## Development Notes

- No TypeScript - plain JSX only
- Error handling with try-catch, loading states, graceful fallbacks
- Components are self-contained with local state + API calls
- Debounced slider updates to reduce API calls
- Automatic WebSocket reconnection with exponential backoff
- All CSS variables and selectors match the prototype exactly

## Browser Support

- Modern browsers with ES2020+ support
- Chrome, Firefox, Safari, Edge (latest)
- Mobile-optimized viewport
