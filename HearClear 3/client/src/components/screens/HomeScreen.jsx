import React, { useState, useEffect, useContext } from 'react'
import { fetchDeviceStatus, fetchAlerts, simulateAlert } from '../../services/api'
import { isAudioSupported, startListening, stopListening, getIsListening, onNoiseLevel, onSoundDetected, isModelReady } from '../../services/audioService'
import { AppContext } from '../../context/AppContext'

const ALERT_LABELS = {
  doorbell: 'Doorbell', 'fire-alarm': 'Fire Alarm', 'car-horn': 'Car Horn',
  name: 'Name Called', name_called: 'Name Called', timer: 'Timer / Alarm',
  alarm_timer: 'Timer / Alarm', baby: 'Baby Crying', baby_crying: 'Baby Crying',
  phone_ring: 'Phone Ring', knock: 'Door Knock', siren: 'Siren',
  dog_bark: 'Dog Bark', smoke_detector: 'Smoke Alarm', glass_breaking: 'Glass Break'
}

const ALERT_ICONS = {
  doorbell: '🔔', 'fire-alarm': '🚨', fire_alarm: '🚨', 'car-horn': '🚗', car_horn: '🚗',
  name: '👤', name_called: '👤', timer: '⏱️', alarm_timer: '⏱️',
  baby: '👶', baby_crying: '👶', phone_ring: '📱', knock: '🚪',
  siren: '🚑', dog_bark: '🐕', smoke_detector: '🔥', glass_breaking: '💎'
}

function formatLabel(type) {
  return ALERT_LABELS[type] || type.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}

export function HomeScreen() {
  const { showNotification, setActiveTab } = useContext(AppContext)
  const [deviceStatus, setDeviceStatus] = useState(null)
  const [alerts, setAlerts] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const [monitoring, setMonitoring] = useState(false)
  const [dbLevel, setDbLevel] = useState(0)
  const [mlReady, setMlReady] = useState(false)
  const [detectedSounds, setDetectedSounds] = useState([])
  const audioSupported = isAudioSupported()

  useEffect(() => {
    loadData()
    return () => { if (getIsListening()) stopListening() }
  }, [])

  useEffect(() => {
    onNoiseLevel((data) => {
      setDbLevel(data.dbLevel)
      if (data.modelReady !== undefined) setMlReady(data.modelReady)
    })
    onSoundDetected((event) => {
      setDetectedSounds(prev => [event, ...prev].slice(0, 20))
      showNotification({
        type: event.type,
        title: `${ALERT_ICONS[event.type] || '🔊'} ${formatLabel(event.type)}`,
        description: `${Math.round(event.confidence * 100)}% · ${event.dbLevel}dB · ${event.method === 'yamnet' ? 'ML' : 'Heuristic'}`,
        contextReasoning: event.priority === 'critical' ? 'CRITICAL — Immediate attention needed' : 'Detected via real-time audio analysis'
      })
    })
  }, [showNotification])

  async function loadData() {
    try {
      setLoading(true)
      const [deviceData, alertsData] = await Promise.all([fetchDeviceStatus(), fetchAlerts()])
      setDeviceStatus(deviceData)
      setAlerts(alertsData.slice(0, 3))
    } catch (err) { setError(err.message) }
    finally { setLoading(false) }
  }

  async function handleToggleMonitoring() {
    if (monitoring) {
      stopListening(); setMonitoring(false); setDbLevel(0)
    } else {
      try { await startListening(); setMonitoring(true) }
      catch (err) { setError(err.message) }
    }
  }

  const handleTestAlert = async () => {
    try {
      await simulateAlert('doorbell')
      showNotification({ type: 'doorbell', title: '🔔 Doorbell Detected', description: 'Someone is at your door', contextReasoning: 'Context-aware delivery test' })
      const alertsData = await fetchAlerts()
      setAlerts(alertsData.slice(0, 3))
    } catch (err) { console.error('Failed to simulate alert:', err) }
  }

  const getBatteryColor = (level) => level > 50 ? 'var(--success)' : level > 25 ? 'var(--warning)' : 'var(--danger)'
  const getNoiseColor = () => dbLevel > 80 ? '#EF4444' : dbLevel > 60 ? '#F59E0B' : '#10B981'
  const getNoiseLabel = () => dbLevel >= 80 ? 'Very Loud' : dbLevel >= 65 ? 'Loud' : dbLevel >= 50 ? 'Moderate' : dbLevel >= 30 ? 'Quiet' : 'Silent'

  const priorityColors = { critical: '#EF4444', high: '#F59E0B', medium: '#3B82F6', low: '#6B7280' }

  if (loading) {
    return (
      <div className="screen home-screen">
        {[1, 2, 3].map(i => (
          <div key={i} style={{
            height: i === 1 ? 90 : 60, borderRadius: 16, marginBottom: 10,
            background: 'linear-gradient(90deg, var(--bg) 25%, var(--bg-card-hover) 50%, var(--bg) 75%)',
            backgroundSize: '200% 100%', animation: 'shimmer 1.5s infinite'
          }}></div>
        ))}
      </div>
    )
  }

  if (error && !deviceStatus) {
    return (
      <div className="screen home-screen" style={{ justifyContent: 'center', alignItems: 'center' }}>
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--danger)" strokeWidth="1.5"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        <p style={{ fontSize: 15, fontWeight: 600, marginTop: 12, marginBottom: 4 }}>Connection Error</p>
        <p style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16 }}>{error}</p>
        <button className="btn-primary" onClick={loadData}>Retry</button>
      </div>
    )
  }

  return (
    <div className="screen home-screen">
      {/* Sound Monitor Card */}
      <div role="region" aria-label="Sound Monitoring" style={{
        background: monitoring
          ? 'linear-gradient(135deg, #ECFDF5 0%, #F0FDFA 100%)'
          : 'var(--bg-card)',
        border: monitoring ? '1px solid rgba(16,185,129,0.2)' : '1px solid var(--border)',
        padding: '14px 16px', borderRadius: 16,
        boxShadow: 'var(--shadow-sm)', transition: 'all 0.3s ease'
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 6 }}>
              {monitoring && <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#10B981', animation: 'livePulse 1.5s infinite', display: 'inline-block' }}></span>}
              {monitoring ? 'Live Monitoring' : 'Sound Monitor'}
            </div>
            <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 2 }}>
              {monitoring
                ? `${dbLevel} dB · ${getNoiseLabel()} · ${mlReady ? 'ML Active' : 'Heuristic'}`
                : 'Real-time sound detection & classification'}
            </div>
          </div>
          <button className={`btn-primary ${monitoring ? 'recording' : ''}`} onClick={handleToggleMonitoring}
            disabled={!audioSupported} style={{ padding: '8px 20px', fontSize: 13 }}>
            {monitoring ? '■ Stop' : '▶ Start'}
          </button>
        </div>

        {monitoring && (
          <div style={{ marginTop: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
              <div style={{ flex: 1, height: 6, background: 'rgba(0,0,0,0.05)', borderRadius: 3, overflow: 'hidden' }}>
                <div style={{ height: '100%', width: `${Math.min(dbLevel, 120) / 120 * 100}%`, background: getNoiseColor(), borderRadius: 3, transition: 'width 0.15s ease' }}></div>
              </div>
              <span style={{ fontSize: 11, fontWeight: 700, color: getNoiseColor(), minWidth: 38, textAlign: 'right' }}>{dbLevel} dB</span>
            </div>
            <div style={{ display: 'flex', gap: 6 }}>
              <span style={{ padding: '2px 8px', borderRadius: 12, fontSize: 10, fontWeight: 600,
                background: mlReady ? 'rgba(16,185,129,0.1)' : 'rgba(245,158,11,0.1)',
                color: mlReady ? '#10B981' : '#F59E0B' }}>
                {mlReady ? 'YAMNet ML' : 'Heuristic'}
              </span>
              <span style={{ padding: '2px 8px', borderRadius: 12, fontSize: 10, fontWeight: 600, background: 'rgba(99,102,241,0.08)', color: '#6366F1' }}>521 Classes</span>
            </div>
          </div>
        )}
      </div>

      {/* Detected Sounds */}
      {detectedSounds.length > 0 && (
        <div>
          <h3 className="section-title">Detected Sounds</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginTop: 8 }}>
            {detectedSounds.slice(0, 3).map((sound, idx) => (
              <div key={idx} style={{
                display: 'flex', alignItems: 'center', gap: 10,
                padding: '10px 14px', background: 'var(--bg-card)', borderRadius: 12,
                border: '1px solid var(--border)',
                borderLeft: `3px solid ${priorityColors[sound.priority] || 'var(--border)'}`,
                boxShadow: 'var(--shadow-xs)',
                animation: idx === 0 ? 'fadeIn 0.3s ease' : 'none'
              }}>
                <span style={{ fontSize: 16 }}>{ALERT_ICONS[sound.type] || '🔊'}</span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 600 }}>{formatLabel(sound.label || sound.type)}</div>
                  <div style={{ fontSize: 11, color: 'var(--text-secondary)' }}>
                    {Math.round(sound.confidence * 100)}% · {sound.dbLevel} dB · {sound.method === 'yamnet' ? 'ML' : 'Heuristic'}
                  </div>
                </div>
                <span style={{
                  padding: '2px 6px', borderRadius: 8, fontSize: 9, fontWeight: 700,
                  textTransform: 'uppercase', letterSpacing: 0.5,
                  background: `${priorityColors[sound.priority]}12`, color: priorityColors[sound.priority]
                }}>{sound.priority}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Device Status */}
      {deviceStatus && (
        <div style={{
          display: 'flex', alignItems: 'center', gap: 12,
          background: 'var(--bg-card)', border: '1px solid var(--border)',
          borderRadius: 14, padding: '12px 16px',
          boxShadow: 'var(--shadow-sm)'
        }}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" strokeWidth="2" strokeLinecap="round">
            <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"/>
            <path d="M19 10v2a7 7 0 0 1-14 0v-2"/>
          </svg>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, fontWeight: 600 }}>{deviceStatus.name || 'Hearing Device'}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
              <div style={{ flex: 1, height: 5, background: 'rgba(0,0,0,0.04)', borderRadius: 3, overflow: 'hidden' }}>
                <div style={{ height: '100%', width: `${deviceStatus.battery}%`, background: getBatteryColor(deviceStatus.battery), borderRadius: 3 }}></div>
              </div>
              <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-secondary)' }}>{deviceStatus.battery}%</span>
            </div>
          </div>
          <span style={{
            padding: '3px 10px', borderRadius: 20, fontSize: 10, fontWeight: 600,
            background: deviceStatus.connected ? 'rgba(34,197,94,0.08)' : 'rgba(239,68,68,0.08)',
            color: deviceStatus.connected ? '#22C55E' : '#EF4444'
          }}>{deviceStatus.connected ? 'Connected' : 'Offline'}</span>
        </div>
      )}

      {/* Quick Actions */}
      <div>
        <h3 className="section-title">Quick Actions</h3>
        <div className="actions-grid" style={{ marginTop: 8 }}>
          {[
            { label: 'Alerts', tab: 1, icon: <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" strokeWidth="1.8" strokeLinecap="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg> },
            { label: 'Transcribe', tab: 2, icon: <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--secondary)" strokeWidth="1.8" strokeLinecap="round"><path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="22"/></svg> },
            { label: 'Train AI', tab: 3, icon: <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" strokeWidth="1.8" strokeLinecap="round"><path d="M12 2L2 7l10 5 10-5-10-5z"/><path d="M2 17l10 5 10-5"/><path d="M2 12l10 5 10-5"/></svg> },
            { label: 'Test Alert', action: handleTestAlert, icon: <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#F59E0B" strokeWidth="1.8" strokeLinecap="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg> }
          ].map((item, idx) => (
            <button key={idx} className="action-card"
              onClick={item.action || (() => setActiveTab(item.tab))}
              aria-label={item.label}>
              <span className="action-icon" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{item.icon}</span>
              <p>{item.label}</p>
            </button>
          ))}
        </div>
      </div>

      {/* Context Pipeline */}
      <div>
        <h3 className="section-title">Context-Aware Pipeline</h3>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '12px 10px', background: 'var(--bg-card)', borderRadius: 14,
          border: '1px solid var(--border)', boxShadow: 'var(--shadow-xs)', marginTop: 8
        }}>
          {[
            { icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/></svg>, label: 'Listen', color: '#6366F1' },
            { icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 2L2 7l10 5 10-5-10-5z"/><path d="M2 17l10 5 10-5"/></svg>, label: 'Classify', color: '#8B5CF6' },
            { icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="10" r="3"/><path d="M12 21.7C17.3 17 20 13 20 10a8 8 0 0 0-16 0c0 3 2.7 7 8 11.7z"/></svg>, label: 'Context', color: '#0EA5E9' },
            { icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/></svg>, label: 'Filter', color: '#14B8A6' },
            { icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>, label: 'Alert', color: '#F97316' }
          ].map((step, idx) => (
            <React.Fragment key={idx}>
              {idx > 0 && <div style={{ width: 1, height: 20, background: 'var(--border-medium)', flexShrink: 0 }}></div>}
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, flex: 1 }}>
                <div style={{
                  width: 32, height: 32, borderRadius: 10,
                  background: `${step.color}10`, color: step.color,
                  display: 'flex', alignItems: 'center', justifyContent: 'center'
                }}>{step.icon}</div>
                <span style={{ fontSize: 10, fontWeight: 600, color: 'var(--text-secondary)' }}>{step.label}</span>
              </div>
            </React.Fragment>
          ))}
        </div>
      </div>

      {/* Recent Alerts */}
      {alerts.length > 0 && (
        <div>
          <h3 className="section-title">Recent Alerts</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginTop: 8 }}>
            {alerts.map((alert) => (
              <div key={alert.id} style={{
                display: 'flex', alignItems: 'center', gap: 12,
                background: 'var(--bg-card)', border: '1px solid var(--border)',
                borderRadius: 12, padding: '12px 14px', boxShadow: 'var(--shadow-xs)'
              }}>
                <span style={{ fontSize: 18 }}>{ALERT_ICONS[alert.type] || '📢'}</span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: 14, fontWeight: 600 }}>{formatLabel(alert.type)}</span>
                    <span style={{ fontSize: 11, color: 'var(--text-tertiary)' }}>
                      {alert.timestamp ? new Date(alert.timestamp).toLocaleTimeString() : ''}
                    </span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 2 }}>
                    <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                      {alert.contextReasoning || 'Context-aware processing'}
                    </span>
                    <span style={{
                      fontSize: 10, fontWeight: 600, padding: '2px 8px', borderRadius: 12,
                      background: alert.delivered ? 'rgba(34,197,94,0.08)' : 'rgba(239,68,68,0.08)',
                      color: alert.delivered ? '#22C55E' : '#EF4444'
                    }}>{alert.delivered ? '✓ Delivered' : '✗ Suppressed'}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
