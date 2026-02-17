# Manual VPS Setup Guide

This document describes the manual steps that `setup-vps.sh` automates. It serves as reference documentation for understanding what happens on the VPS during provisioning.

## Prerequisites

- Ubuntu 22.04 or 24.04 VPS
- A non-root user with sudo privileges (e.g., `deploy`)
- SSH access configured

## 1. Initial Server Setup

### 1.1 Update System Packages

```bash
sudo apt update && sudo apt upgrade -y
```

### 1.2 Create Deploy User (if not exists)

```bash
sudo adduser deploy
sudo usermod -aG sudo deploy
```

### 1.3 Setup SSH Key Authentication

On your local machine:

```bash
ssh-copy-id deploy@your.vps.ip
```

Disable password authentication (optional but recommended):

```bash
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo systemctl restart sshd
```

## 2. Install Caddy

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

curl -1sLf 'https://dl.cloudflare.com/caddy/stable/gpg.key' \
  | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudflare.com/caddy/stable/deb/any-version main" \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list

sudo apt update
sudo apt install -y caddy
```

Verify installation:

```bash
caddy version
```

## 3. Install Node.js (for Dynamic Apps)

If you plan to host dynamic Next.js apps:

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install latest LTS
nvm install --lts

# Verify
node --version
npm --version
```

## 4. Install PM2

```bash
npm install -g pm2

# Verify
pm2 --version

# Setup PM2 startup
pm2 startup systemd -u deploy --hp /home/deploy
```

## 5. Install jq (for JSON processing)

```bash
sudo apt install -y jq
```

## 6. Configure Firewall (UFW)

```bash
# Allow SSH, HTTP, HTTPS
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable UFW
sudo ufw --force enable

# Verify
sudo ufw status
```

## 7. Create Directory Structure

```bash
# For static sites
sudo mkdir -p /var/www
sudo chown -R deploy:deploy /var/www

# For dynamic apps
sudo mkdir -p /home/deploy/apps
sudo chown -R deploy:deploy /home/deploy/apps

# For Caddy logs
sudo mkdir -p /var/log/caddy
sudo chown -R www-data:www-data /var/log/caddy
```

## 8. Create Domain Registry

The central registry tracks all domains on the VPS:

```bash
sudo tee /etc/caddy/domains.json > /dev/null <<'EOF'
{
  "version": 1,
  "updated_at": "2025-02-17T10:30:00Z",
  "domains": {}
}
EOF

sudo chmod 644 /etc/caddy/domains.json
```

## 9. Generate Caddyfile

The Caddyfile is generated from the registry. A typical entry looks like:

```caddyfile
# ── example.com (static) ──
www.example.com {
    redir https://example.com{uri} permanent
}

example.com {
    root * /var/www/example.com
    file_server

    try_files {path} {path}.html /index.html

    log {
        output file /var/log/caddy/example.com.log
        format json
    }

    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    encode gzip
}
```

For dynamic apps:

```caddyfile
# ── dynamicapp.com (dynamic, port 3000) ──
www.dynamicapp.com {
    redir https://dynamicapp.com{uri} permanent
}

dynamicapp.com {
    reverse_proxy localhost:3000

    log {
        output file /var/log/caddy/dynamicapp.com.log
        format json
    }

    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    encode gzip
}
```

Save the Caddyfile to `/etc/caddy/Caddyfile` and validate:

```bash
sudo caddy validate
```

If valid, reload:

```bash
sudo systemctl reload caddy
```

## 10. Verify Caddy is Running

```bash
sudo systemctl status caddy
sudo systemctl is-enabled caddy
```

## 11. Deploy Your Code

### For Static Sites

1. Build your Next.js app locally: `npm run build`
2. Copy the `out/` directory to `/var/www/example.com/`:

```bash
scp -r out/* deploy@your.vps.ip:/var/www/example.com/
```

3. Verify: `https://example.com`

### For Dynamic Apps

1. Copy your project to `/home/deploy/apps/example.com/`:

```bash
scp -r . deploy@your.vps.ip:/home/deploy/apps/example.com/
```

2. SSH in and install dependencies:

```bash
ssh deploy@your.vps.ip
cd /home/deploy/apps/example.com
npm install --production
npm run build
```

3. Start with PM2:

```bash
pm2 start npm --name "example.com" -- start
pm2 save
```

4. Verify: `https://example.com`

## 12. SSL Certificates

Caddy automatically obtains and renews SSL certificates from Let's Encrypt. Ensure your domain's DNS A record points to the VPS IP before first access.

Check certificate status:

```bash
sudo caddy list-certificates
```

## 13. Logs

- **Caddy logs:** `/var/log/caddy/<domain>.log`
- **PM2 logs:** `pm2 logs <app-name>`
- **Systemd logs:** `sudo journalctl -u caddy -f`

## 14. Updating Configuration

When adding a new domain:

1. Update `/etc/caddy/domains.json` by adding the new domain entry
2. Regenerate the Caddyfile from the full registry
3. Validate and reload Caddy

When removing a domain:

1. Remove the domain from `/etc/caddy/domains.json`
2. Regenerate the Caddyfile
3. Validate and reload Caddy
4. Optionally stop and delete the PM2 process (for dynamic apps)
5. Optionally delete the site files

## 15. Backup Strategy

Regular backups are recommended:

- **Caddyfile backups:** `/etc/caddy/backups/` (auto-created by scripts)
- **Site files:** Use `rsync` or `tar` to backup `/var/www/` and `/home/deploy/apps/`
- **Registry:** Backup `/etc/caddy/domains.json`
- **PM2 process list:** `pm2 save` creates `~/.pm2/dump.pm2`

## 16. Security Hardening (Optional)

- Fail2ban for brute force protection
- Change SSH port from 22
- Use SSH key authentication only
- Regular security updates: `sudo apt update && sudo apt upgrade -y`
- Configure Caddy security headers (already included in template)
- Enable automatic security updates: `sudo apt install unattended-upgrades`

## 17. Troubleshooting

| Issue | Solution |
|-------|----------|
| Caddy won't start | `sudo caddy validate` to check syntax |
| Port 80/443 in use | Check with `sudo lsof -i:80` |
| SSL certificate not issued | Ensure DNS is propagated, check `/var/log/caddy/` |
| PM2 app not starting | Check logs: `pm2 logs <app>` |
| Permission denied | Ensure files are owned by correct user (`deploy` for apps, `www-data` for Caddy logs) |

---

**Note:** All these steps are automated by `setup-vps.sh`. Use this manual guide for understanding, debugging, or custom setups.
