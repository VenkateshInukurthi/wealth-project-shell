# 01-Frontend

Frontend is the web application for the Wealth Management Platform. It is built with **React** and **Vite**, and served by **Nginx** which also acts as a **reverse proxy** to route API requests to the correct backend service.

> **Hint**
> **Developer has chosen React with Vite as the build tool. Nginx serves the static files and proxies API calls to backend services.**

> **Note**
> We set up Frontend first to demonstrate the problem — the web page will load but nothing will work because the backend services are not running yet. As we set up each backend, features will start working.

## Install Nginx

By default Nginx available in RHEL 9 may not be version 1.26. We need to enable the 1.26 module and install it.

```shell
dnf module disable nginx -y
dnf module enable nginx:1.26 -y
dnf install -y nginx
```

Start & Enable Nginx service.

```shell
systemctl enable nginx
systemctl start nginx
```

> **Note**
> Try to access the server IP in the browser and ensure you get the default Nginx page. This confirms Nginx is installed and running correctly.

## Install Node.js 22

Node.js is required to build the frontend application from source.

> **Hint**
> **Node.js 22 is not available in default RHEL 9 repos. We need to add the NodeSource repository.**

```shell
curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
dnf install -y nodejs
```

Verify the installation.

```shell
node --version
npm --version
```

## Download & Build

> **Note**
> Our application developed by our own developer does not have any RPM package. So we need to configure every step manually.

Download the frontend source code to a temporary directory.

```shell
curl -L -o /tmp/frontend.tar.gz https://raw.githubusercontent.com/raghudevopsb88/wealth-project/main/artifacts/frontend.tar.gz
mkdir -p /tmp/frontend
cd /tmp/frontend
tar xzf /tmp/frontend.tar.gz
```


Install dependencies and build.

```shell
cd /tmp/frontend
npm ci
npm run build
```

> **Hint**
> **`npm ci` installs exact versions from `package-lock.json` for reproducible builds. `npm run build` produces optimized static files in the `dist/` directory.**

## Deploy to Nginx

Remove the default Nginx content and copy the built frontend.

```shell
rm -rf /usr/share/nginx/html/*
cp -r /tmp/frontend/dist/* /usr/share/nginx/html/
```

## Configure Nginx

The default `nginx.conf` on RHEL 9 has an embedded server block that will conflict with our configuration. We need to replace the entire file with our own configuration that includes the reverse proxy setup.

> **Important**
> **Do NOT try to edit the default `nginx.conf` to remove the server block — it has nested braces that are difficult to handle. Replace the entire file instead.**

Replace the main Nginx configuration.

```shell
vim /etc/nginx/nginx.conf
```

Replace the entire content with:

```nginx title=/etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access_log  main;

    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    server {
        listen 80;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;

        # Auth Service
        location /api/v1/auth/ {
            proxy_pass http://localhost:8081;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Portfolio Service
        location /api/v1/users/ {
            proxy_pass http://localhost:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /api/v1/portfolios/ {
            proxy_pass http://localhost:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /api/v1/holdings/ {
            proxy_pass http://localhost:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Analytics Service
        location /api/v1/market-data/ {
            proxy_pass http://localhost:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /api/v1/valuations/ {
            proxy_pass http://localhost:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /api/v1/analytics/ {
            proxy_pass http://localhost:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # SPA fallback — serves index.html for client-side routing
        location / {
            try_files $uri $uri/ /index.html;
        }

        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Health check
        location /nginx-health {
            access_log off;
            return 200 "OK\n";
        }

        # Gzip compression
        gzip on;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript image/svg+xml;
        gzip_min_length 256;
    }
}
```

> **Important**
> Replace the following placeholders with **private IP addresses** of the backend servers:
> - `localhost` — Auth Service server
> - `localhost` — Portfolio Service server
> - `localhost` — Analytics Service server

Remove the default Nginx server config to avoid conflicts.

```shell
rm -f /etc/nginx/conf.d/default.conf
```

> **Note**
> **Why reverse proxy?** The browser sends all API requests to the **same origin** (the Nginx server). Nginx then routes them to the correct backend based on the URL path. This avoids CORS issues and means the frontend doesn't need to know backend server IPs at build time.

## Validate & Restart

Always test the Nginx configuration before restarting.

```shell
nginx -t
```

> **Hint**
> **If `nginx -t` shows errors, check your config for typos or missing semicolons. The error message will include the line number.**

Restart Nginx to load the new configuration.

```shell
systemctl restart nginx
```

## Verification

Access `http://<FRONTEND-SERVER-PUBLIC-IP>` in your browser.

> **Note**
> You should see the WMP login page. However, if you try to register or login, it will **fail** because the backend services are not running yet. This is expected — we will set them up in the following steps.

Check the Nginx health endpoint.

```shell
curl http://localhost/nginx-health
```

Expected response:

```
OK
```
