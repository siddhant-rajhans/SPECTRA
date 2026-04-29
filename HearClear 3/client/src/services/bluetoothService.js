/**
 * Bluetooth Service — Production-grade Web Bluetooth integration
 * Implements ASHA (Audio Streaming for Hearing Aid) protocol
 * Supports Cochlear, Phonak, Oticon, ReSound, Starkey, Widex, Signia, MED-EL
 *
 * References:
 * - ASHA GATT Profile: https://source.android.com/docs/core/connect/bluetooth/asha
 * - Bluetooth SIG Hearing Aid Profile: HAS (Hearing Access Service) UUID 0x1854
 */

// ─── Known Hearing Device Name Prefixes ───
const KNOWN_PREFIXES = [
  'Cochlear', 'Nucleus', 'Baha', 'Kanso', 'Osia',
  'Phonak', 'Marvel', 'Lumity', 'Paradise', 'Bolero',
  'Oticon', 'More', 'Intent', 'Real', 'Xceed',
  'ReSound', 'Omnia', 'Nexia', 'ONE',
  'Starkey', 'Evolv', 'Genesis', 'Livio',
  'Widex', 'Moment', 'Magnolia', 'SmartRIC',
  'GN', 'Signia', 'Bernafon', 'Unitron', 'Sonic', 'Rexton',
  'MED-EL', 'RONDO', 'SONNET', 'AudioLink'
]

// ─── BLE Service & Characteristic UUIDs ───
const BLE_SERVICES = {
  BATTERY: 'battery_service',
  DEVICE_INFO: 'device_information',
  GENERIC_ACCESS: 'generic_access',
  ASHA: 0xFDF0,
  HEARING_ACCESS: 0x1854,
  VOLUME_CONTROL: 0x1844,
}

const DEVICE_INFO_CHARS = {
  MANUFACTURER: 'manufacturer_name_string',
  MODEL: 'model_number_string',
  FIRMWARE: 'firmware_revision_string',
  HARDWARE: 'hardware_revision_string',
  SOFTWARE: 'software_revision_string',
  SERIAL: 'serial_number_string',
  SYSTEM_ID: 'system_id',
}

// ASHA-specific characteristic UUIDs (from Android ASHA spec)
const ASHA_CHARS = {
  READ_ONLY_PROPERTIES: '6333651e-c481-4a3e-9169-7c902aad37bb',
  AUDIO_CONTROL_POINT: 'f0d4de7e-4a88-476c-9d9f-1937b0996cc0',
  AUDIO_STATUS: '38663f1a-e711-4cac-b641-326b56404837',
  VOLUME: '00e4ca9e-ab14-41e4-8823-f9e70c7e91df',
  LE_PSM_OUT: '2d410339-82b6-42aa-b34e-e2e01df8cc1a',
}

// ─── Connection State ───
let connectedDevice = null
let gattServer = null
let batteryCharacteristic = null
let ashaService = null
let volumeCharacteristic = null
let reconnectAttempts = 0
const MAX_RECONNECT_ATTEMPTS = 5
const RECONNECT_DELAY_MS = 2000

// ─── Callbacks ───
let onBatteryChangeCallback = null
let onDisconnectCallback = null
let onReconnectingCallback = null
let onConnectionStateCallback = null
let onVolumeChangeCallback = null

// ─── Connection States ───
export const ConnectionState = {
  DISCONNECTED: 'disconnected',
  SCANNING: 'scanning',
  CONNECTING: 'connecting',
  READING_SERVICES: 'reading_services',
  CONNECTED: 'connected',
  RECONNECTING: 'reconnecting',
  FAILED: 'failed'
}

let currentState = ConnectionState.DISCONNECTED

function setState(state) {
  currentState = state
  if (onConnectionStateCallback) onConnectionStateCallback(state)
}

export function isBluetoothSupported() {
  return !!(navigator.bluetooth)
}

export function getConnectionState() {
  return currentState
}

/**
 * Scan for hearing aid devices via Web Bluetooth
 */
export async function scanForDevices() {
  if (!isBluetoothSupported()) {
    throw new Error('Web Bluetooth is not supported. Use Chrome on desktop or Android.')
  }

  setState(ConnectionState.SCANNING)

  try {
    const filters = KNOWN_PREFIXES.map(prefix => ({ namePrefix: prefix }))
    const device = await navigator.bluetooth.requestDevice({
      filters,
      optionalServices: [
        BLE_SERVICES.BATTERY,
        BLE_SERVICES.DEVICE_INFO,
        BLE_SERVICES.GENERIC_ACCESS,
        BLE_SERVICES.ASHA,
        BLE_SERVICES.HEARING_ACCESS,
        BLE_SERVICES.VOLUME_CONTROL,
      ]
    })
    setState(ConnectionState.DISCONNECTED)
    return device
  } catch (err) {
    setState(ConnectionState.DISCONNECTED)
    if (err.name === 'NotFoundError') {
      throw new Error('No device selected. Please select your hearing device from the list.')
    }
    throw err
  }
}

/**
 * Scan for ANY Bluetooth device
 */
export async function scanAllDevices() {
  if (!isBluetoothSupported()) {
    throw new Error('Web Bluetooth is not supported. Use Chrome on desktop or Android.')
  }

  setState(ConnectionState.SCANNING)

  try {
    const device = await navigator.bluetooth.requestDevice({
      acceptAllDevices: true,
      optionalServices: [
        BLE_SERVICES.BATTERY,
        BLE_SERVICES.DEVICE_INFO,
        BLE_SERVICES.GENERIC_ACCESS,
        BLE_SERVICES.ASHA,
        BLE_SERVICES.HEARING_ACCESS,
        BLE_SERVICES.VOLUME_CONTROL,
      ]
    })
    setState(ConnectionState.DISCONNECTED)
    return device
  } catch (err) {
    setState(ConnectionState.DISCONNECTED)
    if (err.name === 'NotFoundError') throw new Error('No device selected.')
    throw err
  }
}

/**
 * Connect to a Bluetooth device — full ASHA handshake when available
 */
export async function connectToDevice(device) {
  setState(ConnectionState.CONNECTING)
  reconnectAttempts = 0

  try {
    gattServer = await device.gatt.connect()
    connectedDevice = device
    setState(ConnectionState.READING_SERVICES)

    const info = {
      name: device.name || 'Unknown Device',
      id: device.id,
      connected: true,
      battery: null,
      manufacturer: null,
      model: null,
      firmware: null,
      hardware: null,
      serial: null,
      provider: detectProvider(device.name),
      hasASHA: false,
      hasHAS: false,
      hasVolumeControl: false,
      volume: null,
      ashaProperties: null,
      services: [],
    }

    // Discover available services
    try {
      const servicesList = await gattServer.getPrimaryServices()
      info.services = servicesList.map(s => s.uuid)
    } catch (e) { /* some devices restrict enumeration */ }

    // ── Battery Service ──
    try {
      const batteryService = await gattServer.getPrimaryService(BLE_SERVICES.BATTERY)
      batteryCharacteristic = await batteryService.getCharacteristic('battery_level')
      const batteryValue = await batteryCharacteristic.readValue()
      info.battery = batteryValue.getUint8(0)

      batteryCharacteristic.addEventListener('characteristicvaluechanged', (event) => {
        const value = event.target.value.getUint8(0)
        if (onBatteryChangeCallback) onBatteryChangeCallback(value)
      })
      await batteryCharacteristic.startNotifications()
    } catch (e) {
      console.log('Battery service not available:', e.message)
    }

    // ── Device Information Service ──
    try {
      const deviceInfoService = await gattServer.getPrimaryService(BLE_SERVICES.DEVICE_INFO)
      for (const [key, uuid] of Object.entries(DEVICE_INFO_CHARS)) {
        try {
          const char = await deviceInfoService.getCharacteristic(uuid)
          const value = await char.readValue()
          const decoded = new TextDecoder().decode(value)
          switch (key) {
            case 'MANUFACTURER': info.manufacturer = decoded; break
            case 'MODEL': info.model = decoded; break
            case 'FIRMWARE': info.firmware = decoded; break
            case 'HARDWARE': info.hardware = decoded; break
            case 'SERIAL': info.serial = decoded; break
          }
        } catch (e) { /* characteristic not available */ }
      }
    } catch (e) {
      console.log('Device info service not available:', e.message)
    }

    // ── ASHA Service (0xFDF0) ──
    try {
      ashaService = await gattServer.getPrimaryService(BLE_SERVICES.ASHA)
      info.hasASHA = true

      try {
        const propChar = await ashaService.getCharacteristic(ASHA_CHARS.READ_ONLY_PROPERTIES)
        const propValue = await propChar.readValue()
        info.ashaProperties = parseASHAProperties(propValue)
      } catch (e) { console.log('ASHA properties not readable:', e.message) }

      try {
        const audioStatusChar = await ashaService.getCharacteristic(ASHA_CHARS.AUDIO_STATUS)
        audioStatusChar.addEventListener('characteristicvaluechanged', (event) => {
          console.log('ASHA Audio Status changed:', event.target.value.getUint8(0))
        })
        await audioStatusChar.startNotifications()
      } catch (e) { console.log('ASHA audio status not available:', e.message) }

      try {
        volumeCharacteristic = await ashaService.getCharacteristic(ASHA_CHARS.VOLUME)
        const volValue = await volumeCharacteristic.readValue()
        info.volume = volValue.getInt8(0)
        info.hasVolumeControl = true
      } catch (e) { console.log('ASHA volume not available:', e.message) }
    } catch (e) {
      console.log('ASHA service not available:', e.message)
    }

    // ── Hearing Access Service (0x1854) ──
    try {
      await gattServer.getPrimaryService(BLE_SERVICES.HEARING_ACCESS)
      info.hasHAS = true
    } catch (e) { /* HAS not available */ }

    // ── Volume Control Service (0x1844) ──
    if (!info.hasVolumeControl) {
      try {
        const vcs = await gattServer.getPrimaryService(BLE_SERVICES.VOLUME_CONTROL)
        try {
          volumeCharacteristic = await vcs.getCharacteristic(0x2B7D)
          const volValue = await volumeCharacteristic.readValue()
          info.volume = volValue.getUint8(0)
          info.hasVolumeControl = true
        } catch (e) { /* not available */ }
      } catch (e) { /* VCS not available */ }
    }

    // ── Auto-reconnect on disconnect ──
    device.addEventListener('gattserverdisconnected', () => {
      handleDisconnect(device)
    })

    setState(ConnectionState.CONNECTED)
    return info
  } catch (err) {
    setState(ConnectionState.FAILED)
    connectedDevice = null
    gattServer = null
    throw new Error(`Connection failed: ${err.message}. Make sure your device is in pairing mode.`)
  }
}

/**
 * Parse ASHA Read-Only Properties
 */
function parseASHAProperties(dataView) {
  try {
    const version = dataView.getUint8(0)
    const capabilities = dataView.getUint8(1)
    const side = (capabilities & 0x01) ? 'right' : 'left'
    const binaural = !!(capabilities & 0x02)
    const csisSupported = !!(capabilities & 0x04)

    let hiSyncId = ''
    for (let i = 2; i < 10 && i < dataView.byteLength; i++) {
      hiSyncId += dataView.getUint8(i).toString(16).padStart(2, '0')
    }

    const featureMap = dataView.byteLength > 10 ? dataView.getUint8(10) : 0
    const leCoCAudioSupport = !!(featureMap & 0x01)
    const renderDelay = dataView.byteLength > 12 ? dataView.getUint16(11, true) : 0

    const codecsBitmask = dataView.byteLength > 14 ? dataView.getUint16(13, true) : 0x02
    const codecs = []
    if (codecsBitmask & 0x02) codecs.push('G.722 @ 16kHz')
    if (codecsBitmask & 0x04) codecs.push('G.722 @ 24kHz')

    return { version, side, binaural, csisSupported, hiSyncId, leCoCAudioSupport, renderDelay, codecs }
  } catch (e) {
    return null
  }
}

/**
 * Handle disconnect with auto-reconnect
 */
async function handleDisconnect(device) {
  const wasConnected = currentState === ConnectionState.CONNECTED

  if (!wasConnected && currentState !== ConnectionState.RECONNECTING) {
    setState(ConnectionState.DISCONNECTED)
    connectedDevice = null
    gattServer = null
    if (onDisconnectCallback) onDisconnectCallback(device)
    return
  }

  if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
    setState(ConnectionState.RECONNECTING)
    reconnectAttempts++
    if (onReconnectingCallback) onReconnectingCallback(reconnectAttempts, MAX_RECONNECT_ATTEMPTS)

    await new Promise(r => setTimeout(r, RECONNECT_DELAY_MS))
    try {
      if (device.gatt) {
        await device.gatt.connect()
        reconnectAttempts = 0
        setState(ConnectionState.CONNECTED)
        return
      }
    } catch (e) {
      console.log(`Reconnect attempt ${reconnectAttempts} failed:`, e.message)
    }
    handleDisconnect(device)
  } else {
    setState(ConnectionState.DISCONNECTED)
    connectedDevice = null
    gattServer = null
    if (onDisconnectCallback) onDisconnectCallback(device)
  }
}

export async function setVolume(volume) {
  if (!volumeCharacteristic) throw new Error('Volume control not available')
  const buffer = new ArrayBuffer(1)
  new DataView(buffer).setInt8(0, volume)
  await volumeCharacteristic.writeValue(buffer)
  if (onVolumeChangeCallback) onVolumeChangeCallback(volume)
}

export async function sendASHACommand(opcode) {
  if (!ashaService) throw new Error('ASHA not available on this device')
  const controlPoint = await ashaService.getCharacteristic(ASHA_CHARS.AUDIO_CONTROL_POINT)
  const buffer = new ArrayBuffer(1)
  new DataView(buffer).setUint8(0, opcode)
  await controlPoint.writeValue(buffer)
}

export async function readBattery() {
  if (!batteryCharacteristic) return null
  try {
    const value = await batteryCharacteristic.readValue()
    return value.getUint8(0)
  } catch (e) { return null }
}

export function disconnectDevice() {
  reconnectAttempts = MAX_RECONNECT_ATTEMPTS
  setState(ConnectionState.DISCONNECTED)
  if (connectedDevice && connectedDevice.gatt && connectedDevice.gatt.connected) {
    connectedDevice.gatt.disconnect()
  }
  connectedDevice = null
  gattServer = null
  batteryCharacteristic = null
  ashaService = null
  volumeCharacteristic = null
}

export function getConnectedDevice() { return connectedDevice }
export function isDeviceConnected() {
  return connectedDevice && connectedDevice.gatt && connectedDevice.gatt.connected
}

// ─── Callback Registration ───
export function onBatteryChange(callback) { onBatteryChangeCallback = callback }
export function onDisconnect(callback) { onDisconnectCallback = callback }
export function onReconnecting(callback) { onReconnectingCallback = callback }
export function onConnectionState(callback) { onConnectionStateCallback = callback }
export function onVolumeChange(callback) { onVolumeChangeCallback = callback }

/**
 * Detect provider from device name
 */
export function detectProvider(deviceName) {
  if (!deviceName) return 'Unknown'
  const name = deviceName.toLowerCase()
  const providers = [
    { keys: ['cochlear', 'nucleus', 'baha', 'kanso', 'osia'], name: 'Cochlear' },
    { keys: ['phonak', 'marvel', 'lumity', 'paradise', 'bolero'], name: 'Phonak' },
    { keys: ['oticon', 'more', 'intent', 'xceed'], name: 'Oticon' },
    { keys: ['resound', 'omnia', 'nexia'], name: 'ReSound' },
    { keys: ['starkey', 'evolv', 'genesis', 'livio'], name: 'Starkey' },
    { keys: ['widex', 'moment', 'magnolia', 'smartric'], name: 'Widex' },
    { keys: ['signia'], name: 'Signia' },
    { keys: ['bernafon'], name: 'Bernafon' },
    { keys: ['unitron'], name: 'Unitron' },
    { keys: ['med-el', 'rondo', 'sonnet', 'audiolink'], name: 'MED-EL' },
  ]
  for (const p of providers) {
    if (p.keys.some(k => name.includes(k))) return p.name
  }
  return 'Other'
}

/**
 * Get Cochlear-specific pairing instructions
 */
export function getPairingInstructions(provider) {
  const instructions = {
    'Cochlear': [
      'Open the battery compartment on your Nucleus processor and close it to restart',
      'The LED will flash orange — the processor is now in pairing mode',
      'Tap "Scan Hearing Aids" below within 3 minutes',
      'Select your Nucleus device from the Bluetooth list',
      'Wait for the LED to turn solid green — you\'re connected!'
    ],
    'Phonak': [
      'Turn off your hearing aids by opening the battery door',
      'Close the battery door — aids enter pairing mode for 3 minutes',
      'For rechargeable: place in charger for 5 seconds, then remove',
      'Tap "Scan Hearing Aids" and select your device',
      'Wait for the confirmation tone in your hearing aids'
    ],
    'Oticon': [
      'Restart hearing aids by opening and closing the battery door',
      'For rechargeable: hold the button until LED flashes',
      'Aids enter pairing mode automatically on restart',
      'Tap "Scan Hearing Aids" and select your device',
      'You\'ll hear a confirmation jingle when connected'
    ],
    'MED-EL': [
      'Ensure your SONNET 2 or RONDO 3 is powered on',
      'Press and hold the button for 5 seconds until LED flashes blue',
      'Tap "Scan Hearing Aids" and select your device',
      'Wait for the LED to turn solid blue'
    ],
    'default': [
      'Put your hearing device in Bluetooth pairing mode',
      'Refer to your device manual for pairing instructions',
      'Tap "Scan Hearing Aids" to find nearby devices',
      'Select your device from the list to connect'
    ]
  }
  return instructions[provider] || instructions['default']
}

/**
 * Get supported features for a provider
 */
export function getProviderFeatures(provider) {
  const features = {
    'Cochlear': ['ASHA Streaming', 'Battery Monitoring', 'Remote Volume', 'Program Switching', 'Find My Processor'],
    'Phonak': ['ASHA Streaming', 'Battery Monitoring', 'Remote Volume', 'myPhonak Integration'],
    'Oticon': ['ASHA Streaming', 'Battery Monitoring', 'Remote Volume', 'Sound Scenes'],
    'ReSound': ['ASHA Streaming', 'Battery Monitoring', 'Remote Volume', 'All Access Directionality'],
    'Starkey': ['ASHA Streaming', 'Battery Monitoring', 'Remote Volume', 'Edge AI Processing'],
    'Widex': ['ASHA Streaming', 'Battery Monitoring', 'Remote Volume', 'SoundSense Learn'],
    'MED-EL': ['ASHA Streaming', 'Battery Monitoring', 'AudioLink Connectivity'],
  }
  return features[provider] || ['Bluetooth Connectivity', 'Battery Monitoring']
}
