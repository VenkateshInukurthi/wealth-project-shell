# 03-Portfolio Service

Portfolio Service is the core microservice responsible for managing users, portfolios, and holdings. It is built with **Java 21** and **Spring Boot**, using **Gradle** as the build tool.

> **Hint**
> **Developer has chosen Java 21 with Spring Boot. We use OpenJDK 21 which is available in the RHEL 9 AppStream repository.**

> **Dependency**
> Portfolio Service depends on **PostgreSQL**. Ensure PostgreSQL is set up and running before starting this service.

## Install Java 21

> **Note**
> We install the full JDK (`-devel`) because we need to build the application from source on this server using Gradle. Amazon Corretto is **not** available in default RHEL repos — use `java-21-openjdk-devel` instead.

```shell
dnf install -y java-21-openjdk-devel
```

Verify the installation.

```shell
java -version
```

## Configure the Application

> **Recap**
> Applications should run as a non-root user for security.

Add application user.

```shell
useradd -r -s /bin/false appuser
```

> **Note**
> User **appuser** is a system / daemon user to run the application. We don't use this user to login to the server.

Create the application directory.

```shell
mkdir -p /app
```

## Download & Build

Download and extract the application source code directly to the application directory.

```shell
curl -L -o /tmp/portfolio-service.tar.gz https://raw.githubusercontent.com/raghudevopsb88/wealth-project/main/artifacts/portfolio-service.tar.gz
cd /app
tar xzf /tmp/portfolio-service.tar.gz
```

Build the application using Gradle.

```shell
cd /app
chmod +x gradlew
./gradlew bootJar --no-daemon -x test
```

> **Hint**
> **The `-x test` flag skips tests during build to save time. The built JAR will be in `build/libs/` directory. The first build takes a few minutes as Gradle downloads dependencies.**

Copy the built JAR and set ownership.

```shell
cp /app/build/libs/*.jar /app/portfolio-service.jar
chown -R appuser:appuser /app
chmod o-rwx /app -R
```

## Setup SystemD Service

We need to set up a new service in **systemd** so `systemctl` can manage this service.

> **Note**
> You can create this file using **`vim /etc/systemd/system/portfolio-service.service`**

```ini title=/etc/systemd/system/portfolio-service.service
[Unit]
Description=WMP Portfolio Service
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/app
ExecStart=/usr/bin/java -jar portfolio-service.jar
Restart=on-failure
RestartSec=10

Environment=SPRING_PROFILES_ACTIVE=production
Environment=SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/wmp?currentSchema=portfolio_schema
Environment=SPRING_DATASOURCE_USERNAME=portfolio_svc_user
Environment=SPRING_DATASOURCE_PASSWORD=localdev123
Environment=JWT_SECRET=myDefaultSuperSecretKeyThatIsAtLeast256BitsLongForHS256Algorithm
Environment=SERVER_PORT=8080

[Install]
WantedBy=multi-user.target
```

> **Important**
> Replace `localhost` with the **private IP address** of your PostgreSQL server.

Load the service.

```shell
systemctl daemon-reload
```

> **Note**
> This above command is because we added a new service. We are telling systemd to reload so it will detect the new service.

Start the service.

```shell
systemctl enable portfolio-service
systemctl start portfolio-service
```

> **Re-deployment Note**
> If you are re-deploying (updating the JAR), you must **stop the service first** before copying the new JAR, then start it again:
> ```shell
> systemctl stop portfolio-service
> cd /app && tar xzf /tmp/portfolio-service.tar.gz
> chmod +x gradlew && ./gradlew bootJar --no-daemon -x test
> cp /app/build/libs/*.jar /app/portfolio-service.jar
> systemctl start portfolio-service
> ```

## Verification

Check the service status.

```shell
systemctl status portfolio-service
```

Check the application logs if needed.

```shell
journalctl -u portfolio-service -f
```

> **Hint**
> **The Portfolio Service takes about 30-40 seconds to start up because Spring Boot needs to initialize and run Flyway database migrations.**

Verify the health endpoint is responding.

```shell
curl http://localhost:8080/actuator/health
```

Expected response:

```json
{"status":"UP"}
```

> **Note**
> After this service is running, go back to the **Frontend** browser and try again — API calls to `/api/v1/portfolios/` and `/api/v1/users/` should now be proxied correctly (though auth will still fail until Auth Service is set up).
