#!/usr/bin/env sh
# Talk to the BlinkCodes MCP server with nothing but curl.
# No key, no account — both tools are read-only and free.
set -eu

MCP=${MCP:-https://blinkcodes.com/mcp}

call() {
  curl -sS "$MCP" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d "$1"
  echo
}

echo '--- initialize ---'
call '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"example","version":"1"}}}'

echo '--- tools/list ---'
call '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'

echo '--- search_catalog: cheapest Steam products ---'
call '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"search_catalog","arguments":{"query":"steam","limit":3}}}'

echo '--- get_product: one product with its denominations ---'
call '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_product","arguments":{"id":344}}}'

echo '--- buy_product: quote only, nothing is charged ---'
# Returns x402 payment requirements plus an order_id. Sign the requirements and
# call buy_product again with {order_id, payment_payload} to settle. See
# examples/x402-buy.mjs for the signing half — it is the same document.
call '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"buy_product","arguments":{"email":"you@example.com","product_type":"giftcard","product_id":344,"item_id":1}}}'
