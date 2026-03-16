# 05-Analytics Service

Analytics Service provides market data, portfolio valuations, and analytics. It is built with **Python 3.12** and **FastAPI**, using **asyncpg** for async database access.

> **Hint**
> **Developer has chosen Python 3.12 with FastAPI framework and uvicorn as the ASGI server.**

> **Dependency**
> Analytics Service depends on **PostgreSQL**. Ensure PostgreSQL is set up and running before starting this service.

## Install Python 3.12

```shell
dnf install -y python3.12 python3.12-pip python3.12-devel gcc
```

Verify the installation.

```shell
python3.12 --version
```

> **Note**
> We install `python3.12-devel` and `gcc` because some Python packages (like `asyncpg`) need to compile C extensions during installation. Without these, `pip install` will fail.

## Configure the Application

Add application user.

```shell
useradd -r -s /bin/false appuser
```

Create the application directory.

```shell
mkdir -p /app
```

## Download & Install

Download and extract the application source code directly to the application directory.

```shell
curl -L -o /tmp/analytics-service.tar.gz https://raw.githubusercontent.com/raghudevopsb88/wealth-project/main/artifacts/analytics-service.tar.gz
cd /app
tar xzf /tmp/analytics-service.tar.gz
```

Install the Python dependencies and set ownership.

```shell
cd /app
pip3.12 install --no-cache-dir .
chown -R appuser:appuser /app
chmod o-rwx /app -R
```

> **Hint**
> **The `pyproject.toml` file defines all the dependencies. `pip install .` reads it and installs everything needed — FastAPI, uvicorn, asyncpg, SQLAlchemy, etc. This step takes a couple of minutes.**

> **Troubleshooting**
> If you see an error about "Multiple top-level packages discovered in a flat-layout", ensure the `pyproject.toml` contains:
> ```toml
> [tool.setuptools.packages.find]
> include = ["app*"]
> ```
> This tells setuptools to only package the `app` directory and ignore `migrations/`.

## Setup SystemD Service

> **Note**
> You can create this file using **`vim /etc/systemd/system/analytics-service.service`**

```ini title=/etc/systemd/system/analytics-service.service
[Unit]
Description=WMP Analytics Service
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/app
ExecStart=/usr/local/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
Restart=on-failure
RestartSec=10

Environment=DATABASE_URL=postgresql+asyncpg://analytics_svc_user:localdev123@localhost:5432/wmp
Environment=DB_SCHEMA=analytics_schema
Environment=LOG_LEVEL=INFO
Environment=ENVIRONMENT=production

[Install]
WantedBy=multi-user.target
```

> **Important**
> Replace `localhost` with the **private IP address** of your PostgreSQL server.
>
> Note the `DATABASE_URL` format uses `postgresql+asyncpg://` as the scheme because FastAPI uses async database drivers.

Load the service.

```shell
systemctl daemon-reload
```

Start the service.

```shell
systemctl enable analytics-service
systemctl start analytics-service
```

> **Re-deployment Note**
> If you are re-deploying, stop the service before updating:
> ```shell
> systemctl stop analytics-service
> cd /app && tar xzf /tmp/analytics-service.tar.gz
> pip3.12 install --no-cache-dir .
> systemctl start analytics-service
> ```

## Verification

Check the service status.

```shell
systemctl status analytics-service
```

Check the application logs.

```shell
journalctl -u analytics-service -f
```

Verify the health endpoint.

```shell
curl http://localhost:8000/health
```

Expected response:

```json
{"status":"healthy"}
```

> **Hint**
> **The `--workers 4` flag runs 4 uvicorn worker processes for handling concurrent requests. Adjust based on your server's CPU cores.**

> **Note**
> After this service is running, go back to the **Frontend** browser — the dashboard should now show **market data**, **portfolio valuations**, and **analytics charts**. All features of the application should now be fully functional.
