#!/bin/bash
# Reliable citation search: S2 relevance search, then CrossRef only on exhausted 429.
# Usage: bash scripts/search_papers.sh "query" [limit]
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUERY="${1:-}"
LIMIT="${2:-20}"
if [[ -z "$QUERY" ]]; then
    echo '{"error":"Usage: bash scripts/search_papers.sh \"query\" [limit]"}' >&2
    exit 1
fi
if ! [[ "$LIMIT" =~ ^[1-9][0-9]{0,2}$ ]] || (( LIMIT > 100 )); then
    echo '{"error":"limit must be an integer between 1 and 100"}' >&2
    exit 1
fi
TMP_SEARCH=$(mktemp -d)
trap 'rm -rf "$TMP_SEARCH"' EXIT
if bash "$SCRIPT_DIR/s2_search.sh" "$QUERY" "$LIMIT" > "$TMP_SEARCH/results" 2> "$TMP_SEARCH/errors"; then
    cat "$TMP_SEARCH/errors" >&2
    jq '. + {source: "semantic_scholar", search_method: "relevance", fallback_reason: null}' "$TMP_SEARCH/results"
    exit 0
fi
cat "$TMP_SEARCH/errors" >&2
# Only an explicit final S2 429 triggers fallback; never hide credentials,
# network, input or formatting errors behind a different provider's success.
if ! tail -n 1 "$TMP_SEARCH/errors" | jq -e '.status == 429' >/dev/null 2>&1; then
    exit 1
fi
printf '%s\n' 'Semantic Scholar remains rate limited; using CrossRef. Results include source labels; S2-only metrics are unavailable.' >&2
if ! bash "$SCRIPT_DIR/crossref_search.sh" "$QUERY" "$LIMIT" papers > "$TMP_SEARCH/results"; then
    echo '{"error":"Semantic Scholar was rate limited and CrossRef fallback failed; no results returned"}' >&2
    exit 1
fi
jq '. + {
    authors: .author_details,
    abstract: "",
    arxiv_id: null,
    is_arxiv: null,
    arxiv_status: "unknown",
    recommendation: "CrossRef 检索结果；需核实引用适配性，S2 作者 ID / arXiv 状态不可用",
    source: "crossref",
    search_method: "bibliographic",
    fallback_reason: "semantic_scholar_http_429"
} | del(.author_details)' "$TMP_SEARCH/results"
