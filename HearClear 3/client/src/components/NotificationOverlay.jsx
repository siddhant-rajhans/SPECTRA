import React, { useContext } from 'react'
import { AppContext } from '../context/AppContext'

export function NotificationOverlay() {
  const { notification, hideNotification, setActiveTab } = useContext(AppContext)

  if (!notification) {
    return null
  }

  const handleWasThisRight = () => {
    setActiveTab(3) // Navigate to Train AI tab
    hideNotification()
  }

  const iconMap = {
    doorbell: '🔔',
    'fire-alarm': '🚨',
    'car-horn': '🚗',
    name: '👤',
    timer: '⏱️',
    baby: '👶'
  }

  const icon = iconMap[notification.type] || '📢'

  return (
    <div className="notification-overlay">
      <div className="notification-popup">
        <div className="notification-icon-container">
          <span className="notification-icon">{icon}</span>
        </div>
        <div className="notification-content">
          <h3 className="notification-title">{notification.title}</h3>
          <p className="notification-description">{notification.description}</p>
          {notification.contextReasoning && (
            <p className="notification-reasoning">
              <strong>Why:</strong> {notification.contextReasoning}
            </p>
          )}
        </div>
        <div className="notification-buttons">
          <button className="btn-secondary" onClick={hideNotification}>
            Dismiss
          </button>
          <button className="btn-primary" onClick={handleWasThisRight}>
            Was this right?
          </button>
        </div>
      </div>
    </div>
  )
}
