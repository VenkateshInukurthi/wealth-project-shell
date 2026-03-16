# 02-PostgreSQL

PostgreSQL is the shared database for the Wealth Management Platform. All three microservices connect to the same PostgreSQL 16 instance but use **separate schemas** for data isolation.

| Schema | Used By |
|--------|---------|
| `auth_schema` | Auth Service |
| `portfolio_schema` | Portfolio Service |
| `analytics_schema` | Analytics Service |

> **Hint**
> **PostgreSQL 16 is not available in default RHEL 9 repos. We need to add the official PostgreSQL YUM repository first.**

## Install PostgreSQL Repository

```shell
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
```

Disable the built-in PostgreSQL module to avoid version conflicts.

```shell
dnf -qy module disable postgresql
```

> **Note**
> RHEL 9 ships with an older PostgreSQL version as a module. We must disable it so `dnf` picks up version 16 from the PGDG repo.

## Install PostgreSQL 16

```shell
dnf install -y postgresql16-server postgresql16
```

## Initialize & Start

> **Note**
> The `initdb` step creates the initial database cluster. This only needs to be run **once**. If you see "Data directory is not empty", it means it was already initialized.

```shell
/usr/pgsql-16/bin/postgresql-16-setup initdb
```

Enable and start the service.

```shell
systemctl enable postgresql-16
systemctl start postgresql-16
```

> **Important**
> Note that the service name is `postgresql-16` (not `postgresql`). The binaries are located at `/usr/pgsql-16/bin/`. This is specific to the PGDG repository.

## Configure Network Access

By default, PostgreSQL only listens on localhost. Since our microservices run on different servers, we need to allow remote connections.

Edit the PostgreSQL configuration file.

```shell
vim /var/lib/pgsql/16/data/postgresql.conf
```

Find the `listen_addresses` line and update it.

```ini title=/var/lib/pgsql/16/data/postgresql.conf
listen_addresses = '*'
```

> **Note**
> The config file path is `/var/lib/pgsql/16/data/` (note the `16` in the path). This is the PGDG layout, different from the default RHEL PostgreSQL.

## Configure Authentication

Edit the host-based authentication file to allow password-based connections from other servers.

```shell
vim /var/lib/pgsql/16/data/pg_hba.conf
```

Add the following line **at the end** of the file.

```text title=/var/lib/pgsql/16/data/pg_hba.conf
host    all    all    0.0.0.0/0    scram-sha-256
```

Also change the local authentication method from `peer` to `trust` so we can run the setup SQL.

Find this line:

```
local   all             all                                     peer
```

Change it to:

```
local   all             all                                     trust
```

> **Note**
> `scram-sha-256` means remote clients must authenticate with a password. `trust` for local connections lets us run `psql` as the `postgres` user without a password prompt. In production, restrict `0.0.0.0/0` to your VPC CIDR range.

Restart PostgreSQL to apply the changes.

```shell
systemctl restart postgresql-16
```

## Create Database, Schemas & Users

Connect to PostgreSQL as the `postgres` superuser.

```shell
sudo -u postgres /usr/pgsql-16/bin/psql
```

> **Important**
> Use the full path `/usr/pgsql-16/bin/psql` — the PGDG version may not be in the default `PATH`.

Create the `wmp` database.

```sql
CREATE DATABASE wmp;
\c wmp
```

Create schemas for each microservice.

```sql
CREATE SCHEMA IF NOT EXISTS portfolio_schema;
CREATE SCHEMA IF NOT EXISTS analytics_schema;
CREATE SCHEMA IF NOT EXISTS auth_schema;
```

> **Important**
> Replace `localdev123` below with strong passwords in production environments.

Create service-specific database users.

```sql
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'portfolio_svc_user') THEN
        CREATE ROLE portfolio_svc_user WITH LOGIN PASSWORD 'localdev123';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'analytics_svc_user') THEN
        CREATE ROLE analytics_svc_user WITH LOGIN PASSWORD 'localdev123';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'auth_svc_user') THEN
        CREATE ROLE auth_svc_user WITH LOGIN PASSWORD 'localdev123';
    END IF;
END
$$;
```

## Grant Permissions

Grant permissions for **Portfolio Service** user.

```sql
GRANT USAGE, CREATE ON SCHEMA portfolio_schema TO portfolio_svc_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA portfolio_schema TO portfolio_svc_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA portfolio_schema TO portfolio_svc_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA portfolio_schema GRANT ALL ON TABLES TO portfolio_svc_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA portfolio_schema GRANT ALL ON SEQUENCES TO portfolio_svc_user;
```

Grant permissions for **Analytics Service** user.

```sql
GRANT USAGE, CREATE ON SCHEMA analytics_schema TO analytics_svc_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA analytics_schema TO analytics_svc_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA analytics_schema TO analytics_svc_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics_schema GRANT ALL ON TABLES TO analytics_svc_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics_schema GRANT ALL ON SEQUENCES TO analytics_svc_user;
GRANT USAGE ON SCHEMA portfolio_schema TO analytics_svc_user;
GRANT SELECT ON ALL TABLES IN SCHEMA portfolio_schema TO analytics_svc_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA portfolio_schema GRANT SELECT ON TABLES TO analytics_svc_user;
```

> **Note**
> Analytics Service gets **read-only** access to `portfolio_schema` for cross-referencing portfolio data in valuations.

Grant permissions for **Auth Service** user.

```sql
GRANT USAGE, CREATE ON SCHEMA auth_schema TO auth_svc_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth_schema TO auth_svc_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth_schema TO auth_svc_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth_schema GRANT ALL ON TABLES TO auth_svc_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth_schema GRANT ALL ON SEQUENCES TO auth_svc_user;
```

Exit psql.

```sql
\q
```

## Verification

Verify PostgreSQL is running.

```shell
systemctl status postgresql-16
```

Test a local connection.

```shell
sudo -u postgres /usr/pgsql-16/bin/psql -d wmp -c "\dn"
```

You should see the three schemas listed: `auth_schema`, `analytics_schema`, `portfolio_schema`.

Test remote connectivity from another server (e.g., the Portfolio server).

```shell
psql -h localhost -U portfolio_svc_user -d wmp -c "SELECT current_schema();"
```
