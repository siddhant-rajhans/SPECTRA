import React, { useState, useEffect, useContext } from 'react'
import { fetchProfile, fetchDeviceStatus, fetchIMLStats } from '../../services/api'
import { AppContext } from '../../context/AppContext'

export function ProfileScreen({ onNavigateToImplants }) {
  const { logout } = useContext(AppContext)
  const [profile, setProfile] = useState(null)
  const [device, setDevice] = useState(null)
  const [imlStats, setImlStats] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => { loadData() }, [])

  async function loadData() {
    try {
      setLoading(true)
      const [profileData, deviceData, statsData] = await Promise.all([
        fetchProfile(), fetchDeviceStatus(), fetchIMLStats()
      ])
      setProfile(profileData)
      setDevice(deviceData)
      setImlStats(statsData)
    } catch (err) { setError(err.message) }
    finally { setLoading(false) }
  }

  if (loading) {
    return (
      <div className="screen profile-screen">
        {[1,2,3].map(i => (
          <div key={i} style={{
            height: i === 1 ? 90 : 70, borderRadius: 16, marginBottom: 12,
            background: 'linear-gradient(90deg, var(--bg) 25%, var(--bg-card-hover) 50%, var(--bg) 75%)',
            backgroundSize: '200% 100%', animation: 'shimmer 1.5s infinite'
          }}></div>
        ))}
      </div>
    )
  }

  if (error) {
    return (
      <div className="screen profile-screen" style={{ textAlign: 'center', paddingTop: 60 }}>
        <p style={{ fontSize: 15, color: 'var(--danger)', marginBottom: 12 }}>Error: {error}</p>
        <button className="btn-primary" onClick={loadData}>Retry</button>
      </div>
    )
  }

  const getInitial = (name) => name ? name.charAt(0).toUpperCase() : 'U'

  return (
    <div className="screen profile-screen">
      {/* Profile Header */}
      {profile && (
        <div className="profile-header">
          <div className="profile-avatar">
            {getInitial(profile.name)}
          </div>
          <div className="profile-info">
            <h2 className="profile-name">{profile.name}</h2>
            {device && <p className="profile-device">{device.name}</p>}
          </div>
        </div>
      )}

      {/* Device Settings */}
      <div className="settings-group">
        <h3 className="settings-group-title">Device</h3>
        <div className="settings-items">
          <div className="settings-item">
            <span className="settings-label">Battery</span>
            <span className="settings-value" style={{
              color: (device?.battery || 0) > 50 ? 'var(--success)' : (device?.battery || 0) > 25 ? 'var(--warning)' : 'var(--danger)'
            }}>{device?.battery || 0}%</span>
          </div>
          <div className="settings-item">
            <span className="settings-label">Bluetooth ASHA</span>
            <span className="settings-value" style={{ color: 'var(--success)' }}>Active</span>
          </div>
          {onNavigateToImplants && (
            <button className="settings-item" onClick={onNavigateToImplants}
              style={{ cursor: 'pointer', justifyContent: 'space-between', width: '100%', textAlign: 'left' }}>
              <span className="settings-label">Connect Implant</span>
              <span style={{ fontSize: 13, color: 'var(--primary)' }}>→</span>
            </button>
          )}
        </div>
      </div>

      {/* Smart Alerts */}
      <div className="settings-group">
        <h3 className="settings-group-title">Notifications</h3>
        <div className="settings-items">
          <div className="settings-item">
            <span className="settings-label">Sound Detection</span>
            <span className="settings-value" style={{ color: 'var(--success)' }}>On</span>
          </div>
          <div className="settings-item">
            <span className="settings-label">Flash Alerts</span>
            <span className="settings-value" style={{ color: 'var(--success)' }}>On</span>
          </div>
          <div className="settings-item">
            <span className="settings-label">Calendar Integration</span>
            <span className="settings-value" style={{ color: 'var(--success)' }}>On</span>
          </div>
        </div>
      </div>

      {/* ML */}
      <div className="settings-group">
        <h3 className="settings-group-title">Machine Learning</h3>
        <div className="settings-items">
          <div className="settings-item">
            <span className="settings-label">YAMNet Classifier</span>
            <span className="settings-value">521 classes</span>
          </div>
          <div className="settings-item">
            <span className="settings-label">SPECTRA Training</span>
            <span className="settings-value">{imlStats?.confirmed || 0} samples</span>
          </div>
          <div className="settings-item">
            <span className="settings-label">Personalization Score</span>
            <span className="settings-value" style={{ color: 'var(--primary)', fontWeight: 600 }}>85/100</span>
          </div>
        </div>
      </div>

      {/* Sign Out */}
      <button onClick={logout} style={{
        width: '100%', padding: 14, borderRadius: 12, marginTop: 8,
        background: 'none', border: '1px solid var(--border-medium)',
        color: 'var(--danger)', fontSize: 14, fontWeight: 500, cursor: 'pointer'
      }}>Sign Out</button>

      {/* Footer */}
      <div className="profile-footer">
        <p className="footer-text">Auralis v1.0.0</p>
        <p className="footer-subtext">Stevens Institute of Technology · CS545B</p>
      </div>
    </div>
  )
}
