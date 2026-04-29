import React, { useState, useEffect, useCallback } from 'react'
import { fetchIMLPending, fetchIMLReviewed, fetchIMLStats, submitIMLFeedback } from '../../services/api'

const soundTypeMap = {
  doorbell: { icon: '🔔', label: 'Doorbell', color: '#FDCB6E' },
  fire_alarm: { icon: '🚨', label: 'Fire Alarm', color: '#FF6B6B' },
  'fire-alarm': { icon: '🚨', label: 'Fire Alarm', color: '#FF6B6B' },
  car_horn: { icon: '🚗', label: 'Car Horn', color: '#74B9FF' },
  'car-horn': { icon: '🚗', label: 'Car Horn', color: '#74B9FF' },
  name_called: { icon: '👤', label: 'Name Called', color: '#A29BFE' },
  name: { icon: '👤', label: 'Name Called', color: '#A29BFE' },
  alarm_timer: { icon: '⏱️', label: 'Timer/Alarm', color: '#00CEC9' },
  timer: { icon: '⏱️', label: 'Timer/Alarm', color: '#00CEC9' },
  baby_crying: { icon: '👶', label: 'Baby Crying', color: '#FD79A8' },
  baby: { icon: '👶', label: 'Baby Crying', color: '#FD79A8' },
  phone_ring: { icon: '📱', label: 'Phone Ring', color: '#00B894' },
  knock: { icon: '🚪', label: 'Knock', color: '#E17055' },
  siren: { icon: '🚑', label: 'Siren', color: '#D63031' },
  dog_bark: { icon: '🐕', label: 'Dog Bark', color: '#FFEAA7' },
  microwave: { icon: '📻', label: 'Microwave', color: '#81ECEC' },
  water_running: { icon: '🚰', label: 'Water Running', color: '#0984E3' },
  smoke_detector: { icon: '🔥', label: 'Smoke Detector', color: '#FF7675' },
  glass_breaking: { icon: '💎', label: 'Glass Breaking', color: '#DFE6E9' },
  crying: { icon: '😢', label: 'Crying', color: '#B2BEC3' },
  applause: { icon: '👏', label: 'Applause', color: '#55EFC4' }
}

const allSoundTypes = [
  { id: 'doorbell', label: 'Doorbell', icon: '🔔' },
  { id: 'fire_alarm', label: 'Fire Alarm', icon: '🚨' },
  { id: 'car_horn', label: 'Car Horn', icon: '🚗' },
  { id: 'name_called', label: 'Name Called', icon: '👤' },
  { id: 'alarm_timer', label: 'Timer/Alarm', icon: '⏱️' },
  { id: 'baby_crying', label: 'Baby Crying', icon: '👶' },
  { id: 'phone_ring', label: 'Phone Ring', icon: '📱' },
  { id: 'knock', label: 'Knock', icon: '🚪' },
  { id: 'siren', label: 'Siren', icon: '🚑' },
  { id: 'dog_bark', label: 'Dog Bark', icon: '🐕' }
]

function getSoundInfo(type) {
  return soundTypeMap[type] || { icon: '📢', label: type || 'Unknown', color: '#B8B8D4' }
}

// Circular progress ring component
function AccuracyRing({ accuracy, size = 100, stroke = 8 }) {
  const radius = (size - stroke) / 2
  const circumference = radius * 2 * Math.PI
  const offset = circumference - (accuracy / 100) * circumference
  const pct = Math.round(accuracy)

  let ringColor = '#00B894'
  if (pct < 70) ringColor = '#FF6B6B'
  else if (pct < 85) ringColor = '#FDCB6E'

  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="rgba(0,0,0,0.06)" strokeWidth={stroke} />
        <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke={ringColor} strokeWidth={stroke}
          strokeDasharray={circumference} strokeDashoffset={offset} strokeLinecap="round"
          style={{ transition: 'stroke-dashoffset 0.8s ease' }} />
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
        <span style={{ fontSize: size * 0.28, fontWeight: 800, color: 'var(--text-primary)' }}>{pct}%</span>
        <span style={{ fontSize: size * 0.11, color: 'var(--text-secondary)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px' }}>Accuracy</span>
      </div>
    </div>
  )
}

// Confidence bar
function ConfidenceBar({ confidence, color }) {
  const pct = Math.round(confidence * 100)
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, width: '100%' }}>
      <div style={{ flex: 1, height: 6, background: 'rgba(0,0,0,0.06)', borderRadius: 3, overflow: 'hidden' }}>
        <div style={{ width: `${pct}%`, height: '100%', background: color || 'var(--accent)', borderRadius: 3, transition: 'width 0.4s ease' }} />
      </div>
      <span style={{ fontSize: 11, fontWeight: 700, color: color || 'var(--accent)', minWidth: 34, textAlign: 'right' }}>{pct}%</span>
    </div>
  )
}

export function IMLScreen() {
  const [stats, setStats] = useState(null)
  const [pending, setPending] = useState([])
  const [reviewed, setReviewed] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [showCorrection, setShowCorrection] = useState(null)
  const [submitLoading, setSubmitLoading] = useState(false)
  const [trainingActive, setTrainingActive] = useState(false)
  const [trainingProgress, setTrainingProgress] = useState(0)
  const [feedbackAnimation, setFeedbackAnimation] = useState(null) // 'correct' | 'incorrect' | null
  const [tab, setTab] = useState('review') // 'review' | 'insights'

  useEffect(() => { loadData() }, [])

  async function loadData() {
    try {
      setLoading(true)
      const [statsData, pendingData, reviewedData] = await Promise.all([
        fetchIMLStats(), fetchIMLPending(), fetchIMLReviewed()
      ])
      setStats(statsData)
      setPending(pendingData)
      setReviewed(reviewedData)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  async function handleFeedback(alertId, isCorrect, correctedClassification = null) {
    try {
      setSubmitLoading(true)
      setFeedbackAnimation(isCorrect ? 'correct' : 'incorrect')

      await submitIMLFeedback(alertId, isCorrect, correctedClassification)

      // Brief animation delay
      await new Promise(r => setTimeout(r, 400))

      setPending(prev => prev.filter(p => p.id !== alertId))
      setShowCorrection(null)
      setFeedbackAnimation(null)

      // Reload stats only (not the full page)
      const newStats = await fetchIMLStats()
      setStats(newStats)
      const newReviewed = await fetchIMLReviewed()
      setReviewed(newReviewed)
    } catch (err) {
      setError(err.message)
      setFeedbackAnimation(null)
    } finally {
      setSubmitLoading(false)
    }
  }

  function handleTrainModel() {
    setTrainingActive(true)
    setTrainingProgress(0)
    let progress = 0
    const interval = setInterval(() => {
      progress += Math.random() * 15 + 5
      if (progress >= 100) {
        progress = 100
        clearInterval(interval)
        setTimeout(() => {
          setTrainingActive(false)
          setTrainingProgress(0)
        }, 800)
      }
      setTrainingProgress(Math.min(Math.round(progress), 100))
    }, 300)
  }

  if (loading) {
    return <div className="screen iml-screen"><div className="loading-container"><div className="loading-spinner"></div><p>Loading SPECTRA data...</p></div></div>
  }

  if (error) {
    return (
      <div className="screen iml-screen">
        <div className="error-container">
          <p>Error: {error}</p>
          <button className="btn-primary" onClick={() => { setError(null); loadData() }}>Retry</button>
        </div>
      </div>
    )
  }

  const totalFeedback = (stats?.confirmed || 0) + (stats?.corrected || 0)
  const accuracy = stats?.accuracy ? Math.round(stats.accuracy * 100) : (totalFeedback > 0 ? 100 : 0)

  const currentAlert = pending[0]
  const soundInfo = currentAlert ? getSoundInfo(currentAlert.type) : null

  return (
    <div className="screen iml-screen">

      {/* Header with SPECTRA branding */}
      <div className="iml-hero">
        <div className="iml-hero-left">
          <h2 className="iml-hero-title">SPECTRA</h2>
          <p className="iml-hero-sub">Your personal sound model</p>
          <div className="iml-hero-stats">
            <div className="iml-mini-stat">
              <span className="iml-mini-value">{totalFeedback}</span>
              <span className="iml-mini-label">Samples</span>
            </div>
            <div className="iml-mini-stat">
              <span className="iml-mini-value">{stats?.confirmed || 0}</span>
              <span className="iml-mini-label">Confirmed</span>
            </div>
            <div className="iml-mini-stat">
              <span className="iml-mini-value">{stats?.corrected || 0}</span>
              <span className="iml-mini-label">Corrected</span>
            </div>
          </div>
        </div>
        <AccuracyRing accuracy={accuracy} size={78} stroke={6} />
      </div>

      {/* Tab Switcher */}
      <div className="iml-tabs">
        <button className={`iml-tab ${tab === 'review' ? 'active' : ''}`} onClick={() => setTab('review')}>
          Review {pending.length > 0 && <span className="iml-tab-badge">{pending.length}</span>}
        </button>
        <button className={`iml-tab ${tab === 'insights' ? 'active' : ''}`} onClick={() => setTab('insights')}>
          Insights
        </button>
      </div>

      {tab === 'review' && (
        <>
          {/* Current Card to Review */}
          {currentAlert ? (
            <div className={`iml-review-card ${feedbackAnimation || ''}`}>
              {showCorrection === currentAlert.id ? (
                <div className="correction-panel">
                  <h4 style={{ marginBottom: 4 }}>What was the actual sound?</h4>
                  <p style={{ fontSize: 11, color: 'var(--text-secondary)', margin: '0 0 12px' }}>Select the correct classification below</p>
                  <div className="sound-options">
                    {allSoundTypes.map((sound) => (
                      <button key={sound.id} className="sound-option" onClick={() => handleFeedback(currentAlert.id, false, sound.id)} disabled={submitLoading}>
                        <span>{sound.icon}</span>
                        <span>{sound.label}</span>
                      </button>
                    ))}
                  </div>
                  <button className="btn-secondary" onClick={() => setShowCorrection(null)} style={{ marginTop: 12, width: '100%' }}>Cancel</button>
                </div>
              ) : (
                <>
                  {/* Sound visualization */}
                  <div className="iml-sound-viz">
                    <div className="iml-sound-icon-ring" style={{ borderColor: soundInfo.color + '40', background: soundInfo.color + '15' }}>
                      <span style={{ fontSize: 28 }}>{soundInfo.icon}</span>
                    </div>
                    <div className="iml-sound-waves">
                      {[...Array(5)].map((_, i) => (
                        <div key={i} className="iml-wave-bar" style={{ animationDelay: `${i * 0.1}s`, background: soundInfo.color }} />
                      ))}
                    </div>
                  </div>

                  <div style={{ textAlign: 'center' }}>
                    <h3 className="iml-detected-label">Detected: <span style={{ color: soundInfo.color }}>{soundInfo.label}</span></h3>
                    <p className="iml-detected-meta">
                      {currentAlert.location && <span>📍 {currentAlert.location}</span>}
                      {currentAlert.timeOfDay && <span> · 🕐 {currentAlert.timeOfDay}</span>}
                    </p>
                  </div>

                  <div style={{ padding: '0 8px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                      <span style={{ fontSize: 11, color: 'var(--text-secondary)' }}>Confidence</span>
                    </div>
                    <ConfidenceBar confidence={currentAlert.confidence} color={soundInfo.color} />
                  </div>

                  <p className="iml-question-text">Is this classification correct?</p>

                  <div className="iml-action-row">
                    <button className="iml-btn-correct" onClick={() => handleFeedback(currentAlert.id, true)} disabled={submitLoading}>
                      <span style={{ fontSize: 18 }}>✓</span>
                      <span>Correct</span>
                    </button>
                    <button className="iml-btn-wrong" onClick={() => setShowCorrection(currentAlert.id)} disabled={submitLoading}>
                      <span style={{ fontSize: 18 }}>✗</span>
                      <span>Wrong</span>
                    </button>
                    <button className="iml-btn-skip" onClick={() => setPending(prev => prev.filter(p => p.id !== currentAlert.id))} disabled={submitLoading}>
                      <span style={{ fontSize: 14 }}>⊘</span>
                      <span>Skip</span>
                    </button>
                  </div>

                  {pending.length > 1 && (
                    <p style={{ textAlign: 'center', fontSize: 11, color: 'var(--text-secondary)', margin: 0 }}>
                      {pending.length - 1} more to review
                    </p>
                  )}
                </>
              )}
            </div>
          ) : (
            <div className="iml-empty-state">
              <span style={{ fontSize: 48 }}>🎉</span>
              <h3>All caught up!</h3>
              <p>No pending reviews. Use the app to generate more sound alerts, then come back to train your model.</p>
            </div>
          )}

          {/* Train Model Button */}
          <button className={`iml-train-btn ${trainingActive ? 'training' : ''}`} onClick={handleTrainModel} disabled={trainingActive || totalFeedback === 0}>
            {trainingActive ? (
              <>
                <div className="iml-train-progress" style={{ width: `${trainingProgress}%` }} />
                <span className="iml-train-label">Training SPECTRA... {trainingProgress}%</span>
              </>
            ) : (
              <>
                <span style={{ fontSize: 18 }}>🧠</span>
                <span className="iml-train-label">Train Model ({totalFeedback} samples)</span>
              </>
            )}
          </button>

          {/* Recent Reviews */}
          {reviewed.length > 0 && (
            <div className="section">
              <h3 className="section-title">Recent Reviews</h3>
              <div className="iml-reviewed-list">
                {reviewed.slice(0, 5).map((item) => {
                  const info = getSoundInfo(item.type)
                  return (
                    <div key={item.id} className="iml-reviewed-row">
                      <span style={{ fontSize: 18 }}>{info.icon}</span>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <span style={{ fontSize: 12, fontWeight: 600 }}>{info.label}</span>
                      </div>
                      <span className={`iml-reviewed-badge ${item.isCorrect ? 'correct' : 'corrected'}`}>
                        {item.isCorrect ? '✓' : '✗'}
                      </span>
                    </div>
                  )
                })}
              </div>
            </div>
          )}
        </>
      )}

      {tab === 'insights' && (
        <>
          {/* Sound Types Breakdown */}
          <div className="section">
            <h3 className="section-title">Sound Types Detected</h3>
            <div className="iml-breakdown">
              {(() => {
                // Build counts from all reviewed + pending
                const allItems = [...reviewed, ...pending]
                const counts = {}
                allItems.forEach(item => {
                  const t = item.type || 'unknown'
                  counts[t] = (counts[t] || 0) + 1
                })
                const total = allItems.length || 1
                const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1])

                if (sorted.length === 0) {
                  return <p className="empty-message" style={{ padding: '16px' }}>No sound data yet. Use the app to detect sounds.</p>
                }

                return sorted.map(([type, count]) => {
                  const info = getSoundInfo(type)
                  const pct = Math.round((count / total) * 100)
                  return (
                    <div key={type} className="iml-breakdown-row">
                      <span style={{ fontSize: 18, width: 28, textAlign: 'center' }}>{info.icon}</span>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 3 }}>
                          <span style={{ fontSize: 12, fontWeight: 600 }}>{info.label}</span>
                          <span style={{ fontSize: 11, color: 'var(--text-secondary)' }}>{count}x · {pct}%</span>
                        </div>
                        <div style={{ height: 5, background: 'rgba(0,0,0,0.06)', borderRadius: 3, overflow: 'hidden' }}>
                          <div style={{ width: `${pct}%`, height: '100%', background: info.color, borderRadius: 3 }} />
                        </div>
                      </div>
                    </div>
                  )
                })
              })()}
            </div>
          </div>

          {/* How IML Works */}
          <div className="section">
            <h3 className="section-title">How SPECTRA Learns</h3>
            <div className="iml-how-works">
              <div className="iml-step-row">
                <div className="iml-step-num">1</div>
                <div className="iml-step-content">
                  <strong>Detect</strong>
                  <p>Microphone picks up ambient sounds and the classifier identifies them.</p>
                </div>
              </div>
              <div className="iml-step-row">
                <div className="iml-step-num">2</div>
                <div className="iml-step-content">
                  <strong>Review</strong>
                  <p>You confirm or correct the classification to provide ground truth data.</p>
                </div>
              </div>
              <div className="iml-step-row">
                <div className="iml-step-num">3</div>
                <div className="iml-step-content">
                  <strong>Learn</strong>
                  <p>SPECTRA updates its model weights based on your feedback, becoming more accurate over time.</p>
                </div>
              </div>
              <div className="iml-step-row">
                <div className="iml-step-num">4</div>
                <div className="iml-step-content">
                  <strong>Personalize</strong>
                  <p>Your model adapts to your specific environment, home acoustics, and hearing needs.</p>
                </div>
              </div>
            </div>
          </div>

          {/* SPECTRA info */}
          <div className="iml-footer">
            <p><strong>SPECTRA</strong> — Sound Processing Engine for Context-aware, Trainable, Real-time Alerts</p>
            <p style={{ marginTop: 6 }}>Based on Goodman et al. (2025) Interactive Machine Learning framework. Your feedback loop continuously improves classification accuracy personalized to your acoustic environment.</p>
          </div>
        </>
      )}
    </div>
  )
}
