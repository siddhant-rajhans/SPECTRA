import React, { useState, useEffect } from 'react'
import { fetchMonitoredSounds, toggleMonitoredSound, fetchContextRules, toggleContextRule, fetchAlerts } from '../../services/api'

const soundTypeMap = {
  doorbell: '🔔',
  'fire-alarm': '🚨',
  'car-horn': '🚗',
  name: '👤',
  timer: '⏱️',
  baby: '👶'
}

function getContextRuleIcon(rule) {
  const title = (rule.title || '').toLowerCase()
  if (title.includes('meeting')) return '📞'
  if (title.includes('sleep')) return '😴'
  if (title.includes('outdoor')) return '🌳'
  if (title.includes('restaurant')) return '🍽️'
  return '⚙️'
}

export function AlertsScreen() {
  const [monitoredSounds, setMonitoredSounds] = useState([])
  const [contextRules, setContextRules] = useState([])
  const [alerts, setAlerts] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    loadData()
  }, [])

  async function loadData() {
    try {
      setLoading(true)
      const [soundsData, rulesData, alertsData] = await Promise.all([
        fetchMonitoredSounds(),
        fetchContextRules(),
        fetchAlerts()
      ])
      setMonitoredSounds(soundsData)
      setContextRules(rulesData)
      setAlerts(alertsData)
    } catch (err) {
      setError(err.message)
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  async function handleToggleSound(soundType, currentValue) {
    try {
      await toggleMonitoredSound(soundType, !currentValue)
      setMonitoredSounds(
        monitoredSounds.map(s =>
          s.type === soundType ? { ...s, isEnabled: !currentValue } : s
        )
      )
    } catch (err) {
      console.error('Failed to toggle sound:', err)
    }
  }

  async function handleToggleRule(ruleId, currentValue) {
    try {
      await toggleContextRule(ruleId, !currentValue)
      setContextRules(
        contextRules.map(r =>
          r.id === ruleId ? { ...r, isActive: !currentValue } : r
        )
      )
    } catch (err) {
      console.error('Failed to toggle rule:', err)
    }
  }

  if (loading) {
    return (
      <div className="screen alerts-screen">
        {[1, 2, 3].map(i => (
          <div key={i} style={{
            height: i === 1 ? 100 : 70, borderRadius: 16, marginBottom: 12,
            background: 'linear-gradient(90deg, var(--bg) 25%, var(--bg-card-hover) 50%, var(--bg) 75%)',
            backgroundSize: '200% 100%', animation: 'shimmer 1.5s infinite'
          }}></div>
        ))}
        <style>{`@keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }`}</style>
      </div>
    )
  }

  if (error) {
    return (
      <div className="screen alerts-screen" style={{ textAlign: 'center', paddingTop: 60 }}>
        <span style={{ fontSize: 48, display: 'block', marginBottom: 16 }}>⚠️</span>
        <p style={{ fontSize: 15, fontWeight: 600, marginBottom: 4 }}>Something went wrong</p>
        <p style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16 }}>{error}</p>
        <button className="btn-primary" onClick={() => { setError(null); loadData() }}>Retry</button>
      </div>
    )
  }

  return (
    <div className="screen alerts-screen">
      {/* Monitored Sounds */}
      <div className="section">
        <h3 className="section-title">Monitored Sounds</h3>
        <div className="sound-toggles">
          {monitoredSounds.map((sound) => (
            <div
              key={sound.type}
              className={`toggle-item ${sound.type === 'fire-alarm' ? 'locked' : ''}`}
            >
              <div className="toggle-label">
                <span className="toggle-icon">{soundTypeMap[sound.type] || '📢'}</span>
                <span className="toggle-name">{sound.label}</span>
              </div>
              <input
                type="checkbox"
                className="toggle-switch"
                checked={sound.isEnabled}
                onChange={() => handleToggleSound(sound.type, sound.isEnabled)}
                disabled={sound.type === 'fire-alarm'}
              />
            </div>
          ))}
        </div>
      </div>

      {/* Context Rules */}
      <div className="section">
        <h3 className="section-title">Context Rules</h3>
        <div className="rules-grid">
          {contextRules.map((rule) => (
            <div
              key={rule.id}
              className={`rule-card ${rule.isActive ? 'active' : 'standby'}`}
              onClick={() => handleToggleRule(rule.id, rule.isActive)}
            >
              <div className="rule-icon">{getContextRuleIcon(rule)}</div>
              <div className="rule-header">
                <h4 className="rule-title">{rule.title}</h4>
                <span className={`rule-badge ${rule.isActive ? 'active' : 'standby'}`}>
                  {rule.isActive ? 'Active' : 'Standby'}
                </span>
              </div>
              <p className="rule-description">{rule.description}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Alert History */}
      {alerts.length > 0 && (
        <div className="section">
          <h3 className="section-title">Alert History</h3>
          <div className="alert-history">
            {alerts.map((alert) => (
              <div key={alert.id} className="alert-history-item">
                <div className="alert-header">
                  <span className="alert-type">{alert.type}</span>
                  <span className="alert-confidence">{Math.round(alert.confidence * 100)}%</span>
                </div>
                <p className="alert-reasoning">{alert.contextReasoning}</p>
                <div className="alert-meta">
                  <span className="alert-time">{new Date(alert.timestamp).toLocaleTimeString()}</span>
                  <span className={`status-badge ${alert.delivered ? 'delivered' : 'suppressed'}`}>
                    {alert.delivered ? '✓ Delivered' : '✗ Suppressed'}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
