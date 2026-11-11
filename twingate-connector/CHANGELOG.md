# Changelog

## 1.0.1

- Fix Ingress showing the wrong app on host networking by using a Supervisor-assigned port (`ingress_port: 0`) instead of fixed `8099` (collided with HomeScan and similar apps)

## 1.0.0

- Initial release
- Runs Twingate Connector with host networking
- Automatic restart with exponential backoff when the process exits
- Controller reachability probes and Ingress status page
- Supervisor `/health` endpoint
- Configurable log level, analytics, DNS, and health intervals
