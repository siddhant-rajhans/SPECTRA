import React, { createContext, useState, useCallback } from 'react'

export const AppContext = createContext()

export function AppContextProvider({ children }) {
  const [activeTab, setActiveTab] = useState(0)
  const [notification, setNotification] = useState(null)
  const [deviceStatus, setDeviceStatus] = useState(null)
  const [currentUser, setCurrentUser] = useState(null)

  const showNotification = useCallback((notificationData) => {
    setNotification(notificationData)
  }, [])

  const hideNotification = useCallback(() => {
    setNotification(null)
  }, [])

  const logout = useCallback(() => {
    setCurrentUser(null)
    setActiveTab(0)
  }, [])

  const isAuthenticated = !!currentUser

  const value = {
    activeTab,
    setActiveTab,
    notification,
    showNotification,
    hideNotification,
    deviceStatus,
    setDeviceStatus,
    currentUser,
    setCurrentUser,
    isAuthenticated,
    logout
  }

  return (
    <AppContext.Provider value={value}>
      {children}
    </AppContext.Provider>
  )
}
