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
  role: { type: String, enum: ['admin', 'user'], default: 'user' },
  createdAt: { type: Date, default: Date.now },
});

const deviceSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true }, // e.g. 'esp32_front_door_01'
  name: { type: String, default: 'Main Entrance Door' },
  description: { type: String, default: 'Physical ESP32 Servo Door Latch' },
  owner: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  authorizedUsers: [
    {
      user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
      email: String,
      canOpen: { type: Boolean, default: true },
      canClose: { type: Boolean, default: true },
      approvedAt: { type: Date, default: Date.now },
    },
  ],
  doorState: { type: String, enum: ['open', 'closed', 'unknown'], default: 'closed' },
  latchState: { type: String, enum: ['locked', 'unlocked', 'transitioning', 'unknown'], default: 'locked' },
  connectivity: { type: String, enum: ['online', 'offline'], default: 'offline' },
  lastSeen: { type: Date, default: Date.now },
  ipAddress: { type: String, default: null },
  hardwareFirmwareVersion: { type: String, default: '1.0.0' },
});

const accessRequestSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  userEmail: { type: String, required: true },
  userName: { type: String, required: true },
  deviceId: { type: String, required: true },
  deviceName: { type: String, required: true },
  status: { type: String, enum: ['pending', 'accepted', 'rejected'], default: 'pending' },
  requestedAt: { type: Date, default: Date.now },
  reviewedAt: { type: Date, default: null },
  reviewedBy: { type: String, default: null },
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
const AccessRequest = mongoose.model('AccessRequest', accessRequestSchema);
const ActivityLog = mongoose.model('ActivityLog', activityLogSchema);

// In-Memory Fallback Stores
let inMemoryDevices = [
  {
    id: 'esp32_front_door_01',
    name: 'Main Entrance Door',
    description: 'Physical ESP32 Servo Door Latch',
    connectivity: 'offline',
    doorState: 'closed',
    latchState: 'locked',
    lastSeen: new Date().toISOString(),
    ownerId: 'usr_admin_01',
    authorizedUsers: [],
    permissions: { canOpen: true, canClose: true, isOwner: true },
    ipAddress: null,
    hardwareFirmwareVersion: '1.0.0',
  },
];
let inMemoryAccessRequests = [];
let inMemoryLogs = [];

// Connect to MongoDB Atlas
async function connectDatabase() {
  let uri = process.env.MONGODB_URI;
  if (!uri || uri.includes('<db_password>')) {
    console.warn('\n⚠️ [MONGODB] Connection string contains "<db_password>".');
    console.warn('   Please replace "<db_password>" with your real password in backend/.env');
    console.warn('   Running in IN-MEMORY mode for now.\n');
    return;
  }

  try {
    console.log('[MONGODB] Connecting to MongoDB Atlas cluster...');
    await mongoose.connect(uri);
    isMongoConnected = true;
    console.log('✅ [MONGODB] Successfully connected to MongoDB Atlas (Database: ioe_door_lock)');

    // 1. Seed default Admin Profile
    const adminEmail = 'admin@college.edu';
    let adminUser = await User.findOne({ email: adminEmail });
    if (!adminUser) {
      const hash = await bcrypt.hash('AdminPass2026', 10);
      adminUser = await User.create({
        email: adminEmail,
        passwordHash: hash,
        name: 'System Admin',
        role: 'admin',
      });
      console.log(`👤 [MONGODB] Created default Admin: ${adminEmail} (Role: admin)`);
    } else {
      adminUser.role = 'admin';
      await adminUser.save();
    }

    // 2. Remove any legacy operator profile from database as requested
    const deletedOp = await User.deleteOne({ email: 'engineer@college.edu' });
    if (deletedOp.deletedCount > 0) {
      console.log('🗑️ [MONGODB] Removed legacy operator profile (engineer@college.edu)');
    }

    // 3. Ensure default physical device exists and is bound to Admin
    let defaultDevice = await Device.findOne({ id: 'esp32_front_door_01' });
    if (!defaultDevice) {
      await Device.create({
        id: 'esp32_front_door_01',
        name: 'Main Entrance Door',
        description: 'Physical ESP32 Servo Door Latch',
        owner: adminUser._id,
        connectivity: 'offline',
        doorState: 'closed',
        latchState: 'locked',
        authorizedUsers: [],
      });
      console.log('📦 [MONGODB] Seeded default device "esp32_front_door_01" (Owner: Admin)');
    } else if (!defaultDevice.owner) {
      defaultDevice.owner = adminUser._id;
      await defaultDevice.save();
      console.log('📦 [MONGODB] Assigned device "esp32_front_door_01" owner to Admin');
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
function formatDeviceForApp(dev, userId = null, userRole = null) {
  const isOwner = dev.owner ? String(dev.owner) === String(userId) : false;
  const isAdmin = userRole === 'admin';

  let canOpen = isAdmin || isOwner;
  let canClose = isAdmin || isOwner;

  if (!canOpen && dev.authorizedUsers) {
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
      isOwner: isOwner || isAdmin,
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
        role: 'user', // Default is regular user, only admin@college.edu is admin
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
        console.log(`👤 [MONGODB] First-time login for "${email}". Automatically creating user account...`);
        const passwordHash = await bcrypt.hash(password, 10);
        user = await User.create({
          name: email.split('@')[0],
          email: email.toLowerCase(),
          passwordHash,
          role: email.toLowerCase() === 'admin@college.edu' ? 'admin' : 'user',
        });
        console.log(`✅ [MONGODB] Created account: ${user.email} (Role: ${user.role})`);
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
    const role = email.toLowerCase().includes('admin') ? 'admin' : 'user';
    res.json({
      accessToken: `jwt_${uuidv4()}`,
      refreshToken: `ref_${uuidv4()}`,
      user: {
        id: role === 'admin' ? 'usr_admin_01' : 'usr_student_01',
        email,
        name: email.split('@')[0],
        role,
      },
    });
  } catch (err) {
    console.error('[AUTH ERROR]', err);
    res.status(500).json({ error: 'Login error', details: err.message });
  }
});

// 4. Request Access to a Device: POST /devices/request-access (or /devices/claim)
// When a regular user tries to access a door, an access request goes to the Admin
router.post(['/devices/request-access', '/devices/claim'], async (req, res) => {
  const { deviceId } = req.body;
  const userId = req.body.userId || req.headers['x-user-id'];
  const userEmail = req.body.userEmail || req.headers['x-user-email'] || 'Unknown User';
  const userName = req.body.userName || userEmail.split('@')[0];

  console.log(`\n[ACCESS REQUEST] User "${userEmail}" is requesting access to device "${deviceId}"`);

  if (!deviceId) {
    return res.status(400).json({ error: 'deviceId is required' });
  }

  try {
    if (isMongoConnected) {
      const device = await Device.findOne({ id: deviceId });
      if (!device) {
        return res.status(404).json({ error: `Door device "${deviceId}" not found in system` });
      }

      // If user is Admin or Owner, they already have full access
      if (device.owner && String(device.owner) === String(userId)) {
        return res.json({
          status: 'already_authorized',
          message: 'You are already the owner of this door.',
          device: formatDeviceForApp(device, userId, 'admin'),
        });
      }

      // Check if user is already in authorizedUsers
      const alreadyApproved = device.authorizedUsers.some(
        (a) => String(a.user) === String(userId) || a.email.toLowerCase() === userEmail.toLowerCase()
      );
      if (alreadyApproved) {
        return res.json({
          status: 'already_authorized',
          message: 'You already have approved access to this door.',
          device: formatDeviceForApp(device, userId, 'user'),
        });
      }

      // Check if an existing request is pending
      const existingReq = await AccessRequest.findOne({
        deviceId,
        userEmail: userEmail.toLowerCase(),
        status: 'pending',
      });
      if (existingReq) {
        return res.json({
          status: 'pending',
          message: 'Your access request is currently pending Admin approval.',
          request: existingReq,
        });
      }

      // Create new Access Request
      const newRequest = await AccessRequest.create({
        id: uuidv4(),
        userId: userId ? new mongoose.Types.ObjectId(userId) : new mongoose.Types.ObjectId(),
        userEmail: userEmail.toLowerCase(),
        userName,
        deviceId,
        deviceName: device.name,
        status: 'pending',
        requestedAt: new Date(),
      });

      console.log(`📋 [ACCESS REQUEST LOGGED] Request ID: ${newRequest.id} for Admin approval.`);

      return res.status(202).json({
        status: 'pending',
        message: 'Access request submitted! Waiting for Admin confirmation.',
        request: newRequest,
      });
    }

    // In-memory fallback
    const existingReq = inMemoryAccessRequests.find(
      (r) => r.deviceId === deviceId && r.userEmail === userEmail && r.status === 'pending'
    );
    if (existingReq) {
      return res.json({ status: 'pending', message: 'Request is pending Admin review', request: existingReq });
    }

    const newReq = {
      id: uuidv4(),
      userId: userId || 'usr_temp',
      userEmail,
      userName,
      deviceId,
      deviceName: 'Main Entrance Door',
      status: 'pending',
      requestedAt: new Date().toISOString(),
    };
    inMemoryAccessRequests.push(newReq);
    res.status(202).json({ status: 'pending', message: 'Access request submitted to Admin', request: newReq });
  } catch (err) {
    console.error('[REQUEST ACCESS ERROR]', err);
    res.status(500).json({ error: 'Failed to submit access request', details: err.message });
  }
});

// 5. Admin: List Access Requests: GET /access-requests
router.get('/access-requests', async (req, res) => {
  const { status } = req.query; // optional: ?status=pending

  try {
    if (isMongoConnected) {
      const filter = status ? { status } : {};
      const requests = await AccessRequest.find(filter).sort({ requestedAt: -1 });
      return res.json({ requests });
    }

    const filtered = status ? inMemoryAccessRequests.filter((r) => r.status === status) : inMemoryAccessRequests;
    res.json({ requests: filtered });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch access requests', details: err.message });
  }
});

// 6. Admin: Review Access Request (Accept or Reject): POST /access-requests/:id/review
router.post('/access-requests/:id/review', async (req, res) => {
  const requestId = req.params.id;
  const { action, adminEmail = 'admin@college.edu' } = req.body; // action: 'accept' | 'reject'

  console.log(`\n[ADMIN REVIEW] Request ${requestId} -> Action: ${action?.toUpperCase()}`);

  if (!action || !['accept', 'reject'].includes(action.toLowerCase())) {
    return res.status(400).json({ error: 'Action must be "accept" or "reject"' });
  }

  try {
    if (isMongoConnected) {
      const accessReq = await AccessRequest.findOne({ id: requestId });
      if (!accessReq) {
        return res.status(404).json({ error: 'Access request not found' });
      }

      if (action.toLowerCase() === 'accept') {
        accessReq.status = 'accepted';
        accessReq.reviewedAt = new Date();
        accessReq.reviewedBy = adminEmail;
        await accessReq.save();

        // Add user to the Device's authorizedUsers array
        const device = await Device.findOne({ id: accessReq.deviceId });
        if (device) {
          const alreadyIn = device.authorizedUsers.some(
            (a) => a.email.toLowerCase() === accessReq.userEmail.toLowerCase()
          );
          if (!alreadyIn) {
            device.authorizedUsers.push({
              user: accessReq.userId,
              email: accessReq.userEmail,
              canOpen: true,
              canClose: true,
              approvedAt: new Date(),
            });
            await device.save();
            console.log(`✅ [ACCESS GRANTED] User "${accessReq.userEmail}" added to door "${device.name}"!`);
          }
        }

        // Record Activity Log
        await ActivityLog.create({
          id: uuidv4(),
          timestamp: new Date(),
          deviceId: accessReq.deviceId,
          action: 'access_granted',
          status: 'success',
          triggeredBy: adminEmail,
          authenticationMethod: 'admin_dashboard',
          requestId,
        });

        return res.json({
          status: 'accepted',
          message: `Access granted to ${accessReq.userName} (${accessReq.userEmail}) for ${accessReq.deviceName}.`,
          request: accessReq,
        });
      } else {
        accessReq.status = 'rejected';
        accessReq.reviewedAt = new Date();
        accessReq.reviewedBy = adminEmail;
        await accessReq.save();

        console.log(`❌ [ACCESS REJECTED] Access rejected for "${accessReq.userEmail}"`);

        return res.json({
          status: 'rejected',
          message: `Access request rejected for ${accessReq.userEmail}.`,
          request: accessReq,
        });
      }
    }

    // In-memory fallback
    const reqItem = inMemoryAccessRequests.find((r) => r.id === requestId);
    if (!reqItem) return res.status(404).json({ error: 'Request not found' });

    reqItem.status = action.toLowerCase() === 'accept' ? 'accepted' : 'rejected';
    if (action.toLowerCase() === 'accept') {
      const dev = inMemoryDevices.find((d) => d.id === reqItem.deviceId);
      if (dev) {
        dev.authorizedUsers.push({
          user: reqItem.userId,
          email: reqItem.userEmail,
          canOpen: true,
          canClose: true,
        });
      }
    }
    res.json({ status: reqItem.status, message: `Request ${reqItem.status}` });
  } catch (err) {
    console.error('[REVIEW ERROR]', err);
    res.status(500).json({ error: 'Failed to review request', details: err.message });
  }
});

// 7. Device List: GET /devices
// Admin sees all devices; regular users ONLY see devices they are authorized for
router.get('/devices', async (req, res) => {
  const userId = req.headers['x-user-id'] || null;
  const userEmail = (req.headers['x-user-email'] || '').toLowerCase();

  try {
    if (isMongoConnected) {
      // Find current user's role
      let userRole = 'user';
      if (userId) {
        const u = await User.findById(userId);
        if (u) userRole = u.role;
      }
      if (userEmail === 'admin@college.edu') {
        userRole = 'admin';
      }

      let query = {};
      // If NOT admin, only return devices owned by user or shared with user
      if (userRole !== 'admin') {
        query = {
          $or: [
            { owner: userId },
            { 'authorizedUsers.user': userId },
            { 'authorizedUsers.email': userEmail },
          ],
        };
      }

      const docs = await Device.find(query);
      const formatted = docs.map((d) => formatDeviceForApp(d, userId, userRole));
      return res.json({ devices: formatted });
    }

    res.json({ devices: inMemoryDevices });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch devices', details: err.message });
  }
});

// 8. Single Device: GET /devices/:id
router.get('/devices/:id', async (req, res) => {
  const deviceId = req.params.id;
  const userId = req.headers['x-user-id'] || null;
  const userEmail = (req.headers['x-user-email'] || '').toLowerCase();

  try {
    if (isMongoConnected) {
      const dev = await Device.findOne({ id: deviceId });
      if (!dev) return res.status(404).json({ error: 'Device not found' });

      let userRole = userEmail === 'admin@college.edu' ? 'admin' : 'user';
      return res.json({ device: formatDeviceForApp(dev, userId, userRole) });
    }

    const dev = inMemoryDevices.find((d) => d.id === deviceId);
    if (!dev) return res.status(404).json({ error: 'Device not found' });
    res.json({ device: dev });
  } catch (err) {
    res.status(500).json({ error: 'Error fetching device', details: err.message });
  }
});

// 9. Send Command: POST /devices/:id/command
router.post('/devices/:id/command', async (req, res) => {
  const deviceId = req.params.id;
  const { command, requestId = uuidv4(), authenticationContext = 'biometric_os', triggeredBy = 'User' } = req.body;
  const userId = req.headers['x-user-id'] || req.body.userId;
  const userEmail = (req.headers['x-user-email'] || req.body.userEmail || '').toLowerCase();
  const targetAngle = command.toUpperCase() === 'OPEN' ? 90 : 0;

  console.log(`\n[COMMAND RECEIVED] Device: ${deviceId} | Action: ${command} (${targetAngle}°) | By: ${userEmail || userId}`);

  // Permission Verification Check
  if (isMongoConnected) {
    const dev = await Device.findOne({ id: deviceId });
    if (!dev) return res.status(404).json({ error: 'Device not found' });

    const isAdmin = userEmail === 'admin@college.edu';
    const isOwner = dev.owner && String(dev.owner) === String(userId);
    const isAuthorized = dev.authorizedUsers.some(
      (a) => (userId && String(a.user) === String(userId)) || (userEmail && a.email.toLowerCase() === userEmail)
    );

    if (!isAdmin && !isOwner && !isAuthorized) {
      console.warn(`⛔ [UNAUTHORIZED] User "${userEmail}" attempted unauthorized operation on "${deviceId}"`);
      return res.status(403).json({
        error: 'Forbidden: You do not have permission to operate this door. Request access from the Admin.',
      });
    }
  }

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
        triggeredBy: userEmail || triggeredBy,
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
        triggeredBy: userEmail || triggeredBy,
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

// 10. Activity Logs: GET /activity-logs
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
