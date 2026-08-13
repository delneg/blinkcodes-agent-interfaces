#!/usr/bin/env sh
# A2A against the BlinkCodes catalog agent.
#
# The two catalog skills are free. buy_product quotes a payment and needs the
# x402 extension — see x402-buy.mjs for the signing half.
set -eu

A2A=${A2A:-https://blinkcodes.com/a2a}

send() {
  curl -sS "$A2A" \
    -H 'Content-Type: application/json' \
    -H 'X-A2A-Extensions: https://github.com/google-a2a/a2a-x402/v0.1' \
    -d "$1"
  echo
}

echo '--- agent card ---'
curl -sS https://blinkcodes.com/.well-known/agent-card.json
echo

# A data part routes to a named skill. Bare text falls through to search_catalog.
echo '--- search_catalog via a data part ---'
send '{
  "jsonrpc": "2.0", "id": 1, "method": "message/send",
  "params": { "message": {
    "role": "user", "messageId": "m1",
    "parts": [{ "kind": "data", "data": { "skill": "search_catalog", "query": "razer", "limit": 3 } }]
  }}
}'

echo '--- get_product ---'
send '{
  "jsonrpc": "2.0", "id": 2, "method": "message/send",
  "params": { "message": {
    "role": "user", "messageId": "m2",
    "parts": [{ "kind": "data", "data": { "skill": "get_product", "id": 344 } }]
  }}
}'

# buy_product returns a Task in state input-required whose metadata carries
# x402.payment.required. Sign it, then send x402.payment.payload back with the
# SAME taskId — the task id is the order id, so a retry resolves to one order.
echo '--- buy_product: quote only, nothing is charged ---'
send '{
  "jsonrpc": "2.0", "id": 3, "method": "message/send",
  "params": { "message": {
    "role": "user", "messageId": "m3",
    "parts": [{ "kind": "data", "data": {
      "skill": "buy_product",
      "email": "buyer@example.com",
      "product_type": "giftcard",
      "product_id": 187,
      "item_id": 1195
    }}]
  }}
}'
