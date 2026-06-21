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

### Apply Nginx Config Changes
```bash
# Link config to Nginx active configurations
sudo ln -s /etc/nginx/sites-available/lootlo /etc/nginx/sites-enabled/

# Test configuration syntax for errors
sudo nginx -t

# Reload configuration parameters on Nginx daemon
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
pm2 start dist/main.js --name "lootlo-backend"

# Persist and freeze active processes for system reboots
pm2 save
pm2 startup
```

### Useful PM2 Monitoring Commands:
```bash
# Read logs in real time (great for debugging socket connections)
pm2 logs lootlo-backend

# Check service execution status and memory/CPU consumption
pm2 status

# Restart the service (required after code updates)
pm2 restart lootlo-backend
```

---

## 7. Static Frontend Deployment

### React Admin Console
1. Ensure `.env` is created in local `admin` directory with production URL:
   ```env
   VITE_API_URL=https://api.kktechsolution.app/api
   ```
2. Build the project locally:
   ```bash
   npm run build
   ```
3. Copy local `dist` bundle directly to server host root `/var/www/lootlo-admin`:
   ```bash
   scp -r dist/* kktech@vps_ip_address:/var/www/lootlo-admin/
   ```

### Landing Page HTML
Copy the static files (`index.html`, assets) to the landing web root:
```bash
# Perform on VPS to verify landing page files are in place
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