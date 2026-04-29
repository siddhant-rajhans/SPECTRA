const API_BASE = '/api'

// Store current user ID for API calls
let currentUserId = 'default-user'

export function setApiUserId(userId) {
  currentUserId = userId
}

export function getApiUserId() {
  return currentUserId
}

function userParam(separator = '?') {
  return `${separator}userId=${currentUserId}`
}

// ──────── Auth ────────
export async function loginUser(email, password) {
  const response = await fetch(`${API_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  })
  const json = await response.json()
  if (!response.ok) throw new Error(json.error || 'Login failed')
  if (json.user) setApiUserId(json.user.id)
  return json
}

export async function signupUser(data) {
  const response = await fetch(`${API_BASE}/auth/signup`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  })
  const json = await response.json()
  if (!response.ok) throw new Error(json.error || 'Signup failed')
  if (json.user) setApiUserId(json.user.id)
  return json
}

// ──────── Implants ────────
export async function fetchImplantProviders() {
  const response = await fetch(`${API_BASE}/implants/providers`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch providers')
  return json.providers || json.data || []
}

function transformImplant(imp) {
  return {
    id: imp.id,
    providerId: imp.provider || imp.providerId,
    providerName: imp.provider ? imp.provider.charAt(0).toUpperCase() + imp.provider.slice(1) : imp.providerName,
    displayName: imp.display_name || imp.displayName || imp.provider,
    deviceModel: imp.device_model || imp.deviceModel,
    battery: imp.battery_level ?? imp.battery ?? 0,
    firmwareVersion: imp.firmware_version || imp.firmwareVersion,
    isConnected: imp.is_connected !== undefined ? (imp.is_connected === 1 || imp.is_connected === true) : true,
    lastSynced: imp.last_synced_at || imp.lastSynced,
    features: typeof imp.features === 'string' ? JSON.parse(imp.features) : (imp.features || [])
  }
}

export async function fetchConnectedImplants() {
  const response = await fetch(`${API_BASE}/implants/connected${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch connected implants')
  const raw = json.implants || json.data || []
  return Array.isArray(raw) ? raw.map(transformImplant) : []
}

export async function connectImplant(data) {
  const response = await fetch(`${API_BASE}/implants/connect${userParam()}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      provider: data.providerId,
      displayName: data.displayName,
      deviceModel: data.deviceModel
    })
  })
  const json = await response.json()
  if (!response.ok) throw new Error(json.error || 'Failed to connect implant')
  const raw = json.implant || json.data || json
  return transformImplant(raw)
}

export async function disconnectImplant(id) {
  const response = await fetch(`${API_BASE}/implants/${id}/disconnect${userParam()}`, {
    method: 'DELETE'
  })
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to disconnect')
  return json
}

export async function syncImplant(id) {
  const response = await fetch(`${API_BASE}/implants/${id}/sync${userParam()}`, {
    method: 'POST'
  })
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to sync')
  const raw = json.implant || json.data || json
  return transformImplant(raw)
}

export async function fetchImplantStatus(id) {
  const response = await fetch(`${API_BASE}/implants/${id}/status${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch status')
  const raw = json.status || json.data || json
  return transformImplant(raw)
}

// ──────── Alerts ────────
// Transform backend alert format to frontend format
function transformAlert(alert) {
  return {
    id: alert.id,
    type: alert.sound_type || alert.type,
    confidence: alert.confidence,
    delivered: alert.was_delivered === 1 || alert.was_delivered === true,
    contextReasoning: alert.delivery_reason || alert.contextReasoning,
    location: alert.context_location || alert.location,
    timeOfDay: alert.context_time_of_day || alert.timeOfDay,
    calendar: alert.context_calendar || alert.calendar,
    timestamp: alert.created_at || alert.timestamp
  }
}

export async function fetchAlerts() {
  const response = await fetch(`${API_BASE}/alerts${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch alerts')
  const raw = json.data || json
  return Array.isArray(raw) ? raw.map(transformAlert) : []
}

export async function fetchAlert(id) {
  const response = await fetch(`${API_BASE}/alerts/${id}${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch alert')
  return transformAlert(json.data || json)
}

export async function simulateAlert(type) {
  const response = await fetch(`${API_BASE}/alerts/simulate${userParam()}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ type })
  })
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to simulate alert')
  return json.data || json
}

// ──────── Context Rules ────────
// Transform backend context rule to frontend format
function transformContextRule(rule) {
  return {
    id: rule.id,
    title: rule.name || rule.title,
    description: rule.description,
    isActive: rule.is_active === 1 || rule.is_active === true || rule.isActive,
    condition: rule.condition_type || rule.condition,
    action: rule.action_type || rule.action
  }
}

export async function fetchContextRules() {
  const response = await fetch(`${API_BASE}/alerts/context-rules${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch context rules')
  const raw = json.data || json
  return Array.isArray(raw) ? raw.map(transformContextRule) : []
}

export async function toggleContextRule(id, isActive) {
  const response = await fetch(`${API_BASE}/alerts/context-rules/${id}${userParam()}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ isActive })
  })
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to toggle context rule')
  return json.data || json
}

// ──────── Monitored Sounds (client-side, no backend endpoint) ────────
const defaultMonitoredSounds = [
  { type: 'doorbell', label: 'Doorbell', isEnabled: true },
  { type: 'fire-alarm', label: 'Fire / Smoke Alarm', isEnabled: true },
  { type: 'car-horn', label: 'Car Horn', isEnabled: true },
  { type: 'name', label: 'Name Called', isEnabled: true },
  { type: 'timer', label: 'Timer / Alarm', isEnabled: true },
  { type: 'baby', label: 'Baby Crying', isEnabled: true }
]

let monitoredSoundsState = [...defaultMonitoredSounds]

export async function fetchMonitoredSounds() {
  return monitoredSoundsState
}

export async function toggleMonitoredSound(soundType, isEnabled) {
  monitoredSoundsState = monitoredSoundsState.map(s =>
    s.type === soundType ? { ...s, isEnabled } : s
  )
  return { success: true }
}

// ──────── IML (Interactive Machine Learning) ────────
function transformIMLItem(item) {
  return {
    id: item.id,
    type: item.sound_type || item.original_classification || item.type,
    confidence: item.confidence,
    delivered: item.was_delivered === 1 || item.was_delivered === true,
    contextReasoning: item.delivery_reason || item.contextReasoning,
    location: item.context_location || item.location,
    timeOfDay: item.context_time_of_day || item.timeOfDay,
    timestamp: item.created_at || item.alert_created_at || item.timestamp,
    isCorrect: item.is_correct === 1 || item.is_correct === true || item.isCorrect,
    correctedClassification: item.corrected_classification || item.correctedClassification,
    feedbackCreatedAt: item.feedback_created_at || item.feedbackCreatedAt
  }
}

export async function fetchIMLPending() {
  const response = await fetch(`${API_BASE}/iml/pending${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch pending IML')
  const raw = json.data || json
  return Array.isArray(raw) ? raw.map(transformIMLItem) : []
}

export async function fetchIMLReviewed() {
  const response = await fetch(`${API_BASE}/iml/reviewed${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch reviewed IML')
  const raw = json.data || json
  return Array.isArray(raw) ? raw.map(transformIMLItem) : []
}

export async function fetchIMLStats() {
  const response = await fetch(`${API_BASE}/iml/stats${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch IML stats')
  const data = json.data || json
  // Backend returns { overall: { confirmed, corrected, accuracy, ... }, byType: {...} }
  const overall = data.overall || data
  return {
    confirmed: overall.confirmed || overall.total_confirmed || 0,
    corrected: overall.corrected || overall.total_corrected || 0,
    accuracy: (overall.accuracy || 0) / 100, // normalize to 0-1 range
    totalFeedback: overall.totalSamples || overall.total_feedback || 0
  }
}

export async function submitIMLFeedback(alertId, isCorrect, correctedClassification = null) {
  const response = await fetch(`${API_BASE}/iml/feedback${userParam()}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      alertId,
      isCorrect,
      correctedClassification
    })
  })
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to submit IML feedback')
  return json.data || json
}

// ──────── Hearing Programs (under /api/environment) ────────
function transformProgram(prog) {
  return {
    id: prog.id,
    name: prog.name,
    description: prog.description,
    icon: prog.icon,
    isActive: prog.is_selected === 1 || prog.is_selected === true || prog.isActive,
    settings: {
      speechEnhancement: prog.speech_enhancement ?? prog.settings?.speechEnhancement ?? 50,
      noiseReduction: prog.noise_reduction ?? prog.settings?.noiseReduction ?? 50,
      forwardFocus: prog.forward_focus ?? prog.settings?.forwardFocus ?? 50
    }
  }
}

export async function fetchPrograms() {
  const response = await fetch(`${API_BASE}/environment/programs${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch programs')
  const raw = json.data || json
  return Array.isArray(raw) ? raw.map(transformProgram) : []
}

export async function selectProgram(id) {
  const response = await fetch(`${API_BASE}/environment/programs/${id}${userParam()}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ is_selected: true })
  })
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to select program')
  return json.data || json
}

export async function updateProgramSettings(id, settings) {
  const response = await fetch(`${API_BASE}/environment/programs/${id}${userParam()}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      speech_enhancement: settings.speechEnhancement,
      noise_reduction: settings.noiseReduction,
      forward_focus: settings.forwardFocus
    })
  })
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to update program settings')
  return json.data || json
}

export async function fetchCurrentEnvironment() {
  const response = await fetch(`${API_BASE}/environment/current${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch environment')
  const data = json.data || json
  return {
    noiseLevel: data.noiseLevel || data.noise_level || 45,
    soundProfile: data.soundProfile || data.sound_profile || 'moderate',
    location: data.location || 'Home',
    calendarStatus: data.calendar_event || data.calendarStatus || 'Free',
    timeOfDay: data.time_of_day || data.timeOfDay || 'afternoon',
    suggestedProgram: data.suggestedProgram || data.suggested_program
  }
}

// ──────── Profile ────────
export async function fetchProfile() {
  const response = await fetch(`${API_BASE}/profile${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch profile')
  const data = json.data || json
  return {
    id: data.id,
    name: data.name,
    email: data.email,
    avatarInitial: data.avatar_initial || (data.name ? data.name.charAt(0) : 'U'),
    deviceBrand: data.device_brand || data.deviceBrand,
    deviceModel: data.device_model || data.deviceModel,
    hearingLossLevel: data.hearing_loss_level || data.hearingLossLevel
  }
}

export async function updateProfile(data) {
  const response = await fetch(`${API_BASE}/profile${userParam()}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  })
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to update profile')
  return json.data || json
}

export async function fetchDeviceStatus() {
  const response = await fetch(`${API_BASE}/profile/device${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch device status')
  const data = json.data || json
  return {
    name: data.device_name || data.name || `${data.device_brand || ''} ${data.device_model || ''}`.trim() || 'Hearing Device',
    battery: data.battery_level ?? data.battery ?? 72,
    connected: data.is_connected !== undefined ? (data.is_connected === 1 || data.is_connected === true) : true,
    firmwareVersion: data.firmware_version || data.firmwareVersion || 'v5.2.1',
    wearTime: data.wear_time_hours || data.wearTime || 8
  }
}

// ──────── Transcription (under /api/transcribe) ────────
export async function fetchTranscriptionSessions() {
  const response = await fetch(`${API_BASE}/transcribe/sessions${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch transcription sessions')
  return json.data || json || []
}

export async function startTranscription() {
  const response = await fetch(`${API_BASE}/transcribe/sessions${userParam()}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  })
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to start transcription')
  return json.data || json
}

export async function endTranscription(id) {
  const response = await fetch(`${API_BASE}/transcribe/sessions/${id}${userParam()}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status: 'completed' })
  })
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to end transcription')
  return json.data || json
}

export async function fetchTranscriptionLines(sessionId) {
  const response = await fetch(`${API_BASE}/transcribe/sessions/${sessionId}/lines${userParam()}`)
  const json = await response.json()
  if (!response.ok) throw new Error('Failed to fetch transcription lines')
  const raw = json.data || json || []
  return Array.isArray(raw) ? raw.map(line => ({
    id: line.id,
    speaker: line.speaker_label || line.speaker || 'Unknown',
    text: line.text,
    timestamp: line.timestamp
  })) : []
}
