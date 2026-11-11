ARG BUILD_FROM
FROM ${BUILD_FROM}

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install Twingate Connector at build time so startup stays fast and reliable
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        python3 \
    && curl -fsSL https://packages.twingate.com/apt/gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/twingate-connector-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/twingate-connector-keyring.gpg] https://packages.twingate.com/apt/ /" \
        > /etc/apt/sources.list.d/twingate.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends twingate-connector \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && test -x /usr/bin/twingate-connector

COPY run.sh /run.sh
COPY healthd.py /usr/bin/twingate-healthd
RUN chmod a+x /run.sh /usr/bin/twingate-healthd

CMD ["/run.sh"]
