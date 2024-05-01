#!/bin/sh

export CONFIG_FILE="${CONFIG_FILE:=/etc/crowdsec/bouncers/crowdsec-spoa-bouncer.yaml}"

ARGS=""
if [ "$CONFIG_FILE" != "" ]; then
    ARGS="-c $CONFIG_FILE"
fi

# shellcheck disable=SC2086
exec /usr/local/bin/crowdsec-spoa-bouncer $ARGS
