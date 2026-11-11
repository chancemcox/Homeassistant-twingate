# Twingate for Home Assistant

Home Assistant add-on repository that runs a **Twingate Connector** and keeps the connection online.

Use Twingate to reach Home Assistant and other home-network devices without opening inbound firewall ports—works well behind CGNAT / Starlink / dynamic IPs.

[![Add repository to Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fchancemcox%2FHomeassistant-twingate)

## Add-ons

### [Twingate Connector](./twingate-connector)

![Supports aarch64](https://img.shields.io/badge/aarch64-yes-green.svg)
![Supports amd64](https://img.shields.io/badge/amd64-yes-green.svg)
![Supports armv7](https://img.shields.io/badge/armv7-yes-green.svg)

Runs the Twingate Connector with:

- Automatic process restart (exponential backoff)
- Controller health probes
- Ingress status UI + Supervisor watchdog
- Host networking for LAN access and peer-to-peer
- Start on boot

## Install

1. In Home Assistant go to **Settings → Add-ons → Add-on store**
2. Menu (⋮) → **Repositories** → add:

   `https://github.com/chancemcox/Homeassistant-twingate`

3. Install **Twingate Connector**
4. Create a Connector in the Twingate Admin Console (Manual deploy)
5. Paste **network**, **access_token**, and **refresh_token** into the add-on config
6. Start the add-on

See [twingate-connector/DOCS.md](./twingate-connector/DOCS.md) for full setup and troubleshooting.

## Repository layout

```text
repository.yaml
twingate-connector/
  config.yaml
  Dockerfile
  run.sh
  healthd.py
  DOCS.md
```
