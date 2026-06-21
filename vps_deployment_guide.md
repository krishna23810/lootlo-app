# Lootlo App - VPS Production Deployment Guide

This guide details the steps required to deploy the complete **Lootlo App** stack to a Linux Virtual Private Server (VPS) running Ubuntu 22.04 or 24.04 LTS.

---

## 1. System Architecture Diagram

All client traffic runs through Nginx over secure HTTPS/WSS. Nginx acts as the reverse proxy, routing requests to the respective services.

```mermaid
graph TD
    subgraph Client Apps
        flutter[Flutter App]
        host[Admin Console]
    end

    subgraph VPS Server
        nginx[Nginx Reverse Proxy: SSL Port 443]
        backend[NestJS API Server: Port 3000]
        postgres[(PostgreSQL DB: Port 54320)]
        redis[(Redis Server: Port 6379)]
        janus[Janus WebRTC Gateway: Port 8088]
    end

    flutter -->|HTTPS API / WSS Sockets| nginx
    host -->|HTTPS Admin / Camera Stream| nginx
    nginx -->|Proxy Pass /api| backend
    nginx -->|Proxy Pass /socket.io| backend
    nginx -->|Proxy Pass /janus| janus
    
    backend -->|SQL Queries| postgres
    backend -->|Session Caching| redis
    backend -->|REST Controls| janus
    
    host -.->|UDP RTP Media: Ports 10000-10200| janus
    janus -.->|UDP RTP Media: Ports 10000-10200| flutter
```

---

## 2. Prerequisites & Server Setup

### VPS Hardware Requirements
- **OS**: Ubuntu 22.04 LTS or Ubuntu 24.04 LTS.
- **CPU**: 2 Cores (minimum 1 Core).
- **RAM**: 2GB or more (Janus stream transcoding and Docker instances need overhead).
- **Network**: Public IP address.

### Domain Names
You **must** point two domains/subdomains to your VPS IP address. WebRTC and modern browsers require HTTPS/WSS to access camera/audio feeds.
1. `admin.yourdomain.com` (for the React Admin console)
2. `api.yourdomain.com` (for NestJS Backend API, Sockets, and Janus signaling)

### Firewall Ports Configuration (UFW)
Open these ports in your cloud provider firewall:
- `80/tcp` (HTTP - Let's Encrypt validation)
- `443/tcp` (HTTPS / WSS)
- `10000-10200/udp` (Janus WebRTC UDP Media ports - essential for video streams!)

On the VPS, configure UFW:
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 10000:10200/udp
sudo ufw enable
```

---

## 3. Install Docker & Node.js on the VPS

Log into your VPS via SSH and install Docker, Docker Compose, and Node.js:

```bash
# Update repositories
sudo apt update && sudo apt upgrade -y

# Install Docker
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io -y

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# Install Node.js v20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install nodejs -y

# Install PM2 Process Manager globally
sudo npm install pm2 -g
```

---

## 4. Spin Up Databases & Janus WebRTC Gateway

Create a unified deploy folder `/opt/lootlo` and configure Docker Compose:

```bash
sudo mkdir -p /opt/lootlo/config/conf
sudo mkdir -p /opt/lootlo/config/certs
```

Copy your Janus configuration files from your local repository `backend/config/conf/*` to `/opt/lootlo/config/conf/` on the VPS. 

### Create `docker-compose.prod.yml`
Create `/opt/lootlo/docker-compose.yml`:

```yaml
version: '3.8'

services:
  # 1. PostgreSQL DB
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

  # 2. Redis Cache
  redis:
    image: redis:7-alpine
    container_name: lootlo-redis
    restart: always
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data

  # 3. Janus WebRTC Media Server
  janus-gateway:
    image: sucwangsr/janus-webrtc-gateway-docker:latest
    container_name: lootlo-janus
    restart: always
    command: ["/usr/local/bin/janus", "-F", "/usr/local/etc/janus"]
    ports:
      - "8088:8088"
      - "8188:8188"
      - "10000-10200:10000-10200/udp"
    volumes:
      - "./config/conf/janus.jcfg:/usr/local/etc/janus/janus.jcfg"
      - "./config/conf/janus.transport.http.jcfg:/usr/local/etc/janus/janus.transport.http.jcfg"
      - "./config/conf/janus.transport.websockets.jcfg:/usr/local/etc/janus/janus.transport.websockets.jcfg"
      - "./config/conf/janus.plugin.streaming.jcfg:/usr/local/etc/janus/janus.plugin.streaming.jcfg"
    network_mode: "host" # Requires host network mode for WebRTC UDP port ranges to bind efficiently

volumes:
  postgres-data:
  redis-data:
```

> [!IMPORTANT]
> Change `YourSecurePassword123!` to a secure string.
> Ensure that `network_mode: "host"` is configured, otherwise routing the UDP video packets on dynamically mapped Docker ports 10000-10200 is prone to packet loss.

Start the services:
```bash
cd /opt/lootlo
sudo docker compose up -d
```

---

## 5. Reverse Proxy Setup (Nginx + Let's Encrypt SSL)

### Install Nginx & Certbot
```bash
sudo apt install nginx certbot python3-certbot-nginx -y
```

### Obtain Let's Encrypt Certificates
Run the Certbot command for your two subdomains:
```bash
sudo certbot certonly --nginx -d admin.yourdomain.com -d api.yourdomain.com
```
Choose option 1 to spin up a temporary Nginx server. It will generate private keys and chain certificates in `/etc/letsencrypt/live/yourdomain.com/`.

### Configure Nginx
Edit `/etc/nginx/sites-available/lootlo`:

```nginx
# 1. Host React Admin Dashboard
server {
    listen 80;
    listen 443 ssl;
    server_name admin.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/admin.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/admin.yourdomain.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root /var/www/lootlo-admin;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Redirect non-SSL to SSL
    if ($scheme != "https") {
        return 301 https://$host$request_uri;
    }
}

# 2. Host Backend API, Sockets & WebRTC Proxy
server {
    listen 80;
    listen 443 ssl;
    server_name api.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;
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
        proxy_read_timeout 86400;
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

    # Redirect non-SSL to SSL
    if ($scheme != "https") {
        return 301 https://$host$request_uri;
    }
}
```

Enable the configuration and reload Nginx:
```bash
sudo ln -s /etc/nginx/sites-available/lootlo /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

---

## 6. Deploy Backend API

1. Copy the `backend` folder to the VPS (e.g. `/opt/lootlo/backend`).
2. Create `/opt/lootlo/backend/.env` on the server:

```env
PORT=3000
DATABASE_URL="postgresql://postgres:YourSecurePassword123!@localhost:54320/live_housie?schema=public"
REDIS_HOST="127.0.0.1"
REDIS_PORT=6379
JWT_SECRET="EnterARandomStrongSecretHashHereValue"
JWT_REFRESH_SECRET="EnterAnotherDifferentStrongSecretHashHere"
JANUS_URL="http://127.0.0.1:8088/janus"
```

3. Initialize project, migrate, compile, and run:

```bash
cd /opt/lootlo/backend

# Install dependencies
npm install

# Run database migration (applies SQL tables to Docker Postgres container)
npx prisma migrate deploy

# Compile NestJS typescript
npm run build

# Start with PM2 for background process execution and restart management
pm2 start dist/main.js --name "lootlo-backend"

# Ensure PM2 starts on server boot
pm2 save
pm2 startup
```

---

## 7. Build & Host React Admin Console

1. In your local `admin` directory, copy `.env.example` to `.env` or create it:
   ```env
   VITE_API_URL=https://api.yourdomain.com/api
   ```
2. Build the React project locally:
   ```bash
   npm install
   npm run build
   ```
3. Copy the compiled files from the local `admin/dist` directory to `/var/www/lootlo-admin` on your VPS:
   ```bash
   # Execute this locally (or copy zip archives to server)
   scp -r dist/* user@vps_ip_address:/var/www/lootlo-admin/
   ```
4. Verify by accessing `https://admin.yourdomain.com` in your browser.

---

## 8. Configure & Build Flutter Client

1. Open [app_constants.dart](file:///c:/Users/offic/OneDrive/Desktop/lootlo-app/live_housie/lib/core/constants/app_constants.dart) in the Flutter project.
2. Update the production API endpoints pointing to your secure API subdomain:

```dart
class AppConstants {
  AppConstants._();

  static const String appName = 'Lootlo';

  // ─── Production VPS configuration ───
  static const String baseUrl = 'https://api.yourdomain.com/api';
  static const String wsUrl = 'https://api.yourdomain.com';
  
  // Keep constraints and other constants...
}
```

3. Build the Flutter App:
   - For Android: `flutter build apk --release`
   - For iOS: `flutter build ipa`

Your application is now fully configured and live on your production VPS! 🚀
