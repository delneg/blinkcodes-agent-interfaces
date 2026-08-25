# MCP server — `com.blinkcodes/catalog`

- **Endpoint:** `https://blinkcodes.com/mcp`
- **Transport:** streamable HTTP
- **Protocol version:** `2025-06-18`
- **Auth:** none. The two catalog tools are read-only and free; `buy_product` is
  paid in USDC on Base over x402 and needs no account either.
- **Registry:** [`com.blinkcodes/catalog`](https://registry.modelcontextprotocol.io/v0/servers?search=com.blinkcodes), status `active`

`initialize` returns these instructions:

> Catalog of BlinkCodes (blinkcodes.com): gift cards, service top-ups, travel
> eSIM. Prices in USD. Search with search_catalog, read denominations with
> get_product, then buy with buy_product — call it once to get x402 payment
> requirements (USDC on Base), sign them, and call it again with the same
> order_id and the signed payment_payload. Full API:
> https://blinkcodes.com/llms.txt.

## Tools

### `search_catalog`

Search the store catalog of gift cards, service top-ups and eSIM data plans.
Returns matching products with their price, availability and product page URL.

```json
{
  "type": "object",
  "properties": {
    "query":   { "type": "string",  "description": "Free text matched against product name and brand, e.g. \"steam\" or \"playstation\"." },
    "type":    { "type": "string",  "enum": ["voucher", "recharge_fixed", "recharge", "e_sim"],
                 "description": "voucher = gift card, recharge_fixed / recharge = top-up, e_sim = eSIM data plan." },
    "country": { "type": "string",  "description": "ISO-3166-1 alpha-2 country code the product is issued for, e.g. US, TR." },
    "limit":   { "type": "integer", "description": "Max products to return (default 10, max 50)." }
  }
}
```

Results arrive as both a text summary and `structuredContent`:

```json
{
  "count": 27,
  "products": [
    {
      "id": 344,
      "name": "Steam Wallet Code | ID",
      "brand": "Steam",
      "type": "voucher",
      "country": "ID",
      "currency": "USD",
      "from_price": 0.42,
      "buyable": true,
      "requires_account": false,
      "requires_amount": false,
      "url": "https://blinkcodes.com/en/product/steam-wallet-code-id-id-344/"
    }
  ]
}
```

`requires_account` and `requires_amount` tell you which extra order fields that
product needs — an account number for a top-up, a chosen amount for a variable
denomination.

### `get_product`

One catalog product by id: available denominations with prices, required order
inputs, and any countries where the code cannot be redeemed.

```json
{
  "type": "object",
  "properties": {
    "id": { "type": "integer", "description": "Product id from search_catalog." }
  },
  "required": ["id"]
}
```

Use the `item_id` of the denomination you want as the `item_id` in a purchase.

### `buy_product`

Buy a gift card, service top-up or travel eSIM and receive the delivery. Paid in
USDC on Base over [x402](https://x402.org) — no account, no browser.

**Two calls.** The first prices the exact item, creates the order and returns the
payment requirements; it charges nothing. The second settles and delivers.

```json
{
  "type": "object",
  "properties": {
    "email":           { "type": "string",  "description": "Delivery address — the only identity the order has. Required on the first call." },
    "product_type":    { "type": "string",  "enum": ["giftcard", "topup"],
                         "description": "Names the order shape, not the goods — eSIM data plans found through search_catalog are bought as giftcard too." },
    "product_id":      { "type": "integer", "description": "Product id from search_catalog." },
    "item_id":         { "type": "integer", "description": "Denomination id from get_product items[]." },
    "quantity":        { "type": "integer", "description": "Defaults to 1 — send it only to buy several." },
    "amount":          { "type": "number",  "description": "Only where get_product reported requires_amount; send instead of item_id." },
    "account_number":  { "type": "string",  "description": "Only where get_product reported requires_account." },
    "order_id":        { "type": "string",  "description": "Second call only: the order_id the first call returned." },
    "payment_payload": { "type": "object",  "description": "Second call only: the signed x402 PaymentPayload." }
  }
}
```

First call — `structuredContent`:

```json
{
  "state": "payment_required",
  "order_id": "u0auigts50cf26c",
  "payment_required": {
    "x402Version": 2,
    "accepts": [
      {
        "scheme": "exact",
        "network": "eip155:8453",
        "amount": "420000",
        "asset": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        "payTo": "0x…",
        "resource": "https://blinkcodes.com/api/v1/buy"
      }
    ]
  }
}
```

Sign `accepts[0]` exactly as you would for `POST /api/v1/buy` — it is the same
document from the same rail — then call the tool again:

```json
{ "order_id": "u0auigts50cf26c", "payment_payload": { "x402Version": 2, "...": "…" } }
```

Second call — `state` is `completed` with the code under `order.delivery`,
`fulfilling` when settlement landed but the supplier is still working (poll the
`status_url` in `order`), or a tool error naming the order id if it failed.

Same rail as the HTTP endpoint, so the ordering that keeps it safe is the same:
verify and reserve both happen before settle, and a settle failure cancels the
reservation. The order id doubles as the idempotency key, so replaying a payment
resolves to the same order rather than buying twice.

## Transcript

```sh
# 1. handshake
curl -sS https://blinkcodes.com/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":0,"method":"initialize",
       "params":{"protocolVersion":"2025-06-18","capabilities":{},
                 "clientInfo":{"name":"curl","version":"1"}}}'

# 2. list tools
curl -sS https://blinkcodes.com/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'

# 3. search
curl -sS https://blinkcodes.com/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call",
       "params":{"name":"search_catalog","arguments":{"query":"steam","limit":2}}}'
```

## Bridge for stdio-only clients

The server is remote. If your client cannot open a remote MCP connection, the
[`Dockerfile`](../Dockerfile) in this repository builds a stdio proxy to the same
endpoint:

```sh
docker build -t blinkcodes-mcp . && docker run -i --rm blinkcodes-mcp
```

It is a thin `mcp-remote` wrapper — no logic, no state. Use the URL directly
where you can.
