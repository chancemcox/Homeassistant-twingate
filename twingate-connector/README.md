# Twingate Connector

Home Assistant add-on that runs a [Twingate](https://www.twingate.com/) Connector and **keeps it connected**.

Use it to reach Home Assistant and other devices on your home network through Twingate—no inbound firewall ports required.

## What it does

- Runs the official Twingate Connector inside Home Assistant OS / Supervised
- Restarts the connector automatically if the process exits (exponential backoff)
- Probes your Twingate controller on a schedule and surfaces status in the UI
- Exposes an Ingress status page and a `/health` endpoint for the Supervisor watchdog
- Starts on boot (`boot: auto`) and uses host networking for LAN + peer-to-peer access

## Quick start

1. Add this repository in **Settings → Add-ons → Add-on store → ⋮ → Repositories**
2. Install **Twingate Connector**
3. In the Twingate Admin Console, create a Connector (Manual deploy) and copy the tokens
4. Configure the add-on with your network slug, access token, and refresh token
5. Start the add-on and open the Ingress UI to confirm status
