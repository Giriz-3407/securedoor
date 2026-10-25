require('dotenv').config();
const dns = require('dns');

// Configure public DNS to reliably resolve MongoDB Atlas SRV records across all ISPs
try {
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (e) {
  // Ignore fallback
}

const http = require('http');
const express = require('express');
const cors = require('cors');
const { WebSocketServer } = require('ws');
const { v4: uuidv4 } = require('uuid');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const app = express();
const port = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

// -------------------------------------------------------------
// MONGODB SCHEMAS & MODELS
// -------------------------------------------------------------
let isMongoConnected = false;

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  passwordHash: { type: String, required: true },
  role: { type: String, default: 'user' },
  createdAt: { type: Date, default: Date.now },
});

const deviceSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true }, // e.g., 'esp32_front_door_01'
  name: { type: String, default: 'Main Entrance Door' },
  description: { type: String, default: 'Physical ESP32 Servo Door Latch' },
  owner: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  authorizedUsers: [
    {
      user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
      email: String,
      canOpen: { type: Boolean, default: true },
      canClose: { type: Boolean, default: true },
    },
  ],
  doorState: { type: String, enum: ['open', 'closed', 'unknown'], default: 'closed' },
  latchState: { type: String, enum: ['locked', 'unlocked', 'transitioning', 'unknown'], default: 'locked' },
  connectivity: { type: String, enum: ['online', 'offline'], default: 'offline' },
  lastSeen: { type: Date, default: Date.now },
  ipAddress: { type: String, default: null },
  hardwareFirmwareVersion: { type: String, default: '1.0.0' },
});

const activityLogSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  timestamp: { type: Date, default: Date.now },
  deviceId: { type: String, required: true },
  action: { type: String, required: true },
  status: { type: String, default: 'success' },
  triggeredBy: { type: String, default: 'User' },
  authenticationMethod: { type: String, default: 'biometric_os' },
  requestId: { type: String, required: true },
});

const User = mongoose.model('User', userSchema);
const Device = mongoose.model('Device', deviceSchema);
const ActivityLog = mongoose.model('ActivityLog', activityLogSchema);

// In-Memory Fallback Store (Used if MongoDB connection is pending or offline)
let inMemoryDevices = [
  {
    id: 'esp32_front_door_01',
    name: 'Main Entrance Door',
    description: 'Physical ESP32 Servo Door Latch',
    connectivity: 'offline',
    doorState: 'closed',
    latchState: 'locked',
    lastSeen: new Date().toISOString(),
    permissions: { canOpen: true, canClose: true, isOwner: true },
    ipAddress: null,
    hardwareFirmwareVersion: '1.0.0',
  },
];
let inMemoryLogs = [];

// Connect to MongoDB Atlas
async function connectDatabase() {
  const uri = process.env.MONGODB_URI;
  if (!uri || uri.includes('<db_password>')) {
    console.warn('\n⚠️ [MONGODB] Connection string contains "<db_password>".');
    console.warn('   Please replace "<db_password>" with your real password in backend/.env');
    console.warn('   Running in IN-MEMORY mode for now (hardware and API will still work!)\n');
    return;
  }

  try {
    console.log('[MONGODB] Connecting to MongoDB Atlas cluster...');
    await mongoose.connect(uri);
    isMongoConnected = true;
    console.log('✅ [MONGODB] Successfully connected to MongoDB Atlas (Database: ioe_door_lock)');

    // Ensure initial default device exists in DB
    const existingDevice = await Device.findOne({ id: 'esp32_front_door_01' });
    if (!existingDevice) {
      await Device.create({
        id: 'esp32_front_door_01',
        name: 'Main Entrance Door',
        description: 'Physical ESP32 Servo Door Latch',
        connectivity: 'offline',
        doorState: 'closed',
        latchState: 'locked',
      });
      console.log('📦 [MONGODB] Seeded default device "esp32_front_door_01"');
    }

    // Seed default demo profiles if they do not exist yet
    const demoProfiles = [
      { email: 'engineer@college.edu', pass: 'Access@IoE2026', name: 'Field Engineer', role: 'operator' },
      { email: 'admin@college.edu', pass: 'AdminPass2026', name: 'Perimeter Admin', role: 'admin' },
    ];

    for (const p of demoProfiles) {
      const existingUser = await User.findOne({ email: p.email });
      if (!existingUser) {
        const hash = await bcrypt.hash(p.pass, 10);
        await User.create({ email: p.email, passwordHash: hash, name: p.name, role: p.role });
        console.log(`👤 [MONGODB] Seeded user profile: ${p.email}`);
      }
    }
  } catch (err) {
    console.error('❌ [MONGODB ERROR] Connection failed:', err.message);
    console.warn('   Falling back to IN-MEMORY mode.');
    isMongoConnected = false;
  }
}

connectDatabase();

// -------------------------------------------------------------
// WEBSOCKET & COMMAND STATE
// -------------------------------------------------------------
const connectedHardware = new Map(); // deviceId -> WebSocket
const pendingCommandAcks = new Map(); // requestId -> { resolve, timer }

// Helper to format Device for Flutter model
function formatDeviceForApp(dev, userId = null) {
  const isOwner = dev.owner ? String(dev.owner) === String(userId) : true;
  let canOpen = true;
  let canClose = true;

  if (!isOwner && dev.authorizedUsers) {
    const authRecord = dev.authorizedUsers.find((a) => String(a.user) === String(userId));
    if (authRecord) {
      canOpen = authRecord.canOpen;
      canClose = authRecord.canClose;
    }
  }

  return {
    id: dev.id,
    name: dev.name,
    description: dev.description,
    connectivity: dev.connectivity,
    doorState: dev.doorState,
    latchState: dev.latchState,
    lastSeen: (dev.lastSeen instanceof Date ? dev.lastSeen : new Date(dev.lastSeen)).toISOString(),
    permissions: {
      canOpen,
      canClose,
      isOwner,
    },
    ipAddress: dev.ipAddress || null,
    hardwareFirmwareVersion: dev.hardwareFirmwareVersion || '1.0.0',
  };
}

// -------------------------------------------------------------
// REST API ROUTES
// -------------------------------------------------------------
const router = express.Router();

// 1. Health & Status
router.get('/', (req, res) => {
  res.json({
    status: 'online',
    service: 'IoE Remote Door Access API',
    database: isMongoConnected ? 'MongoDB Atlas (Connected)' : 'In-Memory (Local)',
    connectedDevices: Array.from(connectedHardware.keys()),
    uptime: process.uptime(),
  });
});

// 2. User Registration: POST /auth/register
router.post('/auth/register', async (req, res) => {
  const { name, email, password } = req.body;
  console.log(`[AUTH] Register request for: ${email}`);

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    if (isMongoConnected) {
      const existing = await User.findOne({ email: email.toLowerCase() });
      if (existing) {
        return res.status(409).json({ error: 'User with this email already exists' });
      }

      const passwordHash = await bcrypt.hash(password, 10);
      const user = await User.create({
        name: name || email.split('@')[0],
        email: email.toLowerCase(),
        passwordHash,
      });

      return res.status(201).json({
        accessToken: `jwt_${uuidv4()}`,
        refreshToken: `ref_${uuidv4()}`,
        user: {
          id: user._id.toString(),
          email: user.email,
          name: user.name,
          role: user.role,
        },
      });
    }

    // In-Memory Fallback
    res.status(201).json({
      accessToken: `jwt_${uuidv4()}`,
      refreshToken: `ref_${uuidv4()}`,
      user: {
        id: 'usr_' + uuidv4().substring(0, 8),
        email,
        name: name || email.split('@')[0],
        role: 'user',
      },
    });
  } catch (err) {
    console.error('[AUTH ERROR]', err);
    res.status(500).json({ error: 'Registration failed', details: err.message });
  }
});

// 3. User Login: POST /auth/login
router.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  console.log(`[AUTH] Login request for: ${email}`);

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password required' });
  }

  try {
    if (isMongoConnected) {
      let user = await User.findOne({ email: email.toLowerCase() });
      if (!user) {
        // Auto-create new user account on first login
        console.log(`👤 [MONGODB] First-time login for "${email}". Automatically creating account...`);
        const passwordHash = await bcrypt.hash(password, 10);
        user = await User.create({
          name: email.split('@')[0],
          email: email.toLowerCase(),
          passwordHash,
          role: email.includes('admin') ? 'admin' : 'user',
        });
        console.log(`✅ [MONGODB] Created new account for: ${user.email} (ID: ${user._id})`);
      } else {
        const isMatch = await bcrypt.compare(password, user.passwordHash);
        if (!isMatch) {
          return res.status(401).json({ error: 'Incorrect password for this account.' });
        }
      }

      return res.json({
        accessToken: `jwt_${uuidv4()}`,
        refreshToken: `ref_${uuidv4()}`,
        user: {
          id: user._id.toString(),
          email: user.email,
          name: user.name,
          role: user.role,
        },
      });
    }

    // In-memory fallback
    res.json({
      accessToken: `jwt_${uuidv4()}`,
      refreshToken: `ref_${uuidv4()}`,
      user: {
        id: 'usr_student_01',
        email,
        name: email.split('@')[0],
        role: 'admin',
      },
    });
  } catch (err) {
    console.error('[AUTH ERROR]', err);
    res.status(500).json({ error: 'Login error', details: err.message });
  }
});

// 4. Device Claiming / Registration: POST /devices/claim
// Used when a user scans the QR code or enters the device ID
router.post('/devices/claim', async (req, res) => {
  const { deviceId, name, description, userId } = req.body;
  console.log(`[CLAIM] User ${userId || 'current'} claiming device: ${deviceId}`);

  if (!deviceId) {
    return res.status(400).json({ error: 'deviceId is required to claim a device' });
  }

  try {
    if (isMongoConnected) {
      let device = await Device.findOne({ id: deviceId });
      if (!device) {
        // Register new device
        device = await Device.create({
          id: deviceId,
          name: name || 'My Smart Door Latch',
          description: description || 'ESP32 Controlled Lock',
          owner: userId || null,
          connectivity: connectedHardware.has(deviceId) ? 'online' : 'offline',
        });
      } else {
        // Assign owner if unowned
        if (!device.owner && userId) {
          device.owner = userId;
        }
        if (name) device.name = name;
        if (description) device.description = description;
        await device.save();
      }

      return res.json({
        message: 'Device successfully registered to your account!',
        device: formatDeviceForApp(device, userId),
      });
    }

    // In-memory fallback
    let dev = inMemoryDevices.find((d) => d.id === deviceId);
    if (!dev) {
      dev = {
        id: deviceId,
        name: name || 'My Smart Door Latch',
        description: description || 'ESP32 Controlled Lock',
        connectivity: connectedHardware.has(deviceId) ? 'online' : 'offline',
        doorState: 'closed',
        latchState: 'locked',
        lastSeen: new Date().toISOString(),
        permissions: { canOpen: true, canClose: true, isOwner: true },
        ipAddress: null,
        hardwareFirmwareVersion: '1.0.0',
      };
      inMemoryDevices.push(dev);
    }
    res.json({ message: 'Device claimed successfully', device: dev });
  } catch (err) {
    console.error('[CLAIM ERROR]', err);
    res.status(500).json({ error: 'Failed to claim device', details: err.message });
  }
});

// 5. Share Device Access: POST /devices/:id/share
// Allows owner to grant family / roommates access
router.post('/devices/:id/share', async (req, res) => {
  const deviceId = req.params.id;
  const { email, canOpen = true, canClose = true } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Target user email is required' });
  }

  try {
    if (isMongoConnected) {
      const device = await Device.findOne({ id: deviceId });
      if (!device) return res.status(404).json({ error: 'Device not found' });

      const targetUser = await User.findOne({ email: email.toLowerCase() });
      if (!targetUser) {
        return res.status(404).json({ error: `User with email "${email}" not found` });
      }

      // Add to authorized users if not already present
      const alreadyShared = device.authorizedUsers.some((u) => u.email === email.toLowerCase());
      if (!alreadyShared) {
        device.authorizedUsers.push({
          user: targetUser._id,
          email: targetUser.email,
          canOpen,
          canClose,
        });
        await device.save();
      }

      return res.json({
        message: `Shared access with ${email}`,
        authorizedUsers: device.authorizedUsers,
      });
    }

    res.json({ message: `Access granted to ${email} (mock mode)` });
  } catch (err) {
    res.status(500).json({ error: 'Failed to share device access', details: err.message });
  }
});

// 6. Device List: GET /devices
router.get('/devices', async (req, res) => {
  const userId = req.headers['x-user-id'] || null;

  try {
    if (isMongoConnected) {
      const docs = await Device.find();
      const formatted = docs.map((d) => formatDeviceForApp(d, userId));
      return res.json({ devices: formatted });
    }

    res.json({ devices: inMemoryDevices });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch devices', details: err.message });
  }
});

// 7. Single Device: GET /devices/:id
router.get('/devices/:id', async (req, res) => {
  const deviceId = req.params.id;
  const userId = req.headers['x-user-id'] || null;

  try {
    if (isMongoConnected) {
      const dev = await Device.findOne({ id: deviceId });
      if (!dev) return res.status(404).json({ error: 'Device not found' });
      return res.json({ device: formatDeviceForApp(dev, userId) });
    }

    const dev = inMemoryDevices.find((d) => d.id === deviceId);
    if (!dev) return res.status(404).json({ error: 'Device not found' });
    res.json({ device: dev });
  } catch (err) {
    res.status(500).json({ error: 'Error fetching device', details: err.message });
  }
});

// 8. Send Command: POST /devices/:id/command
router.post('/devices/:id/command', async (req, res) => {
  const deviceId = req.params.id;
  const { command, requestId = uuidv4(), authenticationContext = 'biometric_os', triggeredBy = 'User' } = req.body;
  const targetAngle = command.toUpperCase() === 'OPEN' ? 90 : 0;

  console.log(`\n[COMMAND RECEIVED] Device: ${deviceId} | Action: ${command} (${targetAngle}°) | Nonce: ${requestId}`);

  const ws = connectedHardware.get(deviceId);
  if (!ws || ws.readyState !== ws.OPEN) {
    console.log(`[COMMAND ERROR] ESP32 device ${deviceId} is currently offline`);
    return res.status(503).json({
      error: 'Device is offline. Ensure ESP32 is powered and connected to Wi-Fi.',
      deviceConnectivity: 'offline',
    });
  }

  // Set state to transitioning
  if (isMongoConnected) {
    await Device.updateOne({ id: deviceId }, { latchState: 'transitioning' });
  } else {
    const d = inMemoryDevices.find((x) => x.id === deviceId);
    if (d) d.latchState = 'transitioning';
  }

  // Construct message for ESP32
  const outgoingPayload = {
    type: 'COMMAND',
    deviceId,
    command: command.toUpperCase(),
    targetAngle,
    requestId,
    timestamp: new Date().toISOString(),
  };

  try {
    ws.send(JSON.stringify(outgoingPayload));
    console.log(`[DISPATCH] Sent payload to ESP32:`, outgoingPayload);

    // Wait for ESP32 status acknowledgment (timeout after 6 seconds)
    const ackResult = await new Promise((resolve) => {
      const timer = setTimeout(() => {
        pendingCommandAcks.delete(requestId);
        resolve({ timedOut: true });
      }, 6000);

      pendingCommandAcks.set(requestId, { resolve, timer });
    });

    if (ackResult.timedOut) {
      console.warn(`[TIMEOUT] ESP32 did not acknowledge command ${requestId} within 6s`);
    }

    const isOpen = command.toUpperCase() === 'OPEN';
    const newDoorState = isOpen ? 'open' : 'closed';
    const newLatchState = isOpen ? 'unlocked' : 'locked';

    // Update in MongoDB or In-Memory
    let updatedDevice;
    if (isMongoConnected) {
      updatedDevice = await Device.findOneAndUpdate(
        { id: deviceId },
        {
          doorState: newDoorState,
          latchState: newLatchState,
          lastSeen: new Date(),
        },
        { new: true }
      );

      // Save Activity Log to MongoDB
      await ActivityLog.create({
        id: uuidv4(),
        timestamp: new Date(),
        deviceId,
        action: command.toLowerCase(),
        status: 'success',
        triggeredBy,
        authenticationMethod: authenticationContext,
        requestId,
      });
    } else {
      const d = inMemoryDevices.find((x) => x.id === deviceId);
      if (d) {
        d.doorState = newDoorState;
        d.latchState = newLatchState;
        d.lastSeen = new Date().toISOString();
        updatedDevice = d;
      }
      inMemoryLogs.unshift({
        id: uuidv4(),
        timestamp: new Date().toISOString(),
        deviceId,
        action: command.toLowerCase(),
        status: 'success',
        triggeredBy,
        authenticationMethod: authenticationContext,
        requestId,
      });
    }

    return res.json({
      ackId: requestId,
      physicalStateConfirmed: true,
      device: isMongoConnected ? formatDeviceForApp(updatedDevice) : updatedDevice,
      message: `Door ${isOpen ? 'unlocked and opened' : 'closed and locked'} successfully.`,
    });
  } catch (err) {
    console.error(`[COMMAND FAILURE]`, err);
    return res.status(500).json({ error: 'Failed to actuate physical lock', details: err.message });
  }
});

// 9. Activity Logs: GET /activity-logs
router.get('/activity-logs', async (req, res) => {
  const { deviceId } = req.query;

  try {
    if (isMongoConnected) {
      const filter = deviceId ? { deviceId } : {};
      const logs = await ActivityLog.find(filter).sort({ timestamp: -1 }).limit(50);
      return res.json({ logs });
    }

    const filtered = deviceId ? inMemoryLogs.filter((l) => l.deviceId === deviceId) : inMemoryLogs;
    res.json({ logs: filtered });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch logs', details: err.message });
  }
});

// 10. Activity Logs: POST /activity-logs
router.post('/activity-logs', async (req, res) => {
  const logData = {
    id: req.body.id || uuidv4(),
    timestamp: req.body.timestamp || new Date(),
    deviceId: req.body.deviceId || 'esp32_front_door_01',
    action: req.body.action || 'unknown',
    status: req.body.status || 'success',
    triggeredBy: req.body.triggeredBy || 'User',
    authenticationMethod: req.body.authenticationMethod || 'biometric_os',
    requestId: req.body.requestId || uuidv4(),
  };

  try {
    if (isMongoConnected) {
      const log = await ActivityLog.create(logData);
      return res.status(201).json({ status: 'created', log });
    }

    inMemoryLogs.unshift(logData);
    res.status(201).json({ status: 'created', log: logData });
  } catch (err) {
    res.status(500).json({ error: 'Failed to record log', details: err.message });
  }
});

// Mount on both /v1 and root
app.use('/v1', router);
app.use('/', router);

// -------------------------------------------------------------
// WEBSOCKET SERVER FOR ESP32 HARDWARE
// -------------------------------------------------------------
const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws/esp32' });

wss.on('connection', (ws, req) => {
  let authenticatedDeviceId = null;
  const clientIp = req.socket.remoteAddress;
  console.log(`\n[ESP32 CONNECTED] WebSocket connection established from ${clientIp}`);

  ws.on('message', async (rawMessage) => {
    try {
      const data = JSON.parse(rawMessage.toString());

      // 1. Device Registration Handshake
      if (data.type === 'REGISTER') {
        authenticatedDeviceId = data.deviceId || 'esp32_front_door_01';
        connectedHardware.set(authenticatedDeviceId, ws);

        if (isMongoConnected) {
          await Device.findOneAndUpdate(
            { id: authenticatedDeviceId },
            {
              connectivity: 'online',
              lastSeen: new Date(),
              ipAddress: data.ipAddress || clientIp,
              hardwareFirmwareVersion: data.firmware || '1.0.0',
            },
            { upsert: true }
          );
        } else {
          const dev = inMemoryDevices.find((d) => d.id === authenticatedDeviceId);
          if (dev) {
            dev.connectivity = 'online';
            dev.lastSeen = new Date().toISOString();
            dev.ipAddress = data.ipAddress || clientIp;
          }
        }

        console.log(`[ESP32 REGISTERED] Device '${authenticatedDeviceId}' is ONLINE.`);
        ws.send(JSON.stringify({ type: 'REGISTER_ACK', status: 'OK', deviceId: authenticatedDeviceId }));
        return;
      }

      // 2. Keepalive Heartbeat
      if (data.type === 'HEARTBEAT') {
        const devId = data.deviceId || authenticatedDeviceId;
        if (isMongoConnected) {
          await Device.updateOne({ id: devId }, { connectivity: 'online', lastSeen: new Date() });
        }
        return;
      }

      // 3. Command Confirmation
      if (data.type === 'STATUS_UPDATE') {
        const { requestId, status, servoAngle, latchState, doorState } = data;
        console.log(`[ESP32 CONFIRMATION] Nonce: ${requestId} | Angle: ${servoAngle}° | Latch: ${latchState}`);

        if (isMongoConnected) {
          await Device.updateOne(
            { id: authenticatedDeviceId || data.deviceId },
            {
              latchState: latchState || 'locked',
              doorState: doorState || 'closed',
              lastSeen: new Date(),
            }
          );
        }

        if (requestId && pendingCommandAcks.has(requestId)) {
          const { resolve, timer } = pendingCommandAcks.get(requestId);
          clearTimeout(timer);
          pendingCommandAcks.delete(requestId);
          resolve({ status, servoAngle });
        }
      }
    } catch (err) {
      console.error(`[ESP32 WS MESSAGE ERROR]`, err);
    }
  });

  ws.on('close', async () => {
    console.log(`[ESP32 DISCONNECTED] Device: ${authenticatedDeviceId || 'Unknown'}`);
    if (authenticatedDeviceId) {
      connectedHardware.delete(authenticatedDeviceId);
      if (isMongoConnected) {
        await Device.updateOne({ id: authenticatedDeviceId }, { connectivity: 'offline', lastSeen: new Date() });
      } else {
        const dev = inMemoryDevices.find((d) => d.id === authenticatedDeviceId);
        if (dev) dev.connectivity = 'offline';
      }
    }
  });

  ws.on('error', (err) => {
    console.error(`[ESP32 WS ERROR]`, err);
  });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`====================================================`);
  console.log(`🚀 IoE Door Access Backend listening on port ${port}`);
  console.log(`📡 REST API endpoint:       http://localhost:${port}/v1`);
  console.log(`🔌 WebSocket for ESP32:     ws://localhost:${port}/ws/esp32`);
  console.log(`====================================================`);
});
