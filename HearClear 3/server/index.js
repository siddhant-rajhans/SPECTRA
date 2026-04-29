import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import path from 'path';
import { fileURLToPath } from 'url';
import { initialize as initializeDb, closeDb } from './database.js';
import { handleNotFound, globalErrorHandler, asyncHandler } from './middleware/errorHandler.js';

// Import routes
import alertsRouter from './routes/alerts.js';
import imlRouter from './routes/iml.js';
import environmentRouter from './routes/environment.js';
import profileRouter from './routes/profile.js';
import transcribeRouter from './routes/transcribe.js';
import authRouter from './routes/auth.js';
import implantsRouter from './routes/implants.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3001;
const NODE_ENV = process.env.NODE_ENV || 'development';

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// CORS configuration
app.use(
  cors({
    origin: ['http://localhost:5173', 'http://localhost:3001', 'http://127.0.0.1:5173'],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
  })
);

// Request logging middleware
app.use((req, res, next) => {
  const startTime = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    console.log(`${req.method} ${req.path} - ${res.statusCode} (${duration}ms)`);
  });
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// API Routes
app.use('/api/alerts', alertsRouter);
app.use('/api/iml', imlRouter);
app.use('/api/environment', environmentRouter);
app.use('/api/profile', profileRouter);
app.use('/api/transcribe', transcribeRouter);
app.use('/api/auth', authRouter);
app.use('/api/implants', implantsRouter);

// Static file serving (for production build)
const clientDistPath = path.join(__dirname, '../client/dist');
app.use(express.static(clientDistPath));

// Fallback to index.html for SPA routing
app.get('*', (req, res) => {
  // If route doesn't match API, serve index.html for client-side routing
  if (!req.path.startsWith('/api')) {
    res.sendFile(path.join(clientDistPath, 'index.html'), (err) => {
      if (err) {
        res.status(404).json({
          success: false,
          error: 'Not found'
        });
      }
    });
  } else {
    handleNotFound(req, res);
  }
});

// Error handling middleware
app.use(globalErrorHandler);

// Create HTTP server and WebSocket server
const httpServer = createServer(app);
const wss = new WebSocketServer({ server: httpServer, path: '/ws' });

// WebSocket connection handling
const connectedClients = new Map();

wss.on('connection', (ws, req) => {
  const clientId = req.headers['sec-websocket-key'];
  console.log(`WebSocket client connected: ${clientId}`);

  connectedClients.set(clientId, ws);

  // Send welcome message
  ws.send(
    JSON.stringify({
      type: 'connection',
      message: 'Connected to Auralis server',
      timestamp: new Date().toISOString()
    })
  );

  // Handle incoming messages
  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data.toString());
      console.log(`WebSocket message from ${clientId}:`, message.type);

      // Handle different message types
      if (message.type === 'subscribe') {
        // Client subscribing to alerts
        ws.isSubscribedToAlerts = true;
        ws.send(
          JSON.stringify({
            type: 'subscribed',
            channel: message.channel || 'alerts',
            timestamp: new Date().toISOString()
          })
        );
      } else if (message.type === 'ping') {
        // Respond to ping
        ws.send(
          JSON.stringify({
            type: 'pong',
            timestamp: new Date().toISOString()
          })
        );
      }
    } catch (error) {
      console.error('Error handling WebSocket message:', error);
      ws.send(
        JSON.stringify({
          type: 'error',
          message: 'Failed to process message'
        })
      );
    }
  });

  // Handle client disconnect
  ws.on('close', () => {
    console.log(`WebSocket client disconnected: ${clientId}`);
    connectedClients.delete(clientId);
  });

  // Handle errors
  ws.on('error', (error) => {
    console.error(`WebSocket error for ${clientId}:`, error.message);
  });
});

/**
 * Broadcast alert to all connected WebSocket clients
 * Called when a new alert is created that should be delivered
 */
export function broadcastAlert(alert) {
  const message = JSON.stringify({
    type: 'alert',
    data: alert,
    timestamp: new Date().toISOString()
  });

  let broadcastCount = 0;
  connectedClients.forEach((client) => {
    if (client.readyState === 1 && client.isSubscribedToAlerts) {
      // readyState 1 = OPEN
      client.send(message, (error) => {
        if (error) {
          console.error('Error broadcasting alert:', error);
        } else {
          broadcastCount++;
        }
      });
    }
  });

  console.log(`Alert broadcast to ${broadcastCount} clients`);
}

/**
 * Broadcast device status update
 */
export function broadcastDeviceStatus(deviceStatus) {
  const message = JSON.stringify({
    type: 'device_status',
    data: deviceStatus,
    timestamp: new Date().toISOString()
  });

  connectedClients.forEach((client) => {
    if (client.readyState === 1) {
      client.send(message);
    }
  });
}

/**
 * Broadcast real-time context update
 */
export function broadcastContextUpdate(context) {
  const message = JSON.stringify({
    type: 'context_update',
    data: context,
    timestamp: new Date().toISOString()
  });

  connectedClients.forEach((client) => {
    if (client.readyState === 1) {
      client.send(message);
    }
  });
}

// Graceful shutdown
const signals = ['SIGTERM', 'SIGINT'];
signals.forEach(signal => {
  process.on(signal, () => {
    console.log(`\n${signal} received. Shutting down gracefully...`);

    // Close WebSocket connections
    wss.clients.forEach((client) => {
      client.close(1000, 'Server shutting down');
    });

    // Close HTTP server
    httpServer.close(() => {
      console.log('HTTP server closed');

      // Close database
      closeDb();
      console.log('Database closed');

      process.exit(0);
    });

    // Force close after 10 seconds
    setTimeout(() => {
      console.error('Forced shutdown');
      process.exit(1);
    }, 10000);
  });
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Start server with async database initialization
async function startServer() {
  try {
    console.log('Initializing database...');
    await initializeDb();
    console.log('Database initialized successfully');

    httpServer.listen(PORT, () => {
      console.log(`\n╔════════════════════════════════════════════════════════╗`);
      console.log(`║  Auralis Backend Server Started                        ║`);
      console.log(`╠════════════════════════════════════════════════════════╣`);
      console.log(`║  Environment: ${NODE_ENV.padEnd(43)}║`);
      console.log(`║  HTTP Server: http://localhost:${PORT.toString().padEnd(38)}║`);
      console.log(`║  WebSocket: ws://localhost:${PORT.toString().padEnd(38)}║`);
      console.log(`║  API Docs: http://localhost:${PORT}/api${' '.repeat(32)}║`);
      console.log(`╚════════════════════════════════════════════════════════╝\n`);

      console.log('Available endpoints:');
      console.log('  - GET  /health');
      console.log('  - GET  /api/alerts');
      console.log('  - POST /api/alerts');
      console.log('  - GET  /api/profile');
      console.log('  - GET  /api/iml/pending');
      console.log('  - GET  /api/environment/programs');
      console.log('  - GET  /api/transcribe/sessions');
      console.log('');
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();

export default app;
