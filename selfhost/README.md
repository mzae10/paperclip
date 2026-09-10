# Self-hosting Paperclip AI (LAN-only) with Docker Compose

A production-shaped, **LAN-only** deployment of this fork, built **from source**
so your own changes ship in the image.

- **Not internet-facing.** `authenticated` + `private`: login required,
  reachable across your LAN, no public exposure.
- **External PostgreSQL 17** (the documented production database).
- **Agents run inside the server container** using the baked-in CLIs
  (claude / codex / gemini / opencode / kimi). No Docker socket is mounted.

Everything here lives in this `selfhost/` directory; the server image is built
from the repo root (this fork).

---

## Quick start

```bash
cd selfhost
cp .env.example .env

# Generate the required secrets and paste them into .env:
openssl rand -hex 32   # -> BETTER_AUTH_SECRET
openssl rand -hex 32   # -> PAPERCLIP_TOOL_ACTION_SIGNING_SECRET
openssl rand -hex 24   # -> POSTGRES_PASSWORD

# Set PAPERCLIP_PUBLIC_URL to your LAN address, e.g. http://192.168.1.50:3100,
# and add that IP/hostname to PAPERCLIP_ALLOWED_HOSTNAMES.

docker compose up -d --build      # first build compiles from source (~10-30 min)
docker compose logs -f server     # migrations run automatically on boot
docker compose ps                 # wait for 'healthy'
```

Open `http://<your-LAN-IP>:3100` from any LAN machine.

## First admin, then lock down signup

1. Open the URL and **create an account**.
2. Choose **“Claim this instance”** on the setup screen → you become admin.
   (CLI fallback: `docker compose exec server node cli/dist/index.js auth bootstrap-ceo`.)
3. Set `PAPERCLIP_AUTH_DISABLE_SIGN_UP=true` in `.env` and `docker compose up -d`
   to stop open registration on the LAN.

## Add LLM keys

Put provider keys in `.env` (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`,
`GEMINI_API_KEY`/`GOOGLE_API_KEY`, `OPENROUTER_API_KEY`, `XAI_API_KEY`) — or add
them per agent/company in the UI Secrets Manager for better isolation.

---

## Staying current with the original repo

This fork keeps two remotes:

| Remote     | Points at                          | Use               |
|------------|------------------------------------|-------------------|
| `origin`   | your fork                          | push / pull       |
| `upstream` | `paperclipai/paperclip` (original) | fetch updates     |

If `upstream` isn't set yet:
```bash
git remote add upstream https://github.com/paperclipai/paperclip.git
```

Pull the latest and rebuild:
```bash
cd selfhost && ./update.sh        # fetch upstream, merge, rebuild, restart
```
Or by hand: `git fetch upstream && git merge upstream/master`, then
`docker compose up -d --build`. Or click **“Sync fork”** on GitHub.

> For stability, check out a release tag instead of tracking `master`:
> `git checkout $(git tag | tail -1)` then rebuild.

---

## Day-2 operations

```bash
docker compose ps                 # status + health
docker compose logs -f server     # app logs (JSON, rotated 10m x5)
docker compose up -d --build      # apply code/.env changes
docker compose down               # stop (data volumes are kept)
```

### Backups (do both together)

```bash
# Database
docker compose exec -T db pg_dump -U paperclip paperclip | gzip > db-$(date +%F).sql.gz
# App data volume (holds the secrets master key — without it secrets are lost)
docker run --rm -v paperclip_paperclip-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/data-$(date +%F).tgz -C /data .
```

---

## Security notes

- Keep it on a **trusted LAN**; don't port-forward `3100`. For remote access use
  a VPN/Tailscale or a TLS-terminating reverse proxy (then switch
  `PAPERCLIP_PUBLIC_URL` to `https://`, set `TRUST_PROXY`, bind loopback).
- **Agents are unsandboxed inside the container** and can read its env (provider
  keys) and everything under `/paperclip`. Isolation comes from the container +
  your trusted network. The Docker socket is intentionally not mounted.
- Postgres is not published; `.env` (real secrets) is git-ignored.

## Troubleshooting

| Symptom | Fix |
|---|---|
| 403 "hostname is not allowed" | Add the IP/hostname to `PAPERCLIP_ALLOWED_HOSTNAMES`, `docker compose up -d`. |
| Logged out right after login | `PAPERCLIP_PUBLIC_URL` is `https://` without TLS. Use `http://` on a plain-HTTP LAN. |
| Won't start | `docker compose logs server`; usually DB not ready (it waits) or a provider key issue. |
| Data volume permission errors | Set `USER_UID`/`USER_GID` in `.env` to the host owner and `docker compose build`. |
