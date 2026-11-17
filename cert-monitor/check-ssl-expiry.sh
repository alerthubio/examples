#!/usr/bin/env bash
export PATH="/usr/local/bin:/usr/bin:/bin"
# Add ALERTHUB_USER_ID and ALERTHUB_API_KEY as environment variables
ALERTHUB_USER_ID="${ALERTHUB_USER_ID:-YOUR_USER_ID}"
ALERTHUB_API_KEY="${ALERTHUB_API_KEY:-YOUR_API_KEY}"
WARN_DAYS="${WARN_DAYS:-14}"

# Add all production domains you want to monitor
DOMAINS=(
  "example.com"
  "api.example.com"
  "status.example.com"
)

send_alert() {
  local title="$1"
  local body="$2"
  local status="$3"
  local priority="$4"

  local payload
  payload=$(TITLE="$title" BODY="$body" STATUS="$status" PRIORITY="$priority" python3 -c '
import json, os
print(json.dumps({
    "title": os.environ["TITLE"],
    "body": os.environ["BODY"],
    "status": os.environ["STATUS"],
    "priority": os.environ["PRIORITY"],
    "source": "cert-monitor"
}))
')

  curl -fsS -m 5 -X POST "https://alerthub.io/api/event/${ALERTHUB_USER_ID}" \
    -H "X-API-KEY: ${ALERTHUB_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null 2>&1
}

NOW_EPOCH=$(date +%s)

for DOMAIN in "${DOMAINS[@]}"; do
  END_DATE=$(echo | openssl s_client -servername "$DOMAIN" -connect "${DOMAIN}:443" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null \
    | cut -d= -f2)

  if [ -z "$END_DATE" ]; then
    send_alert \
      "SSL check failed: ${DOMAIN}" \
      "Could not retrieve TLS certificate from ${DOMAIN}:443. Check DNS, firewall, or reverse proxy health." \
      "error" \
      "high"
    continue
  fi

  EXPIRY_EPOCH=$(date -d "$END_DATE" +%s)
  DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

  if [ "$DAYS_LEFT" -le 3 ]; then
    send_alert \
      "URGENT: SSL expires in ${DAYS_LEFT} days (${DOMAIN})" \
      "Live TLS certificate for ${DOMAIN} expires on ${END_DATE}. Immediate renewal or proxy reload required." \
      "error" \
      "high"
  elif [ "$DAYS_LEFT" -le "$WARN_DAYS" ]; then
    send_alert \
      "SSL expires in ${DAYS_LEFT} days: ${DOMAIN}" \
      "Live TLS certificate for ${DOMAIN} expires on ${END_DATE}. Auto-renewal may have stalled." \
      "warning" \
      "medium"
  fi
done
