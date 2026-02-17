# vps-deploy

A lightweight, open-source bash toolkit for managing multiple virtual domains (static and dynamic Next.js apps) on a single VPS using Caddy and PM2.

## Quick Start

1. **Copy the scripts to your project:**
   ```bash
   cp .env.deploy.example .env.deploy
   ```

2. **Configure `.env.deploy`:**
   ```bash
   VPS_USER=deploy
   VPS_IP=your.vps.ip.address
   DOMAIN=example.com
   DOMAIN_TYPE=static  # or "dynamic"
   # If dynamic:
   DOMAIN_PORT=3000
   ```

3. **Setup the VPS infrastructure:**
   ```bash
   ./setup-vps.sh
   ```

4. **Deploy your code:**
   ```bash
   ./deploy.sh
   ```

## Prerequisites

### VPS Requirements
- Ubuntu 22.04 or 24.04
- SSH access with a non-root user (e.g., `deploy`) with sudo privileges
- Domain DNS pointing to the VPS IP

### Local Requirements
- Bash 4.0+
- `rsync`
- SSH key configured for passwordless login to the VPS

## Configuration

The `.env.deploy` file contains all configuration for your project:

| Variable | Required | Description |
|----------|----------|-------------|
| `VPS_USER` | Yes | SSH user on the VPS (e.g., `deploy`) |
| `VPS_IP` | Yes | IP address or hostname of the VPS |
| `DOMAIN` | Yes | Primary domain for this project |
| `DOMAIN_TYPE` | Yes | Either `static` or `dynamic` |
| `DOMAIN_PORT` | If dynamic | Port the Next.js app listens on (1024-65535) |
| `SSH_KEY` | No | Path to SSH private key (default: `~/.ssh/id_ed25519`) |
| `SSH_PORT` | No | SSH port (default: `22`) |
| `VPS_BASE_PATH` | No | Base path for static sites (default: `/var/www`) |
| `VPS_APPS_PATH` | No | Base path for dynamic apps (default: `/home/deploy/apps`) |
| `BUILD_CMD` | No | Build command (default: `npm run build`) |
| `BUILD_OUTPUT` | No | Build output directory (default: `out`) |
| `PM2_APP_NAME` | No | PM2 process name (defaults to `DOMAIN`) |

## Usage

### `setup-vps.sh`

Provisions and configures the VPS infrastructure. Safe to run multiple times (idempotent).

```bash
./setup-vps.sh              # Setup or update this domain
./setup-vps.sh status       # Show all domains and their status
./setup-vps.sh remove       # Remove this domain from the VPS
./setup-vps.sh --dry-run    # Show what would be done
./setup-vps.sh --verbose    # Detailed output
```

**What it does:**
- Installs Caddy, jq, and (if needed) Node.js + PM2
- Configures UFW firewall (SSH, HTTP, HTTPS)
- Updates the central domain registry at `/etc/caddy/domains.json`
- Creates necessary directories
- Generates and reloads Caddy configuration with SSL
- Sets up PM2 for dynamic apps

### `deploy.sh`

Builds and deploys your code to the VPS.

```bash
./deploy.sh                  # Build and deploy
./deploy.sh --skip-build     # Deploy existing build output
./deploy.sh --dry-run        # Preview rsync without transferring
./deploy.sh --verbose        # Detailed rsync output
```

**Deploy behavior:**

| Aspect | Static | Dynamic |
|--------|--------|---------|
| What is rsynced | `out/` directory | Entire project (excluding `node_modules`, `.next/cache`) |
| Remote target | `/var/www/<domain>/` | `/home/deploy/apps/<domain>/` |
| Post-deploy | None | `npm install --production && npm run build && pm2 restart` |

## How It Works

### Architecture

```
Local Machine                    VPS
─────────────                   ───
my-nextjs-project/          /etc/caddy/
├── .env.deploy             ├── Caddyfile (auto-generated)
├── deploy.sh               ├── domains.json (registry)
├── setup-vps.sh            └── backups/
└── ...                         └── <timestamp>
                           
                            /var/www/
                            ├── example.com/  (static sites)
                            └── anotherexample.com/
                           
                            /home/deploy/apps/
                            └── dynamicapp.com/  (dynamic apps)
                           
                            /var/log/caddy/
                            ├── example.com.log
                            └── dynamicapp.com.log
```

### The Domain Registry (`/etc/caddy/domains.json`)

The VPS maintains a central JSON registry of all configured domains. This allows multiple independent projects to coexist on the same VPS without conflicts.

```json
{
  "version": 1,
  "updated_at": "2025-02-17T10:30:00Z",
  "domains": {
    "example.com": {
      "type": "static",
      "added_at": "2025-02-17T10:00:00Z",
      "updated_at": "2025-02-17T10:00:00Z"
    },
    "dynamicapp.com": {
      "type": "dynamic",
      "port": 3000,
      "app_dir": "/home/deploy/apps/dynamicapp.com",
      "added_at": "2025-02-17T10:10:00Z",
      "updated_at": "2025-02-17T10:30:00Z"
    }
  }
}
```

**Rules:**
- Only `setup-vps.sh` writes to this file
- The Caddyfile is always regenerated from the full registry
- Port conflicts are detected and rejected for dynamic domains

### Caddy Configuration

Each domain gets:
- `www` subdomain redirects to the apex domain
- Automatic HTTPS via Let's Encrypt
- Security headers (X-Content-Type-Options, X-Frame-Options, Referrer-Policy)
- Gzip compression
- Per-domain access logs in `/var/log/caddy/`

Static sites use `file_server`; dynamic apps use `reverse_proxy` to the specified port.

## Adding a New Domain

1. On your local machine, create a new project (or use an existing one)
2. Copy `.env.deploy.example` to `.env.deploy` and fill in the values
3. Run `./setup-vps.sh` to provision the VPS for this domain
4. Run `./deploy.sh` to deploy your code

The scripts will automatically merge your new domain into the existing registry and regenerate the Caddyfile with all domains.

## Switching Between Static and Dynamic

1. Update `.env.deploy`:
   - Change `DOMAIN_TYPE` from `static` to `dynamic` (or vice versa)
   - If switching to dynamic, add `DOMAIN_PORT`
2. Run `./setup-vps.sh` to update the registry and Caddy configuration
3. For dynamic → static: your app directory remains but is no longer used; you may remove it manually
4. For static → dynamic: deploy your Next.js app code to the VPS and start it with PM2

## Manual VPS Setup Guide

For a complete understanding of what the scripts automate, see [`docs/manual-setup-guide.md`](docs/manual-setup-guide.md).

## Troubleshooting

### SSH Connection Fails
- Verify your SSH key is added to the VPS user's `~/.ssh/authorized_keys`
- Check that `VPS_USER`, `VPS_IP`, and `SSH_PORT` are correct
- Test manually: `ssh -p <SSH_PORT> <VPS_USER>@<VPS_IP>`

### Caddy Validation Fails
- Check `/etc/caddy/backups/` for previous Caddyfile versions
- Review the registry: `sudo cat /etc/caddy/domains.json`
- Validate manually: `sudo caddy validate`

### PM2 Process Not Starting
- Check logs: `ssh <VPS_USER>@<VPS_IP> 'pm2 logs <DOMAIN>'`
- Ensure your app listens on the correct port (`DOMAIN_PORT`)
- Verify `package.json` has a `start` script

### Port Conflict Error
Two dynamic domains cannot use the same port. Change the `DOMAIN_PORT` in one of them and re-run `setup-vps.sh`.

### Domain Not Accessible After Deploy
- Verify DNS A record points to the VPS IP
- Check Caddy status: `ssh <VPS_USER>@<VPS_IP> 'systemctl status caddy'`
- View logs: `ssh <VPS_USER>@<VPS_IP> 'sudo tail -f /var/log/caddy/<DOMAIN>.log'`

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License. See [LICENSE](LICENSE) for details.
