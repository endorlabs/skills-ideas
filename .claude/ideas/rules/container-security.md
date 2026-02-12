# Container Security Rule

Analyze Dockerfiles and container configurations for security best practices.

## Trigger

This rule activates when:
- Creating or modifying a Dockerfile
- Creating or modifying docker-compose files
- Working with container configurations

## Security Checks

### Critical Issues
- **Running as root**: No `USER` directive -> Add `USER nonroot`
- **Using `:latest` tag**: Non-deterministic builds -> Use specific version tags
- **Secrets in build args**: `ARG PASSWORD=...` -> Use runtime secrets

### High Issues
- **No health check**: Missing `HEALTHCHECK` -> Add health check directive
- **Privileged containers**: `privileged: true` -> Use specific capabilities instead

### Medium Issues
- **Package cache not cleaned**: Add `rm -rf /var/lib/apt/lists/*`
- **Multiple RUN commands**: Combine with `&&` to reduce layers
- **Using ADD instead of COPY**: Use `COPY` for local files

### Docker Compose
- No environment variables with secrets (use Docker secrets)
- No `privileged: true`
- Bind ports to `127.0.0.1`, not `0.0.0.0`
- Set resource limits

## Do Not Ignore

Even for development Dockerfiles, apply security best practices. Insecure patterns in dev often make it to production.
