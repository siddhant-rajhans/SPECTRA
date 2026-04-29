# HearClear Frontend Architecture

## Overview

HearClear is a React 18 + Vite frontend for a context-aware hearing aid companion app. The application provides 6 main screens for managing smart alerts, transcription, and interactive machine learning feedback.

## Tech Stack

- **React 18.2.0** - Component framework with hooks
- **Vite 5.0.0** - Build tool and dev server
- **Plain CSS** - 1400+ lines of dark theme styling
- **Fetch API** - REST API communication
- **WebSocket** - Real-time alert notifications

## Project Structure

```
client/
├── src/
│   ├── App.jsx                     # Main app entry with context provider
│   ├── main.jsx                    # React DOM mount point
│   ├── components/
│   │   ├── PhoneFrame.jsx          # Phone viewport wrapper
│   │   ├── StatusBar.jsx           # System time & battery status
│   │   ├── TabBar.jsx              # 6-tab bottom navigation
│   │   ├── NotificationOverlay.jsx # Alert popup (modal)
│   │   └── screens/
│   │       ├── HomeScreen.jsx      # [0] Overview, quick actions
│   │       ├── AlertsScreen.jsx    # [1] Sound monitoring, rules
│   │       ├── TranscribeScreen.jsx # [2] Real-time transcription
│   │       ├── IMLScreen.jsx       # [3] ML feedback training
│   │       ├── EnvironmentScreen.jsx # [4] Hearing programs, sliders
│   │       └── ProfileScreen.jsx   # [5] User profile, settings
│   ├── context/
│   │   └── AppContext.jsx          # Global state (tab, notification)
│   ├── hooks/
│   │   └── useWebSocket.js         # WebSocket client with reconnect
│   ├── services/
│   │   └── api.js                  # Fetch-based API client
│   └── styles/
│       └── app.css                 # Complete theme + components
├── index.html                      # HTML template
├── vite.config.js                  # Vite configuration
└── package.json                    # Dependencies & scripts
```

## Component Architecture

### App.jsx (Root)
```
<AppContextProvider>
  <AppContent>
    <PhoneFrame>
      <StatusBar />
      <[CurrentScreen] />  {/* Based on activeTab (0-5) */}
      <TabBar />
      <NotificationOverlay />
    </PhoneFrame>
  </AppContent>
</AppContextProvider>
```

### State Management

**AppContext** provides:
- `activeTab` (number: 0-5) - Current screen index
- `setActiveTab` (function) - Change screen
- `notification` (object|null) - Alert popup data
- `showNotification` (function) - Display alert
- `hideNotification` (function) - Hide alert
- `deviceStatus` (object|null) - Device info
- `setDeviceStatus` (function) - Update device

**Local Component State** for:
- Data fetching (loading, error, data)
- UI state (expanded, selected, input values)
- Form state (sliders, toggles)

### 6 Screens

| Tab | Screen | Purpose |
|-----|--------|---------|
| 0 | HomeScreen | Device status, context, quick actions, pipeline |
| 1 | AlertsScreen | Monitor sounds, context rules, alert history |
| 2 | TranscribeScreen | Real-time transcription with speaker labels |
| 3 | IMLScreen | Interactive ML training feedback (SPECTRA) |
| 4 | EnvironmentScreen | Hearing programs, noise gauge, fine tuning |
| 5 | ProfileScreen | User info, settings, ML stats |

## API Integration

### Base Configuration
- **API Base URL:** `/api` (proxied to `http://localhost:3001`)
- **WebSocket URL:** `/ws` (proxied to `ws://localhost:3001`)
- **Timeout:** No explicit timeout (relies on fetch default)

### API Functions (30+ endpoints)

**Alerts & Simulation**
- `fetchAlerts()` → GET `/api/alerts`
- `fetchAlert(id)` → GET `/api/alerts/{id}`
- `simulateAlert(type)` → POST `/api/alerts/simulate`

**Context Rules**
- `fetchContextRules()` → GET `/api/context-rules`
- `toggleContextRule(id, isActive)` → PATCH `/api/context-rules/{id}`

**Monitored Sounds**
- `fetchMonitoredSounds()` → GET `/api/monitored-sounds`
- `toggleMonitoredSound(type, isEnabled)` → PATCH `/api/monitored-sounds/{type}`

**Interactive Machine Learning**
- `fetchIMLPending()` → GET `/api/iml/pending`
- `fetchIMLReviewed()` → GET `/api/iml/reviewed`
- `fetchIMLStats()` → GET `/api/iml/stats`
- `submitIMLFeedback(alertId, isCorrect, correctedClassification)` → POST `/api/iml/feedback`

**Hearing Programs**
- `fetchPrograms()` → GET `/api/programs`
- `selectProgram(id)` → POST `/api/programs/{id}/select`
- `updateProgramSettings(id, settings)` → PATCH `/api/programs/{id}/settings`
- `fetchCurrentEnvironment()` → GET `/api/environment`

**Profile & Device**
- `fetchProfile()` → GET `/api/profile`
- `updateProfile(data)` → PATCH `/api/profile`
- `fetchDeviceStatus()` → GET `/api/device/status`

**Transcription**
- `fetchTranscriptionSessions()` → GET `/api/transcription/sessions`
- `startTranscription()` → POST `/api/transcription/start`
- `endTranscription(id)` → POST `/api/transcription/{id}/end`
- `fetchTranscriptionLines(sessionId)` → GET `/api/transcription/{sessionId}/lines`

### Error Handling

All API functions:
1. Wrap calls in try-catch
2. Check response.ok
3. Parse JSON
4. Log errors to console
5. Throw errors for component handling

Components:
1. Catch errors in useEffect
2. Set error state
3. Display user-friendly message
4. Provide loading state

### WebSocket Integration

**useWebSocket hook:**
- Auto-connects to `/ws`
- Reconnects with exponential backoff (max 5 attempts)
- Parses JSON messages
- Provides: `lastMessage`, `sendMessage`, `isConnected`

**Expected Message Format:**
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

**Usage in App.jsx:**
```jsx
const { lastMessage } = useWebSocket('/ws')

useEffect(() => {
  if (lastMessage?.type === 'alert') {
    showNotification({...})
  }
}, [lastMessage])
```

## Styling System

### CSS Architecture

1. **CSS Variables** - Color tokens, shadows
2. **Global Styles** - Font, baseline resets
3. **Layout** - Phone frame, status bar, screens, tab bar
4. **Components** - Cards, buttons, toggles, sliders, animations
5. **Responsive** - Mobile-first with media queries

### Color Palette

```css
--primary: #6C5CE7         /* Purple - main brand */
--primary-light: #A29BFE   /* Light purple */
--accent: #00CEC9          /* Cyan - highlights */
--danger: #FF6B6B          /* Red - alerts */
--success: #00B894         /* Green - positive */
--warning: #FDCB6E         /* Yellow - caution */
--bg: #0F0F1A              /* Dark background */
--bg-card: #1A1A2E         /* Card background */
--text-primary: #FFFFFF    /* Main text */
--text-secondary: #B8B8D4  /* Secondary text */
--border: #2D2D4A          /* Borders */
--shadow: 0 8px 32px ...   /* Drop shadow */
```

### Phone Frame

- **Dimensions:** 390px × 844px (iPhone 12 Pro size)
- **Border:** 12px rounded (40px radius)
- **Background:** Dark with gradient overlay
- **Notch:** 120px × 24px (top center)
- **Layout:** Flex column with fixed header/footer

### Key CSS Classes

| Class | Purpose |
|-------|---------|
| `.phone-frame` | Phone viewport container |
| `.screen` | Content area (scrollable) |
| `.card` | Content container |
| `.section` | Grouping container |
| `.btn-primary` | Primary action |
| `.btn-secondary` | Secondary action |
| `.toggle-switch` | Checkbox input |
| `.slider-input` | Range input |
| `.status-badge` | Status label |
| `.notification-overlay` | Modal backdrop |
| `.notification-popup` | Alert box |

### Animations

- `fadeIn` (300ms) - Overlay entrance
- `slideUp` (300ms) - Popup entrance
- `pulse` (2s infinite) - Notification icon
- `waveform` (600ms infinite) - Transcription bars
- `fadeInUp` (300ms) - Transcript lines

## Data Flow

### Page Load
```
App mounts
  ↓
Load initial data:
  - fetchDeviceStatus()
  - fetchProfile()
  ↓
setDeviceStatus in context
  ↓
Connect WebSocket
```

### Screen Interaction
```
User clicks tab
  ↓
setActiveTab() in context
  ↓
activeTab changes
  ↓
[CurrentScreen] re-renders
  ↓
Component useEffect triggers
  ↓
Fetch data from API
  ↓
Update local state
  ↓
Re-render with data
```

### Alert Notification
```
WebSocket receives alert message
  ↓
lastMessage in useWebSocket changes
  ↓
App.jsx useEffect triggers
  ↓
showNotification() called
  ↓
notification in context updates
  ↓
NotificationOverlay re-renders
  ↓
User dismisses or navigates
  ↓
hideNotification() clears state
```

## Development Workflow

### Setup
```bash
npm install
npm run dev
```

### Development
- Vite HMR (hot reload on file changes)
- All components reload immediately
- API calls use fetch (check network tab)
- WebSocket connects on page load

### Production Build
```bash
npm run build        # Creates dist/ folder
npm run preview      # Test build locally
```

## Performance Considerations

1. **Code Splitting:** Each screen is a separate component (lazy-loaded possible)
2. **State Management:** Context only for truly global state
3. **Rendering:** Components use proper dependency arrays
4. **API Calls:** Debounced slider updates, no infinite loops
5. **WebSocket:** Auto-cleanup on unmount, reconnection logic
6. **CSS:** Minimal (plain CSS), no runtime overhead

## Browser Compatibility

- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- Mobile Safari (iOS 14+)

**Required Features:**
- ES2020+ JavaScript
- CSS Grid/Flexbox
- WebSocket API
- Fetch API
- Local Storage (optional, not currently used)

## Testing Strategy

### Manual Testing
1. Each screen independently
2. Tab switching
3. API calls (check Network tab)
4. WebSocket connection
5. Notification display
6. Form interactions (toggles, sliders)
7. Error states (disconnect API)

### Potential Automated Tests
- Component rendering
- API function calls
- Context state updates
- WebSocket message parsing

## Future Enhancements

1. **TypeScript** - Type safety for components/API
2. **State Management** - Redux/Zustand for complex state
3. **Error Boundaries** - Graceful error handling
4. **Analytics** - Track user interactions
5. **Offline Mode** - Service Worker + local storage
6. **Dark/Light Mode** - CSS variable switching
7. **Internationalization** - Multi-language support
8. **Testing** - Jest + React Testing Library
9. **Storybook** - Component documentation
10. **Performance** - React Suspense, code splitting
