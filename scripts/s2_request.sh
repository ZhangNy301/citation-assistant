#!/bin/bash
# Shared S2 transport. Source after init.sh; stdout is body + final HTTP status.
# Retries only HTTP 429. Never print credentials or curl's request diagnostics.
s2_request() (
    local url="$1" timeout="$2"
    local retries="${S2_MAX_RETRIES:-2}" delay="${S2_RETRY_DELAY:-2}"
    local max_delay="${S2_MAX_RETRY_DELAY:-60}" interval="${S2_MIN_INTERVAL:-1}"
    local value
    for value in "$retries" "$delay" "$max_delay" "$interval"; do
        if ! [[ "$value" =~ ^(0|[1-9][0-9]{0,4})$ ]]; then
            echo '{"error":"S2 retry and interval settings must be integers between 0 and 99999"}' >&2
            exit 1
        fi
    done
    local tmp
    tmp=$(mktemp -d) || exit 1
    trap 'rm -rf "$tmp"' EXIT
    local attempt=0 code now last_time wait_for retry_after retry_epoch
    local -a headers=()
    if [[ -n "${S2_API_KEY:-}" ]]; then
        # Private temporary header file keeps the key out of curl's argv.
        printf 'x-api-key: %s\n' "$S2_API_KEY" > "$tmp/auth"
        headers=(-H "@$tmp/auth")
    fi
    while :; do
        last_time=0
        if [[ -f "$S2_RATE_LIMIT_FILE" ]]; then
            read -r last_time < "$S2_RATE_LIMIT_FILE" || last_time=0
        fi
        [[ "$last_time" =~ ^[0-9]{1,12}$ ]] || last_time=0
        now=$(date +%s)
        wait_for=$((last_time + interval - now))
        # Ignore corrupt or future timestamps rather than sleeping indefinitely.
        if (( wait_for > 0 && wait_for <= interval )); then
            sleep "$wait_for"
        fi
        if ! code=$(curl -s --dump-header "$tmp/headers" --output "$tmp/body" \
            -w '%{http_code}' "${headers[@]}" --max-time "$timeout" "$url" 2>/dev/null); then
            echo '{"error":"Semantic Scholar network request failed (timeout, DNS or connection error)"}' >&2
            exit 1
        fi
        date +%s > "$S2_RATE_LIMIT_FILE" || exit 1
        if [[ "$code" != 429 ]] || (( attempt >= retries )); then
            break
        fi
        # Use only the final response block (proxies may prepend CONNECT headers).
        retry_after=$(awk '
            /^HTTP\// { value="" }
            tolower($0) ~ /^retry-after:/ {
                sub(/^[^:]*:[ \t]*/, ""); sub(/\r$/, ""); value=$0
            }
            END { print value }
        ' "$tmp/headers")
        wait_for="$delay"
        if [[ "$retry_after" =~ ^[0-9]+$ ]]; then
            # Saturate large values; never retry earlier than a long server cooldown.
            if (( ${#retry_after} > 5 )); then
                wait_for=$((max_delay + 1))
            else
                wait_for=$((10#$retry_after))
            fi
        elif [[ -n "$retry_after" ]]; then
            # GNU date (Linux), then BSD date (macOS); invalid values use backoff.
            retry_epoch=$(LC_ALL=C date -d "$retry_after" +%s 2>/dev/null) || \
                retry_epoch=$(LC_ALL=C date -u -j -f '%a, %d %b %Y %H:%M:%S GMT' \
                    "$retry_after" +%s 2>/dev/null) || retry_epoch=""
            if [[ "$retry_epoch" =~ ^[0-9]+$ ]]; then
                wait_for=$((retry_epoch - $(date +%s)))
                (( wait_for >= 0 )) || wait_for=0
            fi
        fi
        if (( wait_for > max_delay )); then
            echo 'Semantic Scholar cooldown exceeds S2_MAX_RETRY_DELAY; stopping without an early retry.' >&2
            break
        fi
        attempt=$((attempt + 1))
        printf 'Semantic Scholar HTTP 429; retry %s/%s in %ss.\n' "$attempt" "$retries" "$wait_for" >&2
        sleep "$wait_for"
        delay=$((delay * 2))
        (( delay <= max_delay )) || delay="$max_delay"
    done
    cat "$tmp/body"
    printf '\n%s\n' "$code"
)
