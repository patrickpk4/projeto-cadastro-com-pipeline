#!/usr/bin/env bash

set -u

BASE_URL="${API_BASE_URL:-http://aeabf9915f3664e6c83aef32c5cbc2c4-766385586.us-east-2.elb.amazonaws.com}"
REQUESTS="${REQUESTS:-60}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-1}"

if ! [[ "$REQUESTS" =~ ^[1-9][0-9]*$ ]]; then
  echo "REQUESTS must be a positive integer" >&2
  exit 2
fi

if ! [[ "$INTERVAL_SECONDS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "INTERVAL_SECONDS must be a non-negative number" >&2
  exit 2
fi

BASE_URL="${BASE_URL%/}"
ENDPOINTS=("/Produto" "/health" "/swagger/index.html")
FAILURES=0

echo "Sending $REQUESTS GET requests to $BASE_URL (interval: ${INTERVAL_SECONDS}s)"

for ((i = 0; i < REQUESTS; i++)); do
  endpoint="${ENDPOINTS[$((i % ${#ENDPOINTS[@]}))]}"

  if result="$(curl --silent --show-error --output /dev/null \
    --write-out '%{http_code} %{time_total}' \
    --max-time 10 \
    "${BASE_URL}${endpoint}" 2>&1)"; then
    read -r status duration <<< "$result"
    printf '%3d/%d GET %-20s HTTP %s (%ss)\n' \
      "$((i + 1))" "$REQUESTS" "$endpoint" "$status" "$duration"
  else
    printf '%3d/%d GET %-20s FAILED: %s\n' \
      "$((i + 1))" "$REQUESTS" "$endpoint" "$result" >&2
    FAILURES=$((FAILURES + 1))
  fi

  if ((i + 1 < REQUESTS)); then
    sleep "$INTERVAL_SECONDS"
  fi
done

if ((FAILURES > 0)); then
  echo "$FAILURES request(s) failed" >&2
  exit 1
fi

echo "Completed successfully. Allow at least one Prometheus scrape interval for metrics to appear."
