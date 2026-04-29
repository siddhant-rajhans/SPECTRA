/**
 * WebSocket broadcaster.
 *
 * Owns the registry of connected clients and exposes broadcast helpers used by
 * route handlers. Lives in a separate module so routes can import it without
 * creating a circular dependency with index.js.
 */

const connectedClients = new Map();

export function registerClient(clientId, ws) {
  connectedClients.set(clientId, ws);
}

export function unregisterClient(clientId) {
  connectedClients.delete(clientId);
}

export function getClient(clientId) {
  return connectedClients.get(clientId);
}

export function getConnectedClients() {
  return connectedClients;
}

function broadcast(payload, predicate = () => true) {
  const message = JSON.stringify(payload);
  let count = 0;
  connectedClients.forEach((client) => {
    if (client.readyState === 1 && predicate(client)) {
      try {
        client.send(message);
        count += 1;
      } catch (err) {
        console.error('WebSocket broadcast failed:', err.message);
      }
    }
  });
  return count;
}

export function broadcastAlert(alert) {
  const count = broadcast(
    {
      type: 'alert',
      data: alert,
      timestamp: new Date().toISOString()
    },
    (client) => client.isSubscribedToAlerts
  );
  console.log(`Alert broadcast to ${count} clients (${alert?.sound_type ?? 'unknown'})`);
  return count;
}

export function broadcastDeviceStatus(deviceStatus) {
  return broadcast({
    type: 'device_status',
    data: deviceStatus,
    timestamp: new Date().toISOString()
  });
}

export function broadcastContextUpdate(context) {
  return broadcast({
    type: 'context_update',
    data: context,
    timestamp: new Date().toISOString()
  });
}
