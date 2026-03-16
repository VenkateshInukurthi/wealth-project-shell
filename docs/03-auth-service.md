# 04-Auth Service

Auth Service handles user registration and login. It issues JWT tokens that are validated by other services. It is built with **Go** using the **chi** router.

> **Hint**
> **Developer has chosen Golang. This service generates JWTs that are compatible with the Java Portfolio Service — both use the same HS256 secret.**

> **Dependency**
> Auth Service depends on **PostgreSQL** and **Portfolio Service**. Ensure both are running before setting up this service. During user registration, Auth Service makes a sync REST call to Portfolio Service to create the user record and seed a starter portfolio.

## Install Go

```shell
dnf install -y golang
```

Verify the installation.

```shell
go version
```

## Configure the Application

Add application user.

```shell
useradd -r -s /bin/false appuser
```

Create the application directory.

```shell
mkdir -p /app
```

## Download & Build

Download and extract the application source code directly to the application directory.

```shell
curl -L -o /tmp/auth-service.tar.gz https://raw.githubusercontent.com/raghudevopsb88/wealth-project/main/artifacts/auth-service.tar.gz
cd /app
tar xzf /tmp/auth-service.tar.gz
```

Build the Go binary.

```shell
cd /app
CGO_ENABLED=0 go build -o auth-service ./cmd/server
```

> **Hint**
> **`CGO_ENABLED=0` produces a statically-linked binary with no external C dependencies. The first build takes a minute as Go downloads module dependencies. Subsequent builds are much faster.**

Set ownership.

```shell
chown -R appuser:appuser /app
chmod o-rwx /app -R
```

## Setup SystemD Service

> **Note**
> You can create this file using **`vim /etc/systemd/system/auth-service.service`**

```ini title=/etc/systemd/system/auth-service.service
[Unit]
Description=WMP Auth Service
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/app
ExecStart=/app/auth-service
Restart=on-failure
RestartSec=10

Environment=DB_HOST=localhost
Environment=DB_PORT=5432
Environment=DB_USER=auth_svc_user
Environment=DB_PASSWORD=localdev123
Environment=DB_NAME=wmp
Environment=DB_SCHEMA=auth_schema
Environment=SERVER_PORT=8081
Environment=JWT_SECRET=myDefaultSuperSecretKeyThatIsAtLeast256BitsLongForHS256Algorithm
Environment=PORTFOLIO_SERVICE_URL=http://localhost:8080

[Install]
WantedBy=multi-user.target
```

> **Important**
> Replace the following placeholders:
> - `localhost` — Private IP of the PostgreSQL server
> - `localhost` — Private IP of the Portfolio Service server
>
> The `JWT_SECRET` must be the **same value** used in Portfolio Service for token validation to work across services.

Load the service.

```shell
systemctl daemon-reload
```

Start the service.

```shell
systemctl enable auth-service
systemctl start auth-service
```

> **Re-deployment Note**
> If you are re-deploying (updating the binary), you must **stop the service first** before copying — otherwise you'll get a "Text file busy" error:
> ```shell
> systemctl stop auth-service
> cd /app && tar xzf /tmp/auth-service.tar.gz
> CGO_ENABLED=0 go build -o auth-service ./cmd/server
> systemctl start auth-service
> ```

## Verification

Check the service status.

```shell
systemctl status auth-service
```

Check the application logs.

```shell
journalctl -u auth-service -f
```

> **Hint**
> **Auth Service starts up very fast (under 2 seconds) since Go binaries are pre-compiled.**

Verify the health endpoint.

```shell
curl http://localhost:8081/health
```

Expected response:

```json
{"status":"UP"}
```

Test registration.

```shell
curl -X POST http://localhost:8081/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","fullName":"Test User"}'
```

> **Note**
> After this service is running, go back to the **Frontend** browser — you should now be able to **register** and **login**. The dashboard will load and show portfolio data.
