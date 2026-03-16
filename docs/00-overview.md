# 00-Overview

Wealth Management Platform (WMP) is a microservices-based web application for managing investment portfolios. It consists of 5 components deployed across 5 servers.

## Architecture

```
                    ┌──────────────────┐
                    │     Browser      │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │  Frontend/Nginx  │ :80
                    └──┬─────┬──────┬──┘
                       │     │      │
          ┌────────────┘     │      └────────────┐
          │                  │                   │
  ┌───────▼──────┐  ┌───────▼───────┐  ┌────────▼────────┐
  │ Auth Service │  │   Portfolio   │  │    Analytics    │
  │  (Go) :8081  │──│ Service(Java) │  │ Service(Python) │
  └──────┬───────┘  │   :8080      │  │   :8000         │
         │          └───────┬───────┘  └────────┬────────┘
         │                  │                   │
         └──────────┬───────┘───────────────────┘
                    │
            ┌───────▼───────┐
            │ PostgreSQL 16 │ :5432
            └───────────────┘
```

## Components

| Component | Technology | Port | Purpose |
|-----------|-----------|------|---------|
| Frontend | Nginx + React (Vite) | 80 | Web UI & reverse proxy to backends |
| PostgreSQL | PostgreSQL 16 | 5432 | Shared database with isolated schemas |
| Portfolio Service | Java 21 / Spring Boot | 8080 | User, portfolio & holdings management |
| Auth Service | Go / chi router | 8081 | Registration, login & JWT issuance |
| Analytics Service | Python 3.12 / FastAPI | 8000 | Market data & portfolio valuations |

## Server Allocation

You need **5 servers** (EC2 instances recommended: `t3.xlarge` with RHEL 9).

| Server | Component | OS |
|--------|-----------|-----|
| Server 1 | Frontend | RHEL 9 / Amazon Linux 2023 |
| Server 2 | PostgreSQL | RHEL 9 / Amazon Linux 2023 |
| Server 3 | Portfolio Service | RHEL 9 / Amazon Linux 2023 |
| Server 4 | Auth Service | RHEL 9 / Amazon Linux 2023 |
| Server 5 | Analytics Service | RHEL 9 / Amazon Linux 2023 |

## Setup Order

We start with **Frontend first** to demonstrate that the web page loads but no functionality works without backend services. Then we progressively bring up each backend.

1. **Frontend** — Shows the UI but API calls fail (nothing to connect to yet)
2. **PostgreSQL** — Database must be ready before any backend service starts
3. **Portfolio Service** — Core service; Auth Service depends on it during registration
4. **Auth Service** — Depends on PostgreSQL + Portfolio Service
5. **Analytics Service** — Depends on PostgreSQL

> **Important**
> Note down the **private IP address** of each server after creation. Backend services communicate using private IPs. The Frontend server's Nginx reverse proxy uses these private IPs to route API requests.

> **Note**
> After setting up Frontend (Step 1), open it in the browser — you will see the login page but registration/login will fail. As you set up each backend service, functionality will progressively start working.
