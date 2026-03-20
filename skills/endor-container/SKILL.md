---
name: endor-container
description: >
  Scan container images and analyze Dockerfiles for security issues. Use when the user
  says "scan my Docker image", "Dockerfile security", "container scan", "endor container",
  "docker compose security", or is creating/modifying Dockerfiles and docker-compose
  files. Checks for root user, latest tags, exposed ports, secrets in build args, and
  missing health checks. Do NOT use for application code scanning (/endor-sast).
---

# Endor Labs Container Security Scanner

Scan container images and analyze Dockerfiles for security issues.

## Workflow

### Dockerfile Analysis

#### Step 1: Find Dockerfiles

Search for `Dockerfile`, `Dockerfile.*`, `docker/Dockerfile`, `*.dockerfile`.

#### Step 2: Check for Security Issues

**Critical:**

| Issue | Pattern | Fix |
|-------|---------|-----|
| Running as root | No `USER` directive | Add `USER nonroot` |
| Using `:latest` tag | `FROM image:latest` | Use specific version tag |
| Secrets in build args | `ARG PASSWORD=...` | Use runtime secrets |
| Sensitive data in COPY | Copying `.env`, keys | Use `.dockerignore` |

**High:**

| Issue | Pattern | Fix |
|-------|---------|-----|
| No health check | Missing `HEALTHCHECK` | Add health check directive |
| Exposed sensitive ports | `EXPOSE 22` (SSH) | Remove unnecessary ports |
| Using ADD for URLs | `ADD http://...` | Use `COPY` + `curl` |

**Medium:**

| Issue | Pattern | Fix |
|-------|---------|-----|
| Package cache not cleaned | `apt-get` without cleanup | Add `rm -rf /var/lib/apt/lists/*` |
| Multiple RUN commands | Many separate `RUN` lines | Combine with `&&` |
| No `.dockerignore` | Missing file | Create `.dockerignore` |
| Using ADD instead of COPY | `ADD` for local files | Use `COPY` |

#### Step 3: Present Analysis

Report issues by severity with line numbers, then provide a secured Dockerfile version:

```dockerfile
FROM node:20-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --chown=appuser:appgroup package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY --chown=appuser:appgroup . .
USER appuser
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -q --spider http://localhost:3000/health || exit 1
EXPOSE 3000
CMD ["node", "server.js"]
```

Include checklist: specific base image tag, non-root user, health check, clean package cache, multi-stage build, `.dockerignore`, `COPY` over `ADD`, no secrets in build args/env.

### Docker Compose Analysis

#### Step 1: Find Compose Files

Search for `docker-compose.yml`, `docker-compose.*.yml`, `compose.yml`, `compose.*.yml`.

#### Step 2: Check for Issues

| Issue | Pattern | Fix |
|-------|---------|-----|
| Privileged mode | `privileged: true` | Remove or use specific capabilities |
| Host network | `network_mode: host` | Use bridge network |
| Docker socket mount | `/var/run/docker.sock` | Remove unless required |
| Sensitive env vars | `PASSWORD=xxx` in env | Use Docker secrets |
| No resource limits | Missing `deploy.resources` | Add CPU/memory limits |
| Ports on 0.0.0.0 | `ports: "3000:3000"` | Use `127.0.0.1:3000:3000` |

#### Step 3: Present Analysis

Report issues per service, then provide secured compose example:

```yaml
version: '3.8'
services:
  app:
    image: app:1.0.0
    read_only: true
    tmpfs:
      - /tmp
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    secrets:
      - db_password
    ports:
      - "127.0.0.1:3000:3000"

secrets:
  db_password:
    external: true
```

### Image Scanning

For built images, scan with:

```bash
npx -y endorctl scan --image {image_name}:{tag} --output-type summary
```

Present results similar to `/endor-scan` output.

## Next Steps

1. `/endor-scan` for application-level vulnerabilities
2. `/endor-cicd` for automated container scanning in CI
3. `/endor-policy` to enforce container security standards

For data source policy, read references/data-sources.md.

## Error Handling

| Error | Action |
|-------|--------|
| No Dockerfile found | Ask for path or offer to create one |
| Docker not installed | Analyze Dockerfiles statically |
| Auth error | Run `/endor-setup` |
