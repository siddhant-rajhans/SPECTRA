import React, { useState, useEffect, useRef } from 'react'
import { isSpeechSupported, startTranscription, stopTranscription, resetTimer } from '../../services/speechService'

export function TranscribeScreen() {
  const [isRecording, setIsRecording] = useState(false)
  const [lines, setLines] = useState([])
  const [interimText, setInterimText] = useState('')
  const [error, setError] = useState(null)
  const [fontSize, setFontSize] = useState(16)
  const [speakerCount, setSpeakerCount] = useState(0)
  const [duration, setDuration] = useState(0)
  const transcriptRef = useRef(null)
  const timerRef = useRef(null)
  const supported = isSpeechSupported()

  useEffect(() => {
    if (transcriptRef.current) {
      transcriptRef.current.scrollTop = transcriptRef.current.scrollHeight
    }
  }, [lines, interimText])

  useEffect(() => {
    if (isRecording) {
      timerRef.current = setInterval(() => setDuration(prev => prev + 1), 1000)
    } else {
      if (timerRef.current) clearInterval(timerRef.current)
    }
    return () => { if (timerRef.current) clearInterval(timerRef.current) }
  }, [isRecording])

  const handleStartStop = () => {
    if (isRecording) {
      stopTranscription(); setIsRecording(false); setInterimText('')
    } else {
      setError(null); setDuration(0); resetTimer()
      const started = startTranscription({
        onResult: (result) => {
          if (result.isFinal) {
            setLines(prev => {
              const newLines = [...prev, { speaker: result.speaker, text: result.text, timestamp: result.timestamp }]
              setSpeakerCount(new Set(newLines.map(l => l.speaker)).size)
              return newLines
            })
            setInterimText('')
          } else { setInterimText(result.text) }
        },
        onEnd: () => {},
        onError: (errMsg) => { setError(errMsg); setIsRecording(false) }
      })
      if (started) setIsRecording(true)
    }
  }

  const handleClear = () => { setLines([]); setInterimText(''); setSpeakerCount(0); setDuration(0) }

  const handleDownload = () => {
    const text = lines.map(l => `[${l.timestamp}] ${l.speaker}: ${l.text}`).join('\n')
    const blob = new Blob([text], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a'); a.href = url
    a.download = `transcript-${new Date().toISOString().slice(0, 10)}.txt`
    a.click(); URL.revokeObjectURL(url)
  }

  const formatDuration = (secs) => {
    const m = Math.floor(secs / 60).toString().padStart(2, '0')
    const s = (secs % 60).toString().padStart(2, '0')
    return `${m}:${s}`
  }

  return (
    <div className="screen transcribe-screen">
      {/* Waveform */}
      <div className="waveform-container">
        <div className="waveform">
          {[1, 2, 3, 4, 5, 6, 7].map((i) => (
            <div key={i} className={`waveform-bar ${isRecording ? 'active' : ''}`}
              style={isRecording ? { animationDelay: `${i * 0.08}s` } : {}}></div>
          ))}
        </div>
        <div className="recording-status" style={{ display: 'flex', alignItems: 'center', gap: 6, justifyContent: 'center' }}>
          {isRecording ? (
            <>
              <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#EF4444', animation: 'livePulse 1.5s infinite' }}></span>
              <span>Listening — speak clearly</span>
            </>
          ) : (
            <span>Tap Start to begin transcription</span>
          )}
        </div>
      </div>

      {/* Transcript */}
      <div className="transcript-box" ref={transcriptRef} style={{ fontSize }}>
        {lines.length === 0 && !interimText ? (
          <p className="transcript-placeholder">
            {isRecording ? 'Listening for speech...' : 'Your conversation will appear here in real time'}
          </p>
        ) : (
          <div className="transcript-lines">
            {lines.map((line, idx) => (
              <div key={idx} className="transcript-line">
                <span className="speaker-label" style={{ fontSize: fontSize - 2 }}>{line.speaker}:</span>
                <span className="transcript-text">{line.text}</span>
              </div>
            ))}
            {interimText && (
              <div className="transcript-line" style={{ opacity: 0.5 }}>
                <span className="speaker-label" style={{ fontSize: fontSize - 2 }}>...</span>
                <span className="transcript-text">{interimText}</span>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Stats */}
      <div className="transcribe-info">
        <div className="info-item"><span className="info-label">Duration</span><span className="info-value">{formatDuration(duration)}</span></div>
        <div className="info-item"><span className="info-label">Speakers</span><span className="info-value">{speakerCount}</span></div>
        <div className="info-item"><span className="info-label">Lines</span><span className="info-value">{lines.length}</span></div>
        <div className="info-item"><span className="info-label">Size</span><span className="info-value">{fontSize}px</span></div>
      </div>

      {/* Font Controls */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, justifyContent: 'center' }}>
        <button className="btn-secondary" onClick={() => setFontSize(prev => Math.max(12, prev - 2))} style={{ padding: '6px 14px', fontSize: 14 }}>A-</button>
        <span style={{ fontSize: 13, color: 'var(--text-secondary)' }}>Font Size</span>
        <button className="btn-secondary" onClick={() => setFontSize(prev => Math.min(28, prev + 2))} style={{ padding: '6px 14px', fontSize: 14 }}>A+</button>
      </div>

      {/* Controls */}
      <div className="transcribe-controls">
        <button className="btn-secondary" onClick={handleDownload} disabled={lines.length === 0}>Save</button>
        <button className={`btn-primary ${isRecording ? 'recording' : ''}`} onClick={handleStartStop} disabled={!supported}>
          {isRecording ? '■ Stop' : '▶ Start'}
        </button>
        <button className="btn-secondary" onClick={handleClear} disabled={lines.length === 0}>Clear</button>
      </div>

      {/* Error / Info */}
      {error && (
        <div style={{
          display: 'flex', alignItems: 'flex-start', gap: 10,
          padding: '12px 14px', borderRadius: 12,
          background: 'rgba(245,158,11,0.06)', border: '1px solid rgba(245,158,11,0.12)'
        }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#D97706" strokeWidth="2" strokeLinecap="round" style={{ flexShrink: 0, marginTop: 1 }}>
            <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
          </svg>
          <div>
            <p style={{ fontSize: 13, fontWeight: 600, color: '#92400E', margin: 0 }}>Speech Recognition Unavailable</p>
            <p style={{ fontSize: 12, color: '#B45309', margin: '3px 0 0', lineHeight: 1.5 }}>
              {error.includes('network') || error.includes('Network')
                ? 'An active internet connection is required. Chrome processes speech via Google servers for accuracy.'
                : error}
            </p>
          </div>
        </div>
      )}

      {!supported && !error && (
        <div style={{
          display: 'flex', alignItems: 'flex-start', gap: 10,
          padding: '12px 14px', borderRadius: 12,
          background: 'rgba(99,102,241,0.05)', border: '1px solid rgba(99,102,241,0.1)'
        }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" strokeWidth="2" strokeLinecap="round" style={{ flexShrink: 0, marginTop: 1 }}>
            <circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>
          </svg>
          <div>
            <p style={{ fontSize: 13, fontWeight: 600, color: 'var(--primary)', margin: 0 }}>Browser Not Supported</p>
            <p style={{ fontSize: 12, color: 'var(--text-secondary)', margin: '3px 0 0', lineHeight: 1.5 }}>
              Speech recognition requires Google Chrome on desktop or Android.
            </p>
          </div>
        </div>
      )}
    </div>
  )
}
