# BUILD-TRANSCRIPT — AevumPay (Aevum Builder Challenge #1)

Built 17 Nov 2026 (WIB) by an autonomous agent. All facts below were verified
live at build time unless marked as an assumption. Nothing here is claimed
complete before verification.

## What was built

A one-flow stablecoin payment dApp on the QDay Aevum testnet:

- **`src/AevumPay.sol`** — invoice escrow for tUSD8. `createInvoice` →
  `approve` → `fundInvoice` (escrow) → `confirmDelivery` (release to
  merchant); `refundInvoice` after expiry; `cancelInvoice` while unfunded.
  Zero-dependency single file, Solidity 0.8.30, NatSpec-documented,
  reentrancy guard + checks-effects-interactions.
- **`src/MockUSD8.sol`** — 6-decimal ERC-20 mock used ONLY by forge tests.
  Never deployed to testnet.
- **`test/AevumPay.t.sol`** — 19 tests: end-to-end happy path, refund after
  expiry, cancel, invoice field checks, 14 revert cases.
- **`script/Deploy.s.sol`** — deploy script, hard-guarded to chain ID 44005.
- **`scripts/claim-faucet.sh`** — on-chain faucet claims (tQDAY + tUSD8).
- **`scripts/demo.sh`** — cast-based end-to-end demo printing every tx hash
  and explorer link.
- **`app/index.html`** — minimal single-file web UI (MetaMask + ethers v6
  via CDN, no build step). `PAY_ADDRESS` placeholder until deploy.

## Verified live (17 Nov 2026, ~07:30–08:45 WIB)

- DoraHacks page: free online hackathon; prizes $1,500 USDT (800/500/200);
  build 16 Nov–11 Dec; **submissions close 11 Dec 2026 16:00 HKT = 08:00 UTC
  = 15:00 WIB** (the Eventbrite "16:00 PST" figure in the sweep notes was
  wrong — DoraHacks states HKT).
- Aevum testnet live: RPC `https://rpc-test.qday.info`, chain ID 44005
  (`0xabe5` returned by `eth_chainId`), block ~3,367,465, gas price 1 gwei.
  Explorer `https://explorer-test.qday.info` (Blockscout) responding.
- tUSD8 official address from the QDay wiki token list AND FAQ 3.8:
  `0x456569838f1d43009A91ebA4263147Afd7233483`; verified on-chain via
  `cast call`: name `tUSD8`, symbol `tUSD8`, decimals 6.
- Faucets (from `https://faucet.qday.info/gasapi/info`, live):
  tQDAY faucet `0x33d19Bde2e1798c13808f17BfBa1780b28e4bACC` (holds 670 tQDAY),
  tUSD8 faucet `0x4551B2a3dE4F43e6613E23edf798Ab4FB0211564` (holds 297,000
  tUSD8, drip 1 tUSD8). Both expose `claim(address)` (selector `0x1e83409a`,
  confirmed present in deployed bytecode). The Medium guide's faucet address
  (`0xE507…`) is outdated — the live one is `0x33d1…`.
- `forge build` clean; `forge test` **19 passed, 0 failed** (local chain).
- Fresh throwaway deployer generated with `cast wallet new`:
  `0x6C4F0Ae9912674f88aF695C5583Bf2dDd174f32e` (key in mode-600 `.env`,
  never committed). Demo merchant `0xafCda03810C1F06Ead618dd588dAE0d963Ab8674`
  (key discarded; receives only).

## NOT yet verified / still pending

- **Testnet deployment: BLOCKED on faucet gas (see below).** No contract is
  deployed yet; no tx hashes exist. `deployments/aevum-testnet.json` and the
  `PAY_ADDRESS` in `app/index.html` are still placeholders. Nothing in this
  repo claims a deployment that did not happen.
- `scripts/demo.sh` is written but has NOT been run against testnet (it needs
  a deployed contract + funded wallet). Its logic mirrors the passing forge
  test `test_endToEnd`, but that is not a substitute for a live run.
- Source verification on Blockscout: pending deployment.

## Blocker 2: GitHub repo creation rejected by the App (needs browser/human)

`create_repository` via the GitHub connector failed with
`403 Resource not accessible by integration` (the Muse GitHub App token
cannot create repositories under Tiannuryadins). The code is committed
locally (`900a8f4`) and ready to push; the snapshot-push path needs an
existing repo with the App installed on it (same pattern as the make.fun
repos: the browser created/installed the App on those).

**Unblock step:** in a browser signed in as Tiannuryadins, create public
repo `aevum-pay` (no README/license init — the snapshot provides them),
install the Muse GitHub App on it, then push the local snapshot via the
connector (`github push-files --owner Tiannuryadins --repo aevum-pay
--branch main --source-dir ~/workspace/aevum-challenge`, excluding the
`lib/forge-std` submodule entry). Alternatively the user can push from
their own machine.

## Blocker: faucet relay is captcha-gated (needs a browser session)

The deployer holds 0 tQDAY. Getting the first gas requires the faucet relay:

- `POST /gasapi/claim` and `POST /gasapi/tusd8/claim` return
  `403 {"error":"captcha verification failed"}` without a captcha token.
  The site uses reCAPTCHA v3 / Cloudflare Turnstile — solvable only in a
  real browser session, not from a headless script.
- The on-chain faucet `claim(address)` needs gas, so it cannot bootstrap a
  0-balance wallet (chicken-and-egg).
- The `getGas` top-up additionally requires address "eligibility"
  (≥0.0001 ETH on Ethereum mainnet, per `/gasapi/eligibility` probes:
  vitalik.eth eligible, our fresh deployer + the user's OKX wallet +
  the vAPI agent wallet all ineligible). Whether the plain relay `/claim`
  enforces eligibility is UNKNOWN — it cannot be tested without passing the
  captcha first. The browser session will discover this.
- No captcha bypass was attempted, and no one else's address was used to
  fake eligibility.

**Unblock step (for the parent / a browser-capable agent):** in a live
browser, open https://faucet.qday.info, enter deployer address
`0x6C4F0Ae9912674f88aF695C5583Bf2dDd174f32e`, complete the captcha, and claim
tQDAY (5 tQDAY) and tUSD8 (1 tUSD8). If the relay refuses on eligibility,
the fallback is the user claiming with a mainnet-funded wallet of their own
(their OKX wallet is ineligible, so this may need an exchange-funded
address) — or asking the QDay team in their Telegram (FAQ 7.6) for a
hackathon builder drip.

Once the deployer is funded, deployment is one command:

```bash
forge script script/Deploy.s.sol --rpc-url aevum --broadcast
forge verify-contract --chain-id 44005 --verifier blockscout \
  --verifier-url https://explorer-test.qday.info/api \
  <ADDRESS> src/AevumPay.sol:AevumPay
bash scripts/demo.sh <ADDRESS>
```

then fill in `deployments/aevum-testnet.json`, `app/index.html`
(`PAY_ADDRESS`), README addresses, and `SUBMISSION.md`.

## Honest limitations

- Single-flow demo scope by design (the challenge asks for exactly one
  end-to-end flow). No x402 / ERC-4337 / ERC-8004: the QDay docs list those
  as live in Phase 1.5 but with "step-by-step documentation and endpoints
  will be published" — no usable addresses/endpoints were found, so the entry
  does not claim them.
- Contract is not audited; testnet demo only.
- The DoraHacks starter kit mentioned on the timeline ("starter kit
  released" 16 Nov) could not be located via search; the entry was built
  from scratch against the official wiki instead.
- Egress-proxy note: early in this session all HTTPS POSTs from the VM
  timed out for ~30 minutes (even to httpbin.org), then recovered
  spontaneously. If RPC calls hang again, retry — the chain itself was live
  throughout (verified via the explorer's GET API).
