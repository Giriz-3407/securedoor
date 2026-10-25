# IoE Door Access Backend

A lightweight Node.js Express & WebSocket server for physical door lock control with ESP32 and Flutter.

## Local Running (On Your Desk)

```bash
cd backend
npm install
npm start
```

The server starts on port `5000`:
- **REST API for Mobile App**: `http://<YOUR_LOCAL_IP>:5000/v1`
- **WebSocket for ESP32**: `ws://<YOUR_LOCAL_IP>:5000/ws/esp32`

## Deployment to Render.com (100% Free Forever)

1. Push your repository to GitHub.
2. Sign in to [Render.com](https://render.com/).
3. Click **New +** -> **Web Service**.
4. Select your GitHub repository.
5. Configure:
   - **Root Directory**: `backend`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Plan**: `Free`
6. Click **Deploy Web Service**.
7. Render gives you an HTTPS URL: `https://your-service-name.onrender.com`.
   - Your Flutter API Base URL becomes: `https://your-service-name.onrender.com/v1`
   - Your ESP32 WebSocket Host becomes: `your-service-name.onrender.com`, Port: `443`, with SSL enabled (`USE_SSL = true`).
