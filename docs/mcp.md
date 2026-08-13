# MCP server — `com.blinkcodes/catalog`

- **Endpoint:** `https://blinkcodes.com/mcp`
- **Transport:** streamable HTTP
- **Protocol version:** `2025-06-18`
- **Auth:** none. Both tools are read-only and free.
- **Registry:** [`com.blinkcodes/catalog`](https://registry.modelcontextprotocol.io/v0/servers?search=com.blinkcodes), status `active`

`initialize` returns these instructions:

> Read-only catalog of BlinkCodes (blinkcodes.com): gift cards, top-ups, eSIM.
> Prices in USD. To actually buy, follow the HTTP flow documented at
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

## Why there is no `buy` tool

Payment belongs on a rail that can carry it. Buying runs over the x402 HTTP flow
(`POST /api/v1/buy`) or the A2A x402 extension, both documented in the
[README](../README.md). Keeping the MCP surface read-only means a client can
call these tools with no wallet, no key and no risk of spending anything.
