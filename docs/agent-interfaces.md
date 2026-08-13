# Every machine-readable endpoint

All served over HTTPS from `https://blinkcodes.com`, all free to read.

## Documentation

| Path | What it is |
|---|---|
| `/llms.txt` | Plain-language description of the store and how to buy, written for agents |
| `/openapi.json` | OpenAPI 3.1 for the public API, including `x-payment-info` (MPP) blocks on payable operations |
| `/auth.md` | What needs authentication and what does not |
| `/.well-known/api-catalog` | RFC 9727 catalogue linking the above |

The homepage also answers `Accept: text/markdown` with a markdown twin, and
carries `Link` headers pointing at `llms.txt` and the OpenAPI document.

## Agent protocols

| Path | Protocol |
|---|---|
| `/mcp` | MCP, streamable HTTP — see [mcp.md](mcp.md) |
| `/.well-known/mcp/server-card.json` | MCP server card |
| `/a2a` | A2A, JSON-RPC `message/send` |
| `/.well-known/agent-card.json` | A2A agent card, protocol `0.3` |
| `/.well-known/agent-skills/index.json` | Agent skills index; each skill has a `SKILL.md` |
| `/.well-known/acp.json` | ACP discovery document |
| `/.well-known/ucp` | UCP profile, including a P-256 `signing_keys` JWK |

The A2A card and the `/a2a` endpoint are published as a pair — every skill named
on the card is one the endpoint actually serves. The ACP and UCP documents
deliberately declare **no** protocol services or capabilities: they publish the
base URL, transports, currency and locales, which are true, and claim no checkout
surface this backend does not implement.

## Payment

| Path | What it is |
|---|---|
| `GET /api/v1` | Free description of the x402 rail: network, asset, minimum, flow |
| `POST /api/v1/buy` | The paywall. 402 → pay → delivery |
| `GET /api/public/payment-methods` | Every registered rail with its minimum order, and for crypto the payable `(currency, network)` pairs |

x402 details:

- **Version:** v2 by default, v1 on request (`X-PAYMENT-VERSION: 1` or `?x402_version=1`)
- **Network:** `eip155:8453` on v2, `base` on v1
- **Asset:** USDC, `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- **Scheme:** `exact`
- **Minimum:** $0.01
- **Headers (v2):** requirements in `PAYMENT-REQUIRED`, payment in
  `PAYMENT-SIGNATURE`, receipt in `PAYMENT-RESPONSE`
- **Headers (v1):** requirements in the body, payment in `X-PAYMENT`, receipt in
  `X-PAYMENT-RESPONSE`

On v2 the requirements document is canonical in the `PAYMENT-REQUIRED` header and
mirrored into the JSON body, so a client that only reads JSON still sees it.

## Notes for crawlers

- `POST /api/v1/buy` with an **empty body**, or a bare `GET`, answers `402` with
  the rail's floor price and **creates no order**. Probe it freely.
- A request that names a product but gets a field wrong answers `400`, with the
  reason — that error belongs in front of the caller, not buried under a paywall.
- Free operations declare `security: []` in the OpenAPI document, so there is no
  need to probe them for a 402.
