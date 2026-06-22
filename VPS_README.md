# Lootlo App - VPS Production Deployment & Operations Guide

This documentation serves as an all-in-one guide detailing the server setup, dockerized services, Nginx reverse proxy routing, Let's Encrypt SSL certificate provisioning, and backend execution commands used to host **Lootlo App** on a production Virtual Private Server (VPS).

---

## 1. System Architecture & Workflows

All traffic from user devices (Flutter mobile client) and the host (React Admin console) runs through Nginx over secure HTTPS/WSS. Nginx functions as a centralized gateway routing traffic to backend containers, process managers, and WebRTC streaming endpoints.



### Architectural Flow (Mermaid Diagram)
![alt text](image.png)



---

## 2. Global Port Configuration (Firewall)

For WebRTC video calls and backend routing to work, the following ports must be opened inside the VPS Firewall (such as UFW or AWS/DigitalOcean security groups):

* **`80/tcp`**: HTTP (Required for Let's Encrypt validation and domain redirects)
* **`443/tcp`**: HTTPS & WSS (Secure APIs, admin console, and WebSockets)
* **`10000-10200/udp`**: Janus WebRTC RTP Media (Handles incoming and outgoing video/audio packets. **Must be UDP**.)

### Commands to Configure local UFW Firewall:
```bash
# Allow HTTP/HTTPS traffic
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow WebRTC UDP media port ranges
sudo ufw allow 10000:10200/udp

# Enable the firewall
sudo ufw enable

# Check firewall status
sudo ufw status verbose
```

---

## 3. Server Dependencies Setup

Below are the commands executed to install standard software dependencies on the raw VPS:

### System Updates
```bash
sudo apt update && sudo apt upgrade -y
```
* **Why**: Updates the local package index and upgrades all installed packages to their latest secure versions to prevent OS-level vulnerabilities.

### Docker Engine Installation
```bash
# Install package helper utilities
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

# Add Docker's official GPG key for package signing verification
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker package repository to system sources
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update index and install Docker Engine + CLI
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io -y

# Enable Docker daemon to launch automatically on server boot
sudo systemctl enable docker
sudo systemctl start docker
```
* **Why**: Installs Docker to containerize services like PostgreSQL, Redis, and Janus. Containerization keeps services isolated and guarantees the exact same environment runs in production as in development.

### Node.js & Process Management Installation
```bash
# Register NodeSource Node.js v20 LTS repository
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

# Install Node.js
sudo apt install nodejs -y

# Install PM2 Process Manager globally
sudo npm install pm2 -g
```
* **Why**: Node.js is required to execute the Express API backend. PM2 is a production process manager that executes the backend application as a background service, restarts it automatically if it crashes, manages logs, and configures startup execution.

## 4. Dockerized Services Configuration

The infrastructure uses a unified Docker Compose file located at `backend/config/docker-compose.yml` (mapped to `/opt/lootlo/backend/config/docker-compose.yml` on the VPS) to run the PostgreSQL database, Redis cache, and Janus WebRTC gateway.

### Docker Compose File (`/opt/lootlo/backend/config/docker-compose.yml`)
```yaml
version: '3.8'

services:
  # 1. PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: lootlo-postgres
    restart: always
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: YourSecurePassword123!
      POSTGRES_DB: live_housie
    ports:
      - "54320:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data

  # 2. Redis Cache Server
  redis:
    image: redis:7-alpine
    container_name: lootlo-redis
    restart: always
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data

  # 3. Janus WebRTC Media Gateway
  janus-gateway:
    image: 'sucwangsr/janus-webrtc-gateway-docker:latest'
    container_name: lootlo-janus
    restart: always
    command: ["/usr/local/bin/janus", "-F", "/usr/local/etc/janus"]
    ports:
      - "8088:8088"
      - "8188:8188"
      - "10000-10200:10000-10200/udp"
    volumes:
      - "./conf/janus.jcfg:/usr/local/etc/janus/janus.jcfg"
      - "./conf/janus.transport.http.jcfg:/usr/local/etc/janus/janus.transport.http.jcfg"
      - "./conf/janus.transport.websockets.jcfg:/usr/local/etc/janus/janus.transport.websockets.jcfg"
      - "./conf/janus.plugin.streaming.jcfg:/usr/local/etc/janus/janus.plugin.streaming.jcfg"
    network_mode: "host"

volumes:
  postgres-data:
  redis-data:
```

### Key Docker Details:
1. **`network_mode: "host"`**: WebRTC establishes connections using ICE/STUN, exchanging dynamic media ports. Standard Docker bridged networking adds heavy NAT translation layers that drop UDP audio/video packets. Binding Janus directly to the host's networking stack ensures direct, raw packet handling on ports `10000-10200/udp` with zero latency.
2. **Mount Volume paths**: Conf maps are loaded relatively from the `backend/config` directory where `docker-compose.yml` sits.
3. **`postgres-data` & `redis-data` Volumes**: Prevent data loss when containers restart or undergo upgrades.

### Command to Spin Up Services:
```bash
# Navigate to the config folder in the repository
cd /opt/lootlo/backend/config

# Start all database and WebRTC services in detached mode
sudo docker compose up -d
```

---

## 5. Nginx Configuration & Let's Encrypt SSL

Nginx serves as our reverse proxy, mapping external domains to correct internal ports. SSL is enforced across all domains.

### Install Nginx and Certbot
```bash
sudo apt install nginx certbot python3-certbot-nginx -y
```

### Obtain SSL Certificates
Certbot validates domain ownership via temporary HTTP challenges on port 80 and generates Let's Encrypt certificates.
```bash
# Generate certs for the Landing Page
sudo certbot certonly --nginx -d kktechsolution.app -d www.kktechsolution.app

# Generate certs for the Admin Panel
sudo certbot certonly --nginx -d admin.kktechsolution.app

# Generate certs for the Backend API, Sockets & Janus WebRTC gateway
sudo certbot certonly --nginx -d api.kktechsolution.app
```
* **Why `certonly`**: Instructs Certbot to fetch the certificate credentials without altering default server blocks, allowing us to write clean custom Nginx files ourselves.

### Complete Nginx Server Configuration (`/etc/nginx/sites-available/lootlo`)
```nginx
# ─────────────────────────────────────────────────────────────────────────────
# 0. Landing Page - Root Domain
# ─────────────────────────────────────────────────────────────────────────────
server {
    listen 80;
    listen 443 ssl;
    server_name kktechsolution.app www.kktechsolution.app;

    ssl_certificate /etc/letsencrypt/live/kktechsolution.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/kktechsolution.app/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root /var/www/lootlo-landing;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Redirect HTTP to HTTPS
    if ($scheme != "https") {
        return 301 https://$host$request_uri;
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Host React Admin Dashboard
# ─────────────────────────────────────────────────────────────────────────────
server {
    listen 80;
    listen 443 ssl;
    server_name admin.kktechsolution.app;

    ssl_certificate /etc/letsencrypt/live/admin.kktechsolution.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/admin.kktechsolution.app/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root /var/www/lootlo-admin;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Redirect HTTP to HTTPS
    if ($scheme != "https") {
        return 301 https://$host$request_uri;
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Host Backend API, Sockets & WebRTC Proxy
# ─────────────────────────────────────────────────────────────────────────────
server {
    listen 80;
    listen 443 ssl;
    server_name api.kktechsolution.app;

    ssl_certificate /etc/letsencrypt/live/api.kktechsolution.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.kktechsolution.app/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Backend API Proxypass
    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket Socket.io Proxy
    location /socket.io/ {
        proxy_pass http://127.0.0.1:3000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400; # Keep WebSocket tunnels open for 24h
    }

    # Janus HTTP WebRTC Proxy
    location /janus {
        proxy_pass http://127.0.0.1:8088/janus;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Redirect HTTP to HTTPS
    if ($scheme != "https") {
        return 301 https://$host$request_uri;
    }
}
```

### Explaining the Nginx Proxies:
1. **`/api/`**: Proxies REST endpoints to the Express port `3000`.
2. **`/socket.io/`**: Enables Socket.io WebSocket connections. Crucially forces HTTP/1.1 protocol and configures headers `Upgrade: WebSocket` and `Connection: Upgrade` to allow upgrading the HTTP socket tunnel. `proxy_read_timeout 86400` prevents Nginx from severing quiet socket feeds.
3. **`/janus`**: Resolves SSL requests to raw Janus HTTP port `8088/janus`, allowing the mobile client to talk to Janus safely from an `https://` endpoint.

### Apply Nginx Config Changes (Using nginx.config from Repository)

To apply the configuration using the `nginx.config` file included in your repository (located at `/opt/lootlo/nginx.config` on the VPS):

```bash
# 1. Copy the configuration file from your repository to Nginx configurations
sudo cp /opt/lootlo/nginx.config /etc/nginx/sites-available/lootlo

# 2. Disable Nginx's default site configuration (to prevent port 80/default conflicts)
sudo rm -f /etc/nginx/sites-enabled/default

# 3. Link your custom config to Nginx's active configurations
sudo ln -s /etc/nginx/sites-available/lootlo /etc/nginx/sites-enabled/

# 4. Test configuration syntax for errors
sudo nginx -t

# 5. Reload and restart Nginx daemon
sudo systemctl restart nginx
```

---

## 6. Backend API Deployment

Run these commands inside `/opt/lootlo/backend` to configure environment states and start process managers.

### Create Environment Configuration File (`/opt/lootlo/backend/.env`)
```env
PORT=3000
DATABASE_URL="postgresql://postgres:YourSecurePassword123!@localhost:54320/live_housie?schema=public"
REDIS_HOST="127.0.0.1"
REDIS_PORT=6379
JWT_SECRET="SomeRandomLongCryptoSafeStringForAuthenticationTokens"
JWT_REFRESH_SECRET="AnotherDifferentCryptoSafeStringForRefreshingAuth"
JANUS_URL="http://127.0.0.1:8088/janus"
```

### Build & Process Initialization
```bash
cd /opt/lootlo/backend

# Install node dependencies
npm install

# Apply database migration (synchronizes PostgreSQL schema with backend Prisma model)
npx prisma migrate deploy

# Compile NestJS / Express Typescript into Node.js vanilla JS
npm run build

# Start backend using PM2 manager
pm2 start dist/index.js --name "lootlo-backend"

# Persist and freeze active processes for system reboots
pm2 save
pm2 startup
```

### What is PM2 and Why Are We Using It?

**PM2 (Process Manager 2)** is a production-grade process manager for Node.js applications. In development, you typically run your server using commands like `npm run dev` or `node src/index.ts`, which run inside your active terminal session. If you close the terminal, log out of SSH, or if the code encounters an unhandled error, the process immediately terminates and the app goes offline.

We use PM2 in our production VPS environment to solve these issues:

1. **Daemonization (Background Run)**: PM2 runs the backend application in the background. You can safely disconnect your SSH terminal session, and the backend continues running.
2. **Automatic Crash Recovery**: If the backend encounters an unhandled runtime error (e.g., a database connection drop or unexpected payload crash), PM2 instantly restarts the server process in milliseconds, keeping the app online.
3. **System Reboot Survival**: If the VPS server is restarted or updated, PM2 registers with the server's init system (like systemd) to automatically boot up and relaunch the Lootlo API process on system startup.
4. **Built-in Log Management**: PM2 handles all console logs (`console.log`, `console.error`) automatically. It separates standard logs from error logs and stores them in files, making debugging easy without cluttering your system disk.
5. **Cluster Mode (Optional Scaling)**: PM2 can run multiple instances of the backend on all available CPU cores, load-balancing incoming API and socket traffic for higher performance.

---

### Useful PM2 Monitoring Commands:
```bash
# Read logs in real time (great for debugging socket connections)
pm2 logs lootlo-backend

# Check service execution status and memory/CPU consumption
pm2 status

# Restart the service (required after code updates)
pm2 restart lootlo-backend
```

### Shutting Down All Services
If you need to completely shut down and stop all running services on the VPS (for maintenance, server migration, or updates):

```bash
# 1. Stop the Node.js backend process running in PM2
pm2 stop lootlo-backend

# 2. Stop and spin down all Docker containers (PostgreSQL, Redis, and Janus Gateway)
cd /opt/lootlo/backend/config
sudo docker compose down

# 3. Stop the Nginx reverse proxy server
sudo systemctl stop nginx
```

---

## 7. Static Frontend & Landing Page Setup

For Nginx to host the Admin Dashboard and the Landing Page, you must create their hosting directories on the VPS and configure proper user ownership permissions so files can be uploaded.

### Step 1: Create Directories and Set Permissions on VPS
Log into your VPS terminal and run:
```bash
# Create target web hosting directories
sudo mkdir -p /var/www/lootlo-admin
sudo mkdir -p /var/www/lootlo-landing

# Give directory ownership to your VPS user (e.g. kktech) so you can SCP files without permission errors
sudo chown -R kktech:kktech /var/www/lootlo-admin
sudo chown -R kktech:kktech /var/www/lootlo-landing
```

---

### Step 2: Deploy React Admin Console
The Admin Console is built locally on your development machine and uploaded to the VPS.

1. **Configure Environment Variables**:
   In your local `admin/` directory, create or edit `.env` and set the production backend API endpoint:
   ```env
   VITE_API_URL=https://api.kktechsolution.app/api
   ```

2. **Build the Admin App Locally**:
   Run these commands inside your local `admin/` directory:
   ```bash
   npm install
   npm run build
   ```
   This generates a compiled, static `dist/` production folder.

3. **Upload to the VPS**:
   Upload the compiled files using secure copy (`scp`) from your local PC terminal:
   ```bash
   scp -r dist/* kktech@YOUR_VPS_IP_ADDRESS:/var/www/lootlo-admin/
   ```

---

### Step 3: Deploy Lootlo Landing Page
The landing page consists of static HTML and asset files found in the `landing/` directory.

#### Option A: Deploy directly from the VPS repository clone (Easiest)
If your git repository is cloned on the VPS at `/opt/lootlo`:
```bash
# Copy landing files directly on the server
cp -r /opt/lootlo/landing/* /var/www/lootlo-landing/
```

#### Option B: Upload from your local Windows PC
Run this command from your local repository root folder:
```bash
scp -r landing/* kktech@YOUR_VPS_IP_ADDRESS:/var/www/lootlo-landing/
```

---

### Step 4: Verify Deployment Directories
Verify that the files exist in the target paths on the VPS:
```bash
# Verify Admin files (should see index.html, assets, etc.)
ls -la /var/www/lootlo-admin/

# Verify Landing files (should see index.html, assets, etc.)
ls -la /var/www/lootlo-landing/
```

---

## 8. Mobile Client Configuration

Update [app_constants.dart](file:///c:/Users/offic/OneDrive/Desktop/lootlo-app/live_housie/lib/core/constants/app_constants.dart) to target your production domains:

```dart
class AppConstants {
  AppConstants._();

  static const String appName = 'Lootlo';

  // ─── Production VPS configuration ───
  static const String baseUrl = 'https://api.kktechsolution.app/api';
  static const String wsUrl = 'https://api.kktechsolution.app';
  
  // Keep limits and other constants...
}
```
Build clean client binaries:
* **Android**: `flutter build apk --release`
* **iOS**: `flutter build ipa`


style Client_Apps fill:#f9f,stroke:#333,stroke-width:2px
style VPS_Server fill:#bbf,stroke:#333,stroke-width:2px   