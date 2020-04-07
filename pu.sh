#!/usr/bin/env bash

# pu.sh
# A bash script to send iOS push notifications with the HTTP/2 Apple Push Notification service (APNs)
# License: This project is licensed under the MIT License
# Author: Eugene Egorov
#
# Based on pu.sh project: https://github.com/tsif/pu.sh
# License: This project is licensed under the MIT License
# Author: Dimitri James Tsiflitzis
#
# Dependencies: OpenSSL, cURL
# Usually could be installed using Homebrew: brew install openssl curl
#
# APNs HTTP/2 API documentation
# https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html

SCRIPT=`basename $0`
ENV_DEV="development"
ENV_PROD="production"

if [ $# -lt 7 ]; then
    HELP="Usage:
    $SCRIPT TEAM_ID KEY_ID KEY_FILE BUNDLE_ID ENVIRONMENT DEVICE_TOKEN PAYLOAD
Parameters:
    TEAM_ID         - team identifier from App Store Connect
    KEY_ID          - APNs key idenfifier
    KEY_FILE        - path to .p8 key file
    BUNDLE_ID       - bundle idenfifier
    ENVIRONMENT     - environment for APNS server, \"$ENV_DEV\" or \"$ENV_PROD\"
        for debug builds it should be \"$ENV_DEV\", for release (ad-hoc, app store) builds it should be \"$ENV_PROD\"
    DEVICE_TOKEN    - hexadecimal string representation of device token
        received in \"func application(_ application:, didRegisterForRemoteNotificationsWithDeviceToken:)\"
    PAYLOAD         - json payload of notification, raw '{\"aps\": { \"alert\": \"Notification\"}' or file '@path_to_json'"
    echo "$HELP"
    exit 1
fi

TEAM_ID="$1"
KEY_ID="$2"
KEY_FILE="$3"
BUNDLE_ID="$4"
ENVIRONMENT="$5"
DEVICE_TOKEN="$6"
PAYLOAD="$7"

case "$ENVIRONMENT" in
    "$ENV_DEV")
        ENDPOINT="https://api.sandbox.push.apple.com:443"
        ;;
    "$ENV_PROD")
        ENDPOINT="https://api.push.apple.com:443"
        ;;
    *)
        echo "ENVIRONMENT should be \"$ENV_DEV\" or \"$ENV_PROD\""
        exit 1
esac

function base64URLSafe {
    openssl base64 -e -A | tr -- '+/' '-_' | tr -d =
}

function sign {
    printf "$1" | openssl dgst -binary -sha256 -sign "$KEY_FILE" | base64URLSafe
}

TIME=$(date +%s)
HEADER=$(printf '{ "alg": "ES256", "kid": "%s" }' "$KEY_ID" | base64URLSafe)
CLAIMS=$(printf '{ "iss": "%s", "iat": %d }' "$TEAM_ID" "$TIME" | base64URLSafe)
JWT="$HEADER.$CLAIMS.$(sign $HEADER.$CLAIMS)"

URL=$ENDPOINT/3/device/$DEVICE_TOKEN

curl -i \
    --http2 \
    --header "authorization: bearer $JWT" \
    --header "apns-topic: ${BUNDLE_ID}" \
    --header "Content-Type: application/json" \
    --data-binary "${PAYLOAD}" \
    "${URL}"
