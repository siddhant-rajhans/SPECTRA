import React, { useEffect, useContext, useState } from 'react'
import { AppContextProvider, AppContext } from './context/AppContext'
import { useWebSocket } from './hooks/useWebSocket'
import { fetchDeviceStatus, fetchProfile, setApiUserId } from './services/api'
import { PhoneFrame } from './components/PhoneFrame'
import { StatusBar } from './components/StatusBar'
import { TabBar } from './components/TabBar'
import { NotificationOverlay } from './components/NotificationOverlay'
import { AuthScreen } from './components/screens/AuthScreen'
import { HomeScreen } from './components/screens/HomeScreen'
import { AlertsScreen } from './components/screens/AlertsScreen'
import { TranscribeScreen } from './components/screens/TranscribeScreen'
import { IMLScreen } from './components/screens/IMLScreen'
import { EnvironmentScreen } from './components/screens/EnvironmentScreen'
import { ProfileScreen } from './components/screens/ProfileScreen'
import { ImplantConnectScreen } from './components/screens/ImplantConnectScreen'

function AppContent() {
  const { activeTab, showNotification, setDeviceStatus, isAuthenticated, setCurrentUser, currentUser } = useContext(AppContext)
  const { lastMessage, isConnected } = useWebSocket('/ws')
  const [showImplantConnect, setShowImplantConnect] = useState(false)

  // Fetch initial data
  useEffect(() => {
    async function loadInitialData() {
      try {
        const deviceData = await fetchDeviceStatus()
        setDeviceStatus(deviceData)
      } catch (err) {
        console.error('Failed to load initial data:', err)
      }
    }
    if (isAuthenticated) {
      loadInitialData()
    }
  }, [setDeviceStatus, isAuthenticated])

  // Listen for WebSocket alerts
  useEffect(() => {
    if (lastMessage && lastMessage.type === 'alert') {
      showNotification({
        type: lastMessage.soundType,
        title: `${lastMessage.icon || '📢'} ${lastMessage.title}`,
        description: lastMessage.description,
        contextReasoning: lastMessage.contextReasoning
      })
    }
  }, [lastMessage, showNotification])

  const handleLogin = (userData) => {
    // userData is { id, name, email, avatar_initial }
    if (userData && userData.id) {
      setApiUserId(userData.id)
    }
    setCurrentUser(userData)
  }

  const handleNavigateToImplants = () => {
    setShowImplantConnect(true)
  }

  const handleBackFromImplants = () => {
    setShowImplantConnect(false)
  }

  if (!isAuthenticated) {
    return (
      <PhoneFrame>
        <AuthScreen onLogin={handleLogin} />
      </PhoneFrame>
    )
  }

  const screens = [
    <HomeScreen key="home" />,
    <AlertsScreen key="alerts" />,
    <TranscribeScreen key="transcribe" />,
    <IMLScreen key="iml" />,
    <EnvironmentScreen key="environment" />,
    <ProfileScreen key="profile" onNavigateToImplants={handleNavigateToImplants} />
  ]

  return (
    <PhoneFrame>
      <StatusBar />
      {showImplantConnect ? (
        <ImplantConnectScreen onBack={handleBackFromImplants} />
      ) : (
        screens[activeTab]
      )}
      {!showImplantConnect && <TabBar />}
      <NotificationOverlay />
    </PhoneFrame>
  )
}

function App() {
  return (
    <AppContextProvider>
      <AppContent />
    </AppContextProvider>
  )
}

export default App
