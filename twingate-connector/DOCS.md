# Twingate Connector

This add-on installs and supervises a Twingate Connector so devices on your home network stay reachable through Twingate.

## Prerequisites

1. A Twingate account and Remote Network for your home
2. Home Assistant OS or Supervised (add-on support required)
3. Outbound internet from the Home Assistant host:
   - TCP 443 to Twingate Controller / Relays
   - TCP 30000–31000 when peer-to-peer is unavailable
   - UDP / QUIC for peer-to-peer where possible

## Setup

1. Install this add-on from the repository
2. Open the [Twingate Admin Console](https://www.twingate.com/)
3. Create (or select) a Remote Network for your home
4. Add a Connector and choose **Manual** deployment
5. Copy the **Access Token**, **Refresh Token**, and note your network slug  
   (the `acme` in `https://acme.twingate.com`)
6. In the add-on **Configuration** tab, set:
   - **network** — Twingate network slug
   - **access_token** — Connector access token
   - **refresh_token** — Connector refresh token
7. Start the add-on
8. In Twingate, confirm the Connector shows **Online**
9. Create Resources for Home Assistant (and anything else you need) on that Remote Network

Official walkthrough: [Getting started with Home Assistant](https://www.twingate.com/docs/home-assistant-getting-started)

## How the connection is maintained

| Mechanism | Behavior |
| --- | --- |
| Process watchdog | If `twingate-connector` exits, the add-on restarts it with exponential backoff |
| Controller probe | Every `health_interval` seconds, probes `https://<network>.twingate.com/api/v1/public_keys` |
| Start on boot | `boot: auto` so the Connector returns after host reboots |
| Host network | Uses the host network stack so the Connector can reach LAN devices and peer-to-peer peers |
| Dynamic Ingress port | On host networking, Supervisor assigns a free high port so the status UI does not collide with other apps (for example HomeScan on 8099) |

Open the add-on UI (Ingress) for a live status page, or call `/status` for JSON.

## Configuration options

| Option | Description |
| --- | --- |
| `network` | Twingate network slug (required) |
| `access_token` | Connector access token (required, secret) |
| `refresh_token` | Connector refresh token (required, secret) |
| `log_level` | `error`, `warning`, `info` (default), or `debug` |
| `log_analytics` | Emit Connector analytics / network events in the logs (default `true`) |
| `dns` | Optional DNS server for Connector name resolution |
| `health_interval` | Seconds between controller probes (default `60`) |
| `restart_delay` | Initial seconds to wait before restarting a crashed connector (default `5`) |
| `max_restart_delay` | Cap for restart backoff in seconds (default `300`) |

## Tokens

Each Connector’s tokens are unique. Do not run two Connectors with the same token pair. If you regenerate tokens in the Admin Console, update the add-on configuration and restart it.

## Troubleshooting

**Connector flapping or `Invalid token`**

- Twingate is sensitive to clock skew greater than ~5 seconds. Ensure the Home Assistant host keeps accurate time (NTP / chrony).

**Controller unreachable in the status page**

- Confirm outbound HTTPS from the host
- Confirm `network` matches your tenant subdomain exactly
- Check the add-on logs for TLS or DNS errors

**Connector online but Resources fail**

- Verify Resources point at addresses the Home Assistant host can route to
- Prefer hostnames/IPs on the LAN; this add-on runs with host networking for that reason

**Add-on UI shows another app (e.g. HomeScan)**

- Update to add-on version **1.0.1+** (uses a dynamic Ingress port on host networking)
- Restart the Twingate Connector add-on after updating

**Add-on keeps restarting**

- Open logs for connector crash reasons
- Invalid or revoked tokens cause repeated failures—regenerate and update config
- `/health` returns 503 only when the connector process is not running

## Support

- Twingate docs: https://www.twingate.com/docs/
- Connector failures guide: https://www.twingate.com/docs/connector-failures
