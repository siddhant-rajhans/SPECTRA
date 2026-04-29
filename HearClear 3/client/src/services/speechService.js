/**
 * Speech Service — Real-time speech-to-text using Web Speech API
 * Provides live transcription with speaker detection heuristics
 */

let recognition = null
let isActive = false
let currentSpeaker = 1
let lastResultTime = 0
const SPEAKER_CHANGE_PAUSE_MS = 2000 // Pause > 2s suggests new speaker

/**
 * Check if Web Speech API is supported
 */
export function isSpeechSupported() {
  return !!(window.SpeechRecognition || window.webkitSpeechRecognition)
}

/**
 * Start real-time transcription
 * @param {Object} options
 * @param {Function} options.onResult - Called with { text, speaker, isFinal, timestamp }
 * @param {Function} options.onEnd - Called when recognition stops
 * @param {Function} options.onError - Called with error message
 * @param {string} options.language - Language code (default: 'en-US')
 */
export function startTranscription({ onResult, onEnd, onError, language = 'en-US' }) {
  if (!isSpeechSupported()) {
    if (onError) onError('Speech recognition is not supported in this browser. Please use Chrome.')
    return false
  }

  if (isActive) {
    stopTranscription()
  }

  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
  recognition = new SpeechRecognition()

  recognition.continuous = true
  recognition.interimResults = true
  recognition.lang = language
  recognition.maxAlternatives = 1

  currentSpeaker = 1
  lastResultTime = Date.now()

  recognition.onresult = (event) => {
    const now = Date.now()

    // Heuristic speaker change: long pause between results
    if (now - lastResultTime > SPEAKER_CHANGE_PAUSE_MS && lastResultTime > 0) {
      currentSpeaker = currentSpeaker >= 4 ? 1 : currentSpeaker + 1
    }
    lastResultTime = now

    for (let i = event.resultIndex; i < event.results.length; i++) {
      const result = event.results[i]
      const text = result[0].transcript.trim()

      if (text && onResult) {
        onResult({
          text,
          speaker: `Speaker ${currentSpeaker}`,
          isFinal: result.isFinal,
          confidence: result[0].confidence || 0.9,
          timestamp: formatTimestamp(now)
        })
      }
    }
  }

  recognition.onerror = (event) => {
    console.error('Speech recognition error:', event.error)
    if (event.error === 'not-allowed') {
      if (onError) onError('Microphone permission denied. Please allow microphone access.')
    } else if (event.error === 'no-speech') {
      // Silently restart — this is normal
      if (isActive) {
        try { recognition.start() } catch (e) { /* ignore */ }
      }
    } else if (event.error === 'network') {
      if (onError) onError('Network error. Speech recognition requires an internet connection in Chrome.')
    } else {
      if (onError) onError(`Speech recognition error: ${event.error}`)
    }
  }

  recognition.onend = () => {
    // Auto-restart if still supposed to be active
    if (isActive) {
      try {
        recognition.start()
      } catch (e) {
        isActive = false
        if (onEnd) onEnd()
      }
    } else {
      if (onEnd) onEnd()
    }
  }

  try {
    recognition.start()
    isActive = true
    return true
  } catch (err) {
    if (onError) onError('Failed to start speech recognition: ' + err.message)
    return false
  }
}

/**
 * Stop transcription
 */
export function stopTranscription() {
  isActive = false
  if (recognition) {
    try {
      recognition.stop()
    } catch (e) { /* ignore */ }
    recognition = null
  }
}

/**
 * Check if transcription is currently active
 */
export function isTranscribing() {
  return isActive
}

/**
 * Format a timestamp for display
 */
let transcriptionStartTime = null
function formatTimestamp(now) {
  if (!transcriptionStartTime) transcriptionStartTime = now
  const elapsed = Math.floor((now - transcriptionStartTime) / 1000)
  const mins = Math.floor(elapsed / 60).toString().padStart(2, '0')
  const secs = (elapsed % 60).toString().padStart(2, '0')
  return `${mins}:${secs}`
}

/**
 * Reset the transcription start time
 */
export function resetTimer() {
  transcriptionStartTime = null
  currentSpeaker = 1
}
