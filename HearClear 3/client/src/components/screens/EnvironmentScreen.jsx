import React, { useState, useEffect, useRef } from 'react'
import { fetchPrograms, selectProgram, updateProgramSettings } from '../../services/api'
import { isAudioSupported, startListening, stopListening, getIsListening, onNoiseLevel, onSoundDetected, isModelReady } from '../../services/audioService'

const programIcons = {
  home: '🏠', utensils: '🍽️', music: '🎵', car: '🚗',
  moon: '😴', restaurant: '🍽️', outdoors: '🌳', sleep: '😴', cog: '⚙️'
}

export function EnvironmentScreen() {
  const [programs, setPrograms] = useState([])
  const [selectedProgram, setSelectedProgram] = useState(null)
  const [settings, setSettings] = useState({
    speechEnhancement: 50, noiseReduction: 50, forwardFocus: 50
  })
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const debounceTimer = useRef(null)

  // Real audio monitoring
  const [monitoring, setMonitoring] = useState(false)
  const [dbLevel, setDbLevel] = useState(0)
  const [freqBands, setFreqBands] = useState({ low: 0, mid: 0, high: 0 })
  const [lastSound, setLastSound] = useState(null)
  const [mlReady, setMlReady] = useState(false)
  const audioSupported = isAudioSupported()

  useEffect(() => {
    loadData()
    return () => { if (getIsListening()) stopListening() }
  }, [])

  useEffect(() => {
    onNoiseLevel((data) => {
      setDbLevel(data.dbLevel)
      setFreqBands({ low: data.low, mid: data.mid, high: data.high })
      if (data.modelReady !== undefined) setMlReady(data.modelReady)
    })
    onSoundDetected((event) => {
      setLastSound(event)
      setTimeout(() => setLastSound(null), 5000)
    })
  }, [])

  async function loadData() {
    try {
      setLoading(true)
      const programsData = await fetchPrograms()
      setPrograms(programsData)
      const active = programsData.find(p => p.isActive)
      if (active) {
        setSelectedProgram(active.id)
        setSettings({
          speechEnhancement: active.settings?.speechEnhancement || 50,
          noiseReduction: active.settings?.noiseReduction || 50,
          forwardFocus: active.settings?.forwardFocus || 50
        })
      }
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  async function handleToggleMonitoring() {
    if (monitoring) {
      stopListening()
      setMonitoring(false)
      setDbLevel(0)
      setFreqBands({ low: 0, mid: 0, high: 0 })
    } else {
      try {
        await startListening()
        setMonitoring(true)
      } catch (err) {
        setError(err.message)
      }
    }
  }

  async function handleSelectProgram(programId) {
    try {
      setSelectedProgram(programId)
      await selectProgram(programId)
      const updated = programs.find(p => p.id === programId)
      if (updated) {
        setSettings({
          speechEnhancement: updated.settings?.speechEnhancement || 50,
          noiseReduction: updated.settings?.noiseReduction || 50,
          forwardFocus: updated.settings?.forwardFocus || 50
        })
      }
    } catch (err) {
      console.error('Failed to select program:', err)
    }
  }

  function handleSettingChange(setting, value) {
    const newSettings = { ...settings, [setting]: value }
    setSettings(newSettings)
    if (debounceTimer.current) clearTimeout(debounceTimer.current)
    debounceTimer.current = setTimeout(async () => {
      try { await updateProgramSettings(selectedProgram, newSettings) }
      catch (err) { console.error('Failed to update settings:', err) }
    }, 1000)
  }

  // Noise classification
  const getNoiseLabel = () => dbLevel >= 80 ? 'Very Loud' : dbLevel >= 65 ? 'Loud' : dbLevel >= 50 ? 'Moderate' : dbLevel >= 30 ? 'Quiet' : 'Silent'
  const getNoiseColor = () => dbLevel >= 80 ? '#EF4444' : dbLevel >= 65 ? '#F59E0B' : dbLevel >= 50 ? '#3B82F6' : '#10B981'
  const gaugeAngle = Math.min((dbLevel / 120) * 180, 180)
  const maxFreq = Math.max(freqBands.low, freqBands.mid, freqBands.high, 1)

  if (loading) {
    return (
      <div className="screen environment-screen">
        {[1, 2, 3].map(i => (
          <div key={i} style={{
            height: i === 1 ? 140 : 80, borderRadius: 16, marginBottom: 12,
            background: 'linear-gradient(90deg, var(--bg) 25%, var(--bg-card-hover) 50%, var(--bg) 75%)',
            backgroundSize: '200% 100%', animation: 'shimmer 1.5s infinite'
          }}></div>
        ))}
        <style>{`@keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }`}</style>
      </div>
    )
  }

  return (
    <div className="screen environment-screen">
      {/* ── Noise Gauge ── */}
      <div className="gauge-container">
        <div className="noise-gauge">
          <div className="gauge-fill" style={{
            background: monitoring
              ? `conic-gradient(from 180deg, #10B981 0deg, ${getNoiseColor()} ${gaugeAngle}deg, var(--bg-card) ${gaugeAngle}deg)`
              : 'conic-gradient(from 180deg, var(--border) 0deg, var(--border) 0deg)'
          }}></div>
          <div className="gauge-label">
            <p className="gauge-db" style={{ color: monitoring ? getNoiseColor() : 'var(--text-tertiary)' }}>
              {monitoring ? dbLevel : '--'}<span style={{ fontSize: '0.5em' }}>dB</span>
            </p>
            <p className={`gauge-env`} style={{ color: monitoring ? getNoiseColor() : 'var(--text-tertiary)' }}>
              {monitoring ? getNoiseLabel() : 'Tap to start'}
            </p>
          </div>
        </div>

        <button
          className={`btn-primary ${monitoring ? 'recording' : ''}`}
          onClick={handleToggleMonitoring}
          disabled={!audioSupported}
          aria-label={monitoring ? 'Stop noise monitoring' : 'Start noise monitoring'}
          style={{ marginTop: 12, padding: '10px 32px', fontSize: 14 }}
        >
          {monitoring ? '⏹ Stop Monitoring' : '🎙️ Start Monitoring'}
        </button>

        {/* ML Status */}
        {monitoring && (
          <div style={{ display: 'flex', gap: 6, justifyContent: 'center', marginTop: 8 }}>
            <span style={{
              padding: '2px 8px', borderRadius: 12, fontSize: 10, fontWeight: 600,
              background: mlReady ? 'rgba(16,185,129,0.1)' : 'rgba(245,158,11,0.1)',
              color: mlReady ? '#10B981' : '#F59E0B'
            }}>{mlReady ? '🧠 YAMNet Active' : '📊 Heuristic Mode'}</span>
          </div>
        )}

        {!audioSupported && (
          <p style={{ fontSize: 12, color: 'var(--danger)', textAlign: 'center', margin: '8px 0 0' }}>
            Microphone not supported in this browser
          </p>
        )}
      </div>

      {/* ── Frequency Bands ── */}
      {monitoring && (
        <div style={{
          display: 'flex', justifyContent: 'center', alignItems: 'flex-end', gap: 20,
          padding: '14px 16px', background: 'var(--bg)', borderRadius: 12, margin: '0 0 8px'
        }}>
          {[
            { label: 'Bass', value: freqBands.low, color: '#6366F1' },
            { label: 'Mid', value: freqBands.mid, color: '#3B82F6' },
            { label: 'Treble', value: freqBands.high, color: '#06B6D4' },
          ].map(band => (
            <div key={band.label} style={{ textAlign: 'center', flex: 1 }}>
              <div style={{
                width: '100%', maxWidth: 44, height: Math.max(6, (band.value / maxFreq) * 50),
                background: `linear-gradient(to top, ${band.color}, ${band.color}88)`,
                borderRadius: 4, transition: 'height 0.15s ease',
                margin: '0 auto'
              }}></div>
              <span style={{ fontSize: 10, color: 'var(--text-tertiary)', marginTop: 4, display: 'block' }}>{band.label}</span>
              <span style={{ fontSize: 9, color: 'var(--text-tertiary)' }}>{Math.round(band.value)}</span>
            </div>
          ))}
        </div>
      )}

      {/* ── Sound Detection Alert ── */}
      {lastSound && (
        <div style={{
          padding: '12px 16px', borderRadius: 12, margin: '0 0 8px',
          background: lastSound.priority === 'critical' ? 'rgba(239,68,68,0.08)' : 'rgba(245,158,11,0.08)',
          border: `1px solid ${lastSound.priority === 'critical' ? 'rgba(239,68,68,0.2)' : 'rgba(245,158,11,0.2)'}`,
          display: 'flex', alignItems: 'center', gap: 10,
          animation: 'fadeIn 0.3s ease'
        }}>
          <span style={{ fontSize: 22 }}>{lastSound.priority === 'critical' ? '🚨' : '🔊'}</span>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, fontWeight: 600 }}>{lastSound.label} Detected</div>
            <div style={{ fontSize: 11, color: 'var(--text-secondary)' }}>
              {Math.round(lastSound.confidence * 100)}% confidence · {lastSound.dbLevel}dB · {lastSound.method === 'yamnet' ? 'ML Classification' : 'Heuristic'}
            </div>
          </div>
        </div>
      )}

      {/* ── Hearing Programs ── */}
      <div className="section">
        <h3 className="section-title">Hearing Programs</h3>
        <div className="programs-grid">
          {programs.map((program) => (
            <button
              key={program.id}
              className={`program-card ${selectedProgram === program.id ? 'active' : ''}`}
              onClick={() => handleSelectProgram(program.id)}
              aria-label={`Select ${program.name} program`}
              aria-pressed={selectedProgram === program.id}
            >
              <span className="program-icon">{programIcons[program.icon] || '⚙️'}</span>
              <span className="program-name">{program.name}</span>
            </button>
          ))}
        </div>
      </div>

      {/* ── Fine Tuning ── */}
      <div className="section">
        <h3 className="section-title">Fine Tuning</h3>
        <div className="sliders-container">
          {[
            { key: 'speechEnhancement', label: 'Speech Enhancement' },
            { key: 'noiseReduction', label: 'Background Noise Reduction' },
            { key: 'forwardFocus', label: 'Forward Focus' }
          ].map(slider => (
            <div className="slider-group" key={slider.key}>
              <label className="slider-label">
                <span>{slider.label}</span>
                <span className="slider-value">{settings[slider.key]}%</span>
              </label>
              <input
                type="range" min="0" max="100"
                value={settings[slider.key]}
                onChange={(e) => handleSettingChange(slider.key, parseInt(e.target.value))}
                className="slider-input"
                aria-label={`${slider.label}: ${settings[slider.key]}%`}
              />
            </div>
          ))}
        </div>
      </div>

      {error && <p className="error-message">{error}</p>}

      <style>{`
        @keyframes fadeIn { from { opacity: 0; transform: translateY(-4px); } to { opacity: 1; transform: translateY(0); } }
      `}</style>
    </div>
  )
}
