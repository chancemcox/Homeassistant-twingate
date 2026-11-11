#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

STATUS_FILE="/data/twingate-status.json"
CONFIG_FILE="/etc/twingate/connector.conf"
CONNECTOR_BIN="/usr/bin/twingate-connector"
HEALTH_PORT=8099

CONNECTOR_PID=""
HEALTH_PID=""
RESTARTS=0
STARTED_AT=""
LAST_RESTART_AT=""

log_level_to_int() {
    case "$1" in
        error) echo 1 ;;
        warning) echo 2 ;;
        info) echo 3 ;;
        debug) echo 7 ;;
        *) echo 3 ;;
    esac
}

iso_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

write_status() {
    local connector_running="$1"
    local controller_reachable="$2"
    local message="$3"
    local ok="false"

    if [[ "${connector_running}" == "true" && "${controller_reachable}" == "true" ]]; then
        ok="true"
    fi

    cat >"${STATUS_FILE}" <<EOF
{
  "ok": ${ok},
  "connector_running": ${connector_running},
  "controller_reachable": ${controller_reachable},
  "restarts": ${RESTARTS},
  "started_at": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "${STARTED_AT}"),
  "last_restart_at": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1] or None))' "${LAST_RESTART_AT}"),
  "last_check_at": "$(iso_now)",
  "message": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "${message}"),
  "network": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "${TWINGATE_NETWORK}")
}
EOF
}

controller_reachable() {
    local url="https://${TWINGATE_NETWORK}.twingate.com/api/v1/public_keys"
    if curl -fsS --connect-timeout 8 --max-time 12 "${url}" >/dev/null; then
        return 0
    fi
    return 1
}

cleanup() {
    bashio::log.info "Shutting down Twingate Connector add-on"
    if [[ -n "${CONNECTOR_PID}" ]] && kill -0 "${CONNECTOR_PID}" 2>/dev/null; then
        kill "${CONNECTOR_PID}" 2>/dev/null || true
        wait "${CONNECTOR_PID}" 2>/dev/null || true
    fi
    if [[ -n "${HEALTH_PID}" ]] && kill -0 "${HEALTH_PID}" 2>/dev/null; then
        kill "${HEALTH_PID}" 2>/dev/null || true
        wait "${HEALTH_PID}" 2>/dev/null || true
    fi
    write_status "false" "false" "stopped"
}

trap cleanup EXIT INT TERM

# --- configuration ---
TWINGATE_NETWORK="$(bashio::config 'network')"
TWINGATE_ACCESS_TOKEN="$(bashio::config 'access_token')"
TWINGATE_REFRESH_TOKEN="$(bashio::config 'refresh_token')"
LOG_LEVEL="$(bashio::config 'log_level')"
LOG_ANALYTICS="$(bashio::config 'log_analytics')"
DNS="$(bashio::config 'dns')"
HEALTH_INTERVAL="$(bashio::config 'health_interval')"
RESTART_DELAY="$(bashio::config 'restart_delay')"
MAX_RESTART_DELAY="$(bashio::config 'max_restart_delay')"

# Trim accidental whitespace from UI paste without mangling token characters
TWINGATE_NETWORK="${TWINGATE_NETWORK#"${TWINGATE_NETWORK%%[![:space:]]*}"}"
TWINGATE_NETWORK="${TWINGATE_NETWORK%"${TWINGATE_NETWORK##*[![:space:]]}"}"
TWINGATE_ACCESS_TOKEN="${TWINGATE_ACCESS_TOKEN#"${TWINGATE_ACCESS_TOKEN%%[![:space:]]*}"}"
TWINGATE_ACCESS_TOKEN="${TWINGATE_ACCESS_TOKEN%"${TWINGATE_ACCESS_TOKEN##*[![:space:]]}"}"
TWINGATE_REFRESH_TOKEN="${TWINGATE_REFRESH_TOKEN#"${TWINGATE_REFRESH_TOKEN%%[![:space:]]*}"}"
TWINGATE_REFRESH_TOKEN="${TWINGATE_REFRESH_TOKEN%"${TWINGATE_REFRESH_TOKEN##*[![:space:]]}"}"

if ! bashio::config.has_value 'network' || [[ -z "${TWINGATE_NETWORK}" ]]; then
    bashio::log.fatal "Option 'network' is required (your Twingate subdomain, e.g. acme for acme.twingate.com)."
    exit 1
fi
if ! bashio::config.has_value 'access_token' || [[ -z "${TWINGATE_ACCESS_TOKEN}" ]]; then
    bashio::log.fatal "Option 'access_token' is required. Create a Connector in the Twingate Admin Console and paste the Manual deploy tokens."
    exit 1
fi
if ! bashio::config.has_value 'refresh_token' || [[ -z "${TWINGATE_REFRESH_TOKEN}" ]]; then
    bashio::log.fatal "Option 'refresh_token' is required. Create a Connector in the Twingate Admin Console and paste the Manual deploy tokens."
    exit 1
fi

TWINGATE_LOG_LEVEL="$(log_level_to_int "${LOG_LEVEL}")"
TWINGATE_LABEL_HOSTNAME="$(hostname)"
TWINGATE_LABEL_DEPLOYED_BY="home_assistant"
export TWINGATE_NETWORK TWINGATE_ACCESS_TOKEN TWINGATE_REFRESH_TOKEN TWINGATE_LOG_LEVEL
export TWINGATE_LABEL_HOSTNAME TWINGATE_LABEL_DEPLOYED_BY

if [[ "${LOG_ANALYTICS}" == "true" ]]; then
    export TWINGATE_LOG_ANALYTICS="v2"
fi

if bashio::config.has_value 'dns' && [[ -n "${DNS}" ]]; then
    export TWINGATE_DNS="${DNS}"
fi

install -d -m 0700 "$(dirname "${CONFIG_FILE}")"
{
    echo "TWINGATE_NETWORK=${TWINGATE_NETWORK}"
    echo "TWINGATE_ACCESS_TOKEN=${TWINGATE_ACCESS_TOKEN}"
    echo "TWINGATE_REFRESH_TOKEN=${TWINGATE_REFRESH_TOKEN}"
    echo "TWINGATE_LOG_LEVEL=${TWINGATE_LOG_LEVEL}"
    echo "TWINGATE_LABEL_HOSTNAME=${TWINGATE_LABEL_HOSTNAME}"
    echo "TWINGATE_LABEL_DEPLOYED_BY=${TWINGATE_LABEL_DEPLOYED_BY}"
    if [[ -n "${TWINGATE_LOG_ANALYTICS:-}" ]]; then
        echo "TWINGATE_LOG_ANALYTICS=${TWINGATE_LOG_ANALYTICS}"
    fi
    if [[ -n "${TWINGATE_DNS:-}" ]]; then
        echo "TWINGATE_DNS=${TWINGATE_DNS}"
    fi
} >"${CONFIG_FILE}"
chmod 0600 "${CONFIG_FILE}"

mkdir -p /data
STARTED_AT="$(iso_now)"
write_status "false" "false" "starting health endpoint"

export TWINGATE_STATUS_FILE="${STATUS_FILE}"
export TWINGATE_HEALTH_PORT="${HEALTH_PORT}"
/usr/bin/twingate-healthd &
HEALTH_PID=$!
bashio::log.info "Health endpoint listening on :${HEALTH_PORT} (ingress + /health)"

current_delay="${RESTART_DELAY}"

bashio::log.info "Maintaining Twingate Connector for network '${TWINGATE_NETWORK}'"
bashio::log.info "Health interval=${HEALTH_INTERVAL}s, restart delay=${RESTART_DELAY}s (max ${MAX_RESTART_DELAY}s)"

while true; do
    if [[ ! -x "${CONNECTOR_BIN}" ]]; then
        bashio::log.fatal "twingate-connector binary not found at ${CONNECTOR_BIN}"
        write_status "false" "false" "connector binary missing"
        exit 1
    fi

    bashio::log.info "Starting twingate-connector"
    "${CONNECTOR_BIN}" &
    CONNECTOR_PID=$!
    write_status "true" "false" "connector started; probing controller"

    # Reset backoff after a successful sustained run
    healthy_ticks=0

    while kill -0 "${CONNECTOR_PID}" 2>/dev/null; do
        reachable="false"
        message="connector running"
        if controller_reachable; then
            reachable="true"
            message="connected"
            healthy_ticks=$((healthy_ticks + 1))
            if [[ "${healthy_ticks}" -ge 3 ]]; then
                current_delay="${RESTART_DELAY}"
            fi
        else
            message="connector running; controller unreachable"
            bashio::log.warning "${message}"
            healthy_ticks=0
        fi
        write_status "true" "${reachable}" "${message}"
        sleep "${HEALTH_INTERVAL}"
    done

    set +e
    wait "${CONNECTOR_PID}"
    exit_code=$?
    set -e
    CONNECTOR_PID=""
    RESTARTS=$((RESTARTS + 1))
    LAST_RESTART_AT="$(iso_now)"
    write_status "false" "false" "connector exited (code ${exit_code}); restarting in ${current_delay}s"
    bashio::log.error "twingate-connector exited with code ${exit_code}; restart ${RESTARTS} in ${current_delay}s"

    sleep "${current_delay}"
    current_delay=$((current_delay * 2))
    if [[ "${current_delay}" -gt "${MAX_RESTART_DELAY}" ]]; then
        current_delay="${MAX_RESTART_DELAY}"
    fi
done
