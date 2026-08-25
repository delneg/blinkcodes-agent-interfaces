# BlinkCodes agent interfaces

Machine-readable interfaces for [blinkcodes.com](https://blinkcodes.com) — a store
selling gift card codes, service top-ups and travel eSIMs, with delivery by email
in seconds.

Everything here is a **remote, hosted service**. There is nothing to install and
no server to run: point your client at the URLs below. This repository exists to
document those endpoints, pin their schemas, and give working examples.

| Interface | Endpoint | Spec |
|---|---|---|
| **MCP** (catalog + buy) | `https://blinkcodes.com/mcp` | Streamable HTTP, protocol `2025-06-18` |
| **A2A** | `https://blinkcodes.com/a2a` | JSON-RPC, protocol `0.3` |
| **x402** (pay per call) | `https://blinkcodes.com/api/v1/buy` | x402 v2 (v1 on request), USDC on Base |
| OpenAPI | `https://blinkcodes.com/openapi.json` | includes `x-payment-info` (MPP) |
| Plain-language docs for agents | `https://blinkcodes.com/llms.txt` | |

Discovery documents: [`/.well-known/agent-card.json`](https://blinkcodes.com/.well-known/agent-card.json),
[`/.well-known/mcp/server-card.json`](https://blinkcodes.com/.well-known/mcp/server-card.json),
[`/.well-known/api-catalog`](https://blinkcodes.com/.well-known/api-catalog),
[`/.well-known/agent-skills/index.json`](https://blinkcodes.com/.well-known/agent-skills/index.json),
[`/.well-known/acp.json`](https://blinkcodes.com/.well-known/acp.json),
[`/.well-known/ucp`](https://blinkcodes.com/.well-known/ucp).

## MCP server

Published to the [Official MCP Registry](https://registry.modelcontextprotocol.io)
as **`com.blinkcodes/catalog`** ([server.json](./server.json)).

Three tools. The two catalog tools are read-only and free — no key, no account,
no payment. The third takes money, and only over x402:

| Tool | Purpose |
|---|---|
| `search_catalog` | Search gift cards, top-ups and eSIM plans. Returns price, availability and product URL. |
| `get_product` | One product by id: denominations with prices, required order inputs, countries where the code cannot be redeemed. |
| `buy_product` | Buy and receive the delivery. Two calls: arguments in → x402 payment requirements out; signed payload in → the code out. |

`buy_product` runs the same rail as `POST /api/v1/buy` below — verify, reserve,
settle, fulfil, in that order — so an agent that found the store through MCP
never has to change protocol to complete the purchase. Nothing is charged by the
first call, and no wallet is needed to use the other two tools.

Add it to a client that speaks remote MCP:

```json
{
  "mcpServers": {
    "blinkcodes": {
      "type": "http",
      "url": "https://blinkcodes.com/mcp"
    }
  }
}
```

Full tool schemas and a curl transcript: [docs/mcp.md](docs/mcp.md).

A stdio-only client can use the bridge in [`Dockerfile`](./Dockerfile), which
proxies to the same hosted endpoint:

```sh
docker build -t blinkcodes-mcp . && docker run -i --rm blinkcodes-mcp
```

Prefer the direct URL above wherever your client speaks remote MCP — the bridge
adds a hop and buys nothing.

## Buying, for agents

Payment is **USDC on Base** over [x402](https://x402.org). One endpoint, two
passes:

1. `POST /api/v1/buy` with the order body → **402** carrying payment requirements
   priced for that exact item, plus an `order` block (id, access token, status URL).
2. The **identical** request with a `PAYMENT-SIGNATURE` header → **200** with the
   code, or **202** + `status_url` if fulfilment outlives the sync window.

```jsonc
// the body, in both passes
{
  "email": "buyer@example.com",
  "product_type": "giftcard",   // giftcard | topup | esim | phone_rental
  "product_id": 187,
  "item_id": 1195,
  "quantity": 1
}
```

- Network `eip155:8453`, asset `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` (USDC).
- x402 **v2 by default**; v1 clients send `X-PAYMENT`, or ask for a v1 quote with
  `X-PAYMENT-VERSION: 1`.
- `GET /api/v1` describes the rail for free.
- Calling `/api/v1/buy` with **nothing named** answers 402 quoting the rail's
  floor and creates no order — that is the probe form, safe for crawlers.

Worked example: [examples/x402-buy.mjs](examples/x402-buy.mjs). Rails, floors and
payable coin pairs: `GET /api/public/payment-methods`.

## A2A

Agent card at [`/.well-known/agent-card.json`](https://blinkcodes.com/.well-known/agent-card.json),
JSON-RPC `message/send` at `https://blinkcodes.com/a2a`. Skills are the two catalog
tools plus `buy_product`, which over this transport carries the
[a2a-x402](https://github.com/google-a2a/a2a-x402) payments extension
(`https://github.com/google-a2a/a2a-x402/v0.1`, declared `required: false` because
the catalog skills are free).

Quote → `Task` in `input-required` with `x402.payment.required`; pay → same
`taskId` with `x402.payment.payload` → `Task` `completed` plus the delivery as an
artifact. See [examples/a2a.sh](examples/a2a.sh).

## Human docs

Store, prices and terms: <https://blinkcodes.com>. Support:
<support@blinkcodes.com>.

## License

[MIT](./LICENSE) — applies to the documentation and examples in this repository.
The service itself is governed by the terms published on the site.
