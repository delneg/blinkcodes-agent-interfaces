// Buy a product from BlinkCodes with USDC on Base, in one script.
//
//   npm i @x402/core @x402/evm viem
//   PRIVATE_KEY=0x… EMAIL=you@example.com node x402-buy.mjs
//
// This spends real money on Base mainnet. The wallet needs USDC for the amount
// the 402 quotes, and nothing else — no ETH for gas, because you only sign an
// authorization and the facilitator broadcasts the transfer.

import { x402Client, x402HTTPClient } from "@x402/core/client";
import { toClientEvmSigner } from "@x402/evm";
import { ExactEvmScheme } from "@x402/evm/exact/client";
import { privateKeyToAccount } from "viem/accounts";

const ORIGIN = process.env.ORIGIN ?? "https://blinkcodes.com";
const BUY = `${ORIGIN}/api/v1/buy`;

// The order. product_id / item_id come from the catalog — see the MCP tools, or
// GET /api/public/products?q=steam
const order = {
  email: process.env.EMAIL ?? "buyer@example.com",
  product_type: "giftcard", // giftcard | topup | esim | phone_rental
  product_id: 187,
  item_id: 1195,
  quantity: 1,
};

const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const client = new x402HTTPClient(
  new x402Client().register("eip155:8453", new ExactEvmScheme(toClientEvmSigner(account))),
);

const post = (headers = {}) =>
  fetch(BUY, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(order),
  });

// Pass 1 — no payment header. The 402 prices this exact item and opens an order.
const quote = await post();
if (quote.status !== 402) {
  // 400 means the order body is wrong; the message says which field.
  console.error("expected 402, got", quote.status, await quote.text());
  process.exit(1);
}

// On v2 the requirements document is canonical in the PAYMENT-REQUIRED header
// and mirrored into the body. Read either; the SDK takes both.
const required = client.getPaymentRequiredResponse(
  (name) => quote.headers.get(name),
  await quote.clone().json().catch(() => undefined),
);
const accept = required.accepts[0];
console.log(`quoted ${accept.amount} atomic USDC on ${accept.network} → ${accept.payTo}`);

// Pass 2 — the identical body, now signed. Handing the whole `required`
// document to the client matters: it copies `resource` and `extensions` into
// the payload, which is what lets the facilitator catalogue the resource.
const payload = await client.createPaymentPayload(required, accept);
const paid = await post(client.encodePaymentSignatureHeader(payload));

const body = await paid.json();
switch (paid.status) {
  case 200:
    // delivery.code for a gift card, delivery.esim / delivery.phone otherwise.
    console.log("delivered:", JSON.stringify(body.delivery, null, 2));
    break;
  case 202:
    // Fulfilment outlived the sync window. Poll the status URL; the code lands
    // there, and by email.
    console.log("fulfilling, poll:", body.status_url);
    break;
  default:
    console.error("failed:", paid.status, JSON.stringify(body, null, 2));
    process.exit(1);
}

// An Idempotency-Key header is derived from the body when you omit it, so a
// retried payment resolves to the same order rather than buying twice.
