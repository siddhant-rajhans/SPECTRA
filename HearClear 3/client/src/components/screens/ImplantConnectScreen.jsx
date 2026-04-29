import React, { useState, useEffect } from 'react'
import {
  fetchImplantProviders,
  fetchConnectedImplants,
  connectImplant,
  disconnectImplant,
  syncImplant
} from '../../services/api'
import {
  isBluetoothSupported,
  scanForDevices,
  scanAllDevices,
  connectToDevice,
  disconnectDevice,
  detectProvider,
  onBatteryChange,
  onDisconnect,
  onReconnecting,
  onConnectionState,
  ConnectionState,
  getConnectionState,
  isDeviceConnected,
  setVolume,
  getPairingInstructions,
  getProviderFeatures
} from '../../services/bluetoothService'

const PROVIDER_LOGOS = {
  'Cochlear': '🎧', 'Phonak': '👂', 'Oticon': '🔊', 'ReSound': '📡',
  'Starkey': '🌟', 'Widex': '💫', 'MED-EL': '🏥', 'Signia': '🔉',
  'Bernafon': '🎶', 'Unitron': '🎵', 'Other': '🔌'
}

export function ImplantConnectScreen({ onBack }) {
  const [providers, setProviders] = useState([])
  const [connected, setConnected] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [syncing, setSyncing] = useState({})

  // Bluetooth state
  const [bleSupported] = useState(isBluetoothSupported())
  const [connectionState, setConnectionState] = useState(getConnectionState())
  const [bleInfo, setBleInfo] = useState(null)
  const [reconnectInfo, setReconnectInfo] = useState(null)

  // Pairing flow
  const [pairingStep, setPairingStep] = useState(null) // null | 'select-provider' | 'instructions' | 'scanning'
  const [selectedBrand, setSelectedBrand] = useState(null)

  useEffect(() => {
    loadData()
  }, [])

  useEffect(() => {
    onConnectionState((state) => setConnectionState(state))
    onBatteryChange((level) => {
      setBleInfo(prev => prev ? { ...prev, battery: level } : prev)
    })
    onDisconnect(() => {
      setBleInfo(null)
      setReconnectInfo(null)
    })
    onReconnecting((attempt, max) => {
      setReconnectInfo({ attempt, max })
    })
  }, [])

  async function loadData() {
    try {
      setLoading(true)
      const [providersData, connectedData] = await Promise.all([
        fetchImplantProviders(),
        fetchConnectedImplants()
      ])
      setProviders(providersData)
      setConnected(connectedData)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const getBatteryColor = (b) => b > 50 ? '#10B981' : b > 25 ? '#F59E0B' : '#EF4444'
  const getBatteryIcon = (b) => b > 75 ? '🔋' : b > 25 ? '🪫' : '⚠️'

  // ── Pairing Flow ──
  function startPairing() {
    setPairingStep('select-provider')
    setError(null)
  }

  function selectBrand(brand) {
    setSelectedBrand(brand)
    setPairingStep('instructions')
  }

  async function startBleScan(allDevices = false) {
    setPairingStep('scanning')
    setError(null)
    try {
      const device = allDevices ? await scanAllDevices() : await scanForDevices()
      const info = await connectToDevice(device)
      setBleInfo(info)
      setPairingStep(null)
      setSelectedBrand(null)

      // Register in backend
      const provider = detectProvider(device.name)
      try {
        const providerObj = providers.find(p => p.name === provider)
        await connectImplant({
          providerId: providerObj?.id || 'cochlear',
          displayName: info.name,
          deviceModel: info.model || device.name
        })
        const updatedConnected = await fetchConnectedImplants()
        setConnected(updatedConnected)
      } catch (e) {
        console.log('Backend registration skipped:', e.message)
      }
    } catch (err) {
      setError(err.message)
      setPairingStep('instructions')
    }
  }

  function cancelPairing() {
    setPairingStep(null)
    setSelectedBrand(null)
    setError(null)
  }

  function handleBleDisconnect() {
    disconnectDevice()
    setBleInfo(null)
  }

  const handleDisconnect = async (id) => {
    if (!confirm('Remove this device?')) return
    try {
      await disconnectImplant(id)
      setConnected(connected.filter(c => c.id !== id))
    } catch (err) {
      setError(err.message)
    }
  }

  const handleSync = async (id) => {
    setSyncing(prev => ({ ...prev, [id]: true }))
    try {
      await syncImplant(id)
      const updatedConnected = await fetchConnectedImplants()
      setConnected(updatedConnected)
    } catch (err) {
      setError(err.message)
    } finally {
      setSyncing(prev => ({ ...prev, [id]: false }))
    }
  }

  const brands = ['Cochlear', 'Phonak', 'Oticon', 'ReSound', 'Starkey', 'Widex', 'MED-EL', 'Signia']

  if (loading && providers.length === 0) {
    return (
      <div className="screen">
        <button className="implant-back-btn" onClick={onBack}>← Back</button>
        <div style={{ textAlign: 'center', padding: 40 }}>
          <div className="loading-spinner"></div>
          <p style={{ color: 'var(--text-secondary)', marginTop: 12, fontSize: 13 }}>Loading devices...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="screen">
      <button className="implant-back-btn" onClick={onBack}>← Back</button>

      <div style={{ paddingBottom: 12 }}>
        <h2 style={{ fontSize: 20, fontWeight: 700, margin: '0 0 4px' }}>Implant Connection</h2>
        <p style={{ fontSize: 13, color: 'var(--text-secondary)', margin: 0 }}>
          Pair your hearing device via Bluetooth ASHA protocol
        </p>
      </div>

      {error && (
        <div style={{
          display: 'flex', alignItems: 'flex-start', gap: 10,
          padding: '12px 14px', borderRadius: 12, marginBottom: 8,
          background: error.includes('cancelled') || error.includes('No device') || error.includes('select')
            ? 'rgba(99,102,241,0.05)' : 'rgba(239,68,68,0.06)',
          border: error.includes('cancelled') || error.includes('No device') || error.includes('select')
            ? '1px solid rgba(99,102,241,0.12)' : '1px solid rgba(239,68,68,0.12)'
        }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
            stroke={error.includes('cancelled') || error.includes('No device') || error.includes('select') ? 'var(--primary)' : '#DC2626'}
            strokeWidth="2" strokeLinecap="round" style={{ flexShrink: 0, marginTop: 1 }}>
            <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
          </svg>
          <p style={{
            fontSize: 13, margin: 0, lineHeight: 1.5,
            color: error.includes('cancelled') || error.includes('No device') || error.includes('select')
              ? 'var(--text-secondary)' : '#DC2626'
          }}>
            {error.includes('cancelled') ? 'Bluetooth pairing was cancelled. Tap "Scan Hearing Aids" to try again.'
              : error.includes('No device') || error.includes('select')
              ? 'No device selected. Follow the pairing steps above, then tap "Scan Hearing Aids" to connect.'
              : error}
          </p>
        </div>
      )}

      {/* ── Reconnecting Banner ── */}
      {connectionState === ConnectionState.RECONNECTING && reconnectInfo && (
        <div style={{
          padding: '10px 14px', borderRadius: 10, marginBottom: 12,
          background: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.15)',
          fontSize: 13, color: '#D97706', display: 'flex', alignItems: 'center', gap: 8
        }}>
          <span className="loading-spinner" style={{ width: 16, height: 16 }}></span>
          Reconnecting... (attempt {reconnectInfo.attempt}/{reconnectInfo.max})
        </div>
      )}

      {/* ══════════ PAIRING FLOW ══════════ */}
      {pairingStep === 'select-provider' && (
        <div style={{
          background: 'var(--bg-card)', borderRadius: 16, padding: 20,
          border: '1px solid var(--border)', marginBottom: 16
        }}>
          <h3 style={{ fontSize: 15, fontWeight: 600, margin: '0 0 4px' }}>Select Your Device Brand</h3>
          <p style={{ fontSize: 12, color: 'var(--text-secondary)', margin: '0 0 16px' }}>
            We'll show you brand-specific pairing instructions
          </p>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8 }}>
            {brands.map(brand => (
              <button
                key={brand}
                onClick={() => selectBrand(brand)}
                style={{
                  display: 'flex', alignItems: 'center', gap: 8,
                  padding: '12px 14px', borderRadius: 12,
                  background: 'var(--bg)', border: '1px solid var(--border)',
                  cursor: 'pointer', fontSize: 13, fontWeight: 500,
                  transition: 'all 0.15s'
                }}
              >
                <span style={{ fontSize: 18 }}>{PROVIDER_LOGOS[brand]}</span>
                {brand}
              </button>
            ))}
          </div>

          <button
            onClick={cancelPairing}
            style={{
              marginTop: 12, width: '100%', padding: 10, borderRadius: 10,
              background: 'none', border: '1px solid var(--border)',
              color: 'var(--text-secondary)', fontSize: 13, cursor: 'pointer'
            }}
          >Cancel</button>
        </div>
      )}

      {pairingStep === 'instructions' && selectedBrand && (
        <div style={{
          background: 'var(--bg-card)', borderRadius: 16, padding: 20,
          border: '1px solid var(--border)', marginBottom: 16
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}>
            <span style={{ fontSize: 28 }}>{PROVIDER_LOGOS[selectedBrand]}</span>
            <div>
              <h3 style={{ fontSize: 15, fontWeight: 600, margin: 0 }}>Pair {selectedBrand} Device</h3>
              <p style={{ fontSize: 12, color: 'var(--text-secondary)', margin: 0 }}>Follow these steps</p>
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 16 }}>
            {getPairingInstructions(selectedBrand).map((step, idx) => (
              <div key={idx} style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
                <span style={{
                  width: 22, height: 22, borderRadius: '50%', flexShrink: 0,
                  background: 'var(--primary)', color: '#fff', fontSize: 11,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontWeight: 700
                }}>{idx + 1}</span>
                <p style={{ fontSize: 13, color: 'var(--text-primary)', margin: 0, lineHeight: 1.4 }}>{step}</p>
              </div>
            ))}
          </div>

          {/* Supported features */}
          <div style={{ marginBottom: 16 }}>
            <p style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)', margin: '0 0 6px', textTransform: 'uppercase', letterSpacing: 0.5 }}>
              Supported Features
            </p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
              {getProviderFeatures(selectedBrand).map((feat, idx) => (
                <span key={idx} style={{
                  padding: '3px 10px', borderRadius: 20, fontSize: 11,
                  background: 'rgba(59,130,246,0.08)', color: 'var(--primary)', fontWeight: 500
                }}>{feat}</span>
              ))}
            </div>
          </div>

          <div style={{ display: 'flex', gap: 8 }}>
            <button
              className="btn-primary"
              onClick={() => startBleScan(false)}
              style={{ flex: 1, padding: 12, fontSize: 14 }}
            >🔍 Scan Hearing Aids</button>
            <button
              className="btn-secondary"
              onClick={() => startBleScan(true)}
              style={{ padding: '12px 14px', fontSize: 13 }}
            >All</button>
          </div>

          <button
            onClick={() => setPairingStep('select-provider')}
            style={{
              marginTop: 8, width: '100%', padding: 8,
              background: 'none', border: 'none',
              color: 'var(--text-secondary)', fontSize: 12, cursor: 'pointer'
            }}
          >← Choose a different brand</button>
        </div>
      )}

      {pairingStep === 'scanning' && (
        <div style={{
          background: 'var(--bg-card)', borderRadius: 16, padding: 32,
          border: '1px solid var(--border)', marginBottom: 16, textAlign: 'center'
        }}>
          <div className="loading-spinner" style={{ margin: '0 auto 16px' }}></div>
          <p style={{ fontSize: 14, fontWeight: 600, margin: '0 0 4px' }}>
            {connectionState === ConnectionState.SCANNING ? 'Scanning for devices...' :
             connectionState === ConnectionState.CONNECTING ? 'Connecting...' :
             connectionState === ConnectionState.READING_SERVICES ? 'Reading device info...' :
             'Preparing...'}
          </p>
          <p style={{ fontSize: 12, color: 'var(--text-secondary)', margin: 0 }}>
            Make sure your device is in pairing mode
          </p>
        </div>
      )}

      {/* ══════════ CONNECTED BLE DEVICE ══════════ */}
      {bleInfo && !pairingStep && (
        <div style={{
          background: 'var(--bg-card)', borderRadius: 16, padding: 16,
          border: '1px solid rgba(16,185,129,0.2)', marginBottom: 16,
          boxShadow: '0 0 0 1px rgba(16,185,129,0.05)'
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
            <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              <span style={{ fontSize: 28 }}>{PROVIDER_LOGOS[bleInfo.provider] || '🔌'}</span>
              <div>
                <div style={{ fontSize: 15, fontWeight: 600 }}>{bleInfo.name}</div>
                <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
                  {bleInfo.manufacturer || bleInfo.provider} {bleInfo.model ? `· ${bleInfo.model}` : ''}
                </div>
              </div>
            </div>
            <span style={{
              padding: '3px 10px', borderRadius: 20, fontSize: 11, fontWeight: 600,
              background: 'rgba(16,185,129,0.1)', color: '#10B981'
            }}>Connected</span>
          </div>

          {/* Battery */}
          {bleInfo.battery !== null && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
              <span style={{ fontSize: 14 }}>{getBatteryIcon(bleInfo.battery)}</span>
              <div style={{ flex: 1, height: 8, background: 'var(--bg)', borderRadius: 4, overflow: 'hidden' }}>
                <div style={{
                  height: '100%', width: `${bleInfo.battery}%`,
                  background: getBatteryColor(bleInfo.battery), borderRadius: 4,
                  transition: 'width 0.3s ease'
                }}></div>
              </div>
              <span style={{ fontSize: 13, fontWeight: 600, minWidth: 36, textAlign: 'right' }}>{bleInfo.battery}%</span>
            </div>
          )}

          {/* ASHA Info */}
          {bleInfo.hasASHA && (
            <div style={{
              padding: '8px 12px', borderRadius: 8, marginBottom: 10,
              background: 'rgba(59,130,246,0.06)', border: '1px solid rgba(59,130,246,0.1)'
            }}>
              <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--primary)', marginBottom: 4 }}>
                ASHA Protocol Active
              </div>
              {bleInfo.ashaProperties && (
                <div style={{ fontSize: 11, color: 'var(--text-secondary)', lineHeight: 1.5 }}>
                  Side: {bleInfo.ashaProperties.side} ·
                  {bleInfo.ashaProperties.binaural ? ' Binaural' : ' Monaural'} ·
                  {bleInfo.ashaProperties.codecs?.join(', ')}
                </div>
              )}
            </div>
          )}

          {/* Device Details */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6, marginBottom: 10 }}>
            {bleInfo.firmware && (
              <div style={{ fontSize: 11, color: 'var(--text-tertiary)' }}>
                <span style={{ fontWeight: 600 }}>Firmware:</span> {bleInfo.firmware}
              </div>
            )}
            {bleInfo.hardware && (
              <div style={{ fontSize: 11, color: 'var(--text-tertiary)' }}>
                <span style={{ fontWeight: 600 }}>Hardware:</span> {bleInfo.hardware}
              </div>
            )}
            {bleInfo.serial && (
              <div style={{ fontSize: 11, color: 'var(--text-tertiary)' }}>
                <span style={{ fontWeight: 600 }}>Serial:</span> {bleInfo.serial}
              </div>
            )}
            {bleInfo.hasVolumeControl && bleInfo.volume !== null && (
              <div style={{ fontSize: 11, color: 'var(--text-tertiary)' }}>
                <span style={{ fontWeight: 600 }}>Volume:</span> {bleInfo.volume}
              </div>
            )}
          </div>

          {/* Services */}
          {(bleInfo.hasASHA || bleInfo.hasHAS) && (
            <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap', marginBottom: 10 }}>
              {bleInfo.hasASHA && <span style={{ padding: '2px 8px', borderRadius: 12, fontSize: 10, background: 'rgba(16,185,129,0.1)', color: '#10B981', fontWeight: 600 }}>ASHA</span>}
              {bleInfo.hasHAS && <span style={{ padding: '2px 8px', borderRadius: 12, fontSize: 10, background: 'rgba(99,102,241,0.1)', color: '#6366F1', fontWeight: 600 }}>HAS</span>}
              {bleInfo.hasVolumeControl && <span style={{ padding: '2px 8px', borderRadius: 12, fontSize: 10, background: 'rgba(245,158,11,0.1)', color: '#F59E0B', fontWeight: 600 }}>Volume Control</span>}
            </div>
          )}

          <button
            onClick={handleBleDisconnect}
            style={{
              width: '100%', padding: 10, borderRadius: 10,
              border: '1px solid rgba(239,68,68,0.2)', background: 'rgba(239,68,68,0.04)',
              color: '#EF4444', fontSize: 13, fontWeight: 500, cursor: 'pointer'
            }}
          >Disconnect Bluetooth</button>
        </div>
      )}

      {/* ══════════ PAIR NEW DEVICE BUTTON ══════════ */}
      {!pairingStep && !bleInfo && (
        <button
          onClick={startPairing}
          disabled={!bleSupported}
          style={{
            width: '100%', padding: 16, borderRadius: 16, marginBottom: 16,
            background: bleSupported ? 'linear-gradient(135deg, #3B82F6, #2563EB)' : 'var(--bg)',
            color: bleSupported ? '#fff' : 'var(--text-tertiary)',
            border: 'none', fontSize: 15, fontWeight: 600, cursor: bleSupported ? 'pointer' : 'not-allowed',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            boxShadow: bleSupported ? '0 4px 12px rgba(59,130,246,0.3)' : 'none'
          }}
        >
          📶 {bleSupported ? 'Pair Hearing Device via Bluetooth' : 'Bluetooth Not Supported'}
        </button>
      )}

      {!bleSupported && (
        <p style={{ fontSize: 12, color: 'var(--text-tertiary)', textAlign: 'center', margin: '-8px 0 12px' }}>
          Web Bluetooth requires Chrome on desktop or Android
        </p>
      )}

      {/* ══════════ REGISTERED DEVICES (Backend) ══════════ */}
      {connected.length > 0 && (
        <div style={{ marginBottom: 12 }}>
          <h3 className="section-title">Registered Devices</h3>
          {connected.map(device => (
            <div key={device.id} className="implant-connected-card">
              <div className="implant-card-header">
                <div className="implant-provider-icon" style={{ background: 'rgba(0,206,201,0.1)' }}>
                  {PROVIDER_LOGOS[device.providerName] || '🔌'}
                </div>
                <div className="implant-card-info">
                  <div className="implant-card-name">{device.displayName}</div>
                  <div className="implant-card-model">{device.providerName} · {device.deviceModel || 'Device'}</div>
                </div>
              </div>
              <div className="implant-battery-row">
                <span style={{ fontSize: 11, color: 'var(--text-secondary)' }}>Battery</span>
                <div className="implant-battery-bar">
                  <div className="implant-battery-fill" style={{
                    width: `${device.battery || 0}%`,
                    backgroundColor: getBatteryColor(device.battery || 0)
                  }}></div>
                </div>
                <div className="implant-battery-text">{device.battery || 0}%</div>
              </div>
              <div className="implant-meta">
                <span>Firmware v{device.firmwareVersion || 'N/A'}</span>
                <span>Synced {device.lastSynced ? new Date(device.lastSynced).toLocaleString() : 'Never'}</span>
              </div>
              <div className="implant-card-actions">
                <button className="implant-action-btn implant-sync-btn"
                  onClick={() => handleSync(device.id)} disabled={syncing[device.id]}>
                  {syncing[device.id] ? '⟳ Syncing...' : '⟳ Sync'}
                </button>
                <button className="implant-action-btn implant-disconnect-btn"
                  onClick={() => handleDisconnect(device.id)}>✕ Remove</button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* ══════════ SUPPORTED BRANDS ══════════ */}
      {!pairingStep && (
        <div style={{ marginTop: 4 }}>
          <h3 className="section-title">Supported Brands</h3>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, justifyContent: 'center' }}>
            {brands.map(brand => (
              <span key={brand} style={{
                display: 'flex', alignItems: 'center', gap: 4,
                padding: '5px 10px', background: 'var(--bg)', borderRadius: 20,
                fontSize: 11, color: 'var(--text-secondary)'
              }}>
                {PROVIDER_LOGOS[brand]} {brand}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
