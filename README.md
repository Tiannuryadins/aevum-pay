# AevumPay — tUSD8 invoice escrow on QDay Aevum testnet

Entry for **Aevum Builder Challenge #1** (Aevum / QDay.io, on DoraHacks).
One end-to-end stablecoin payment flow on the Aevum testnet (chain ID 44005)
using the official test stablecoin **tUSD8**: a merchant invoice is created,
funded into escrow, and released to the merchant when the payer confirms
delivery — or refunded to the payer after expiry.

Testnet only. tUSD8 and tQDAY have no real value. No mainnet, no real funds.

## The flow

```
payer                          AevumPay                         merchant
  |  createInvoice(merchant, 0.50 tUSD8, 1h, "order-001")        |
  | -----------------------------------------------------------> |
  |  approve(AevumPay, 0.50 tUSD8)                               |
  | ---------------------> tUSD8                                 |
  |  fundInvoice(id)  — 0.50 tUSD8 locked in escrow              |
  | -----------------------------------------------------------> |
  |  confirmDelivery(id) — escrow releases to merchant           |
  | -----------------------------------------------------------> |  +0.50 tUSD8
  |  (or, after expiry: refundInvoice(id) returns funds to payer)|
```

## Deployed (Aevum testnet, chain 44005)

| Item | Address |
|---|---|
| AevumPay | **TBD — deploy pending faucet gas (see below)** |
| tUSD8 (official) | `0x456569838f1d43009A91ebA4263147Afd7233483` (6 decimals) |
| tQDAY faucet | `0x33d19Bde2e1798c13808f17BfBa1780b28e4bACC` |
| tUSD8 faucet | `0x4551B2a3dE4F43e6613E23edf798Ab4FB0211564` (drip 1 tUSD8) |
| RPC | `https://rpc-test.qday.info` |
| Explorer | `https://explorer-test.qday.info` |

Deployer (testnet-only throwaway): `0x6C4F0Ae9912674f88aF695C5583Bf2dDd174f32e`
Demo merchant (receives only): `0xafCda03810C1F06Ead618dd588dAE0d963Ab8674`

> **Deploy status (17 Nov 2026):** the contract is built and fully tested
> locally (19/19 forge tests pass), but the deployer wallet holds 0 tQDAY and
> the faucet relay at faucet.qday.info is captcha-gated — it cannot be claimed
> from a headless script. Deployment is a single command once the wallet is
> funded; see `BUILD-TRANSCRIPT.md` for the exact unblock step.

## Repository layout

```
src/AevumPay.sol        the escrow contract (zero-dependency, single file)
src/MockUSD8.sol        local-test tUSD8 stand-in (forge tests only, never deployed)
test/AevumPay.t.sol     19 tests: happy path, refund, cancel, 14 revert cases
script/Deploy.s.sol     Foundry deploy script (chain-id guarded to 44005)
scripts/claim-faucet.sh on-chain faucet claims (needs a little gas first)
scripts/demo.sh         cast-based end-to-end demo; prints every tx hash
app/index.html          minimal web UI (MetaMask + ethers.js, no build step)
deployments/            deployment record (filled in after deploy)
```

## Build & test

```bash
forge build
forge test   # 19 passed, 0 failed
```

Requires [Foundry](https://getfoundry.sh). Solidity 0.8.30, no dependencies
except `forge-std` (tests only). `AevumPay.sol` itself imports nothing, so the
deployed source verifies on Blockscout as a single file.

## Deploy (once the deployer is funded)

```bash
cp .env.example .env   # set PRIVATE_KEY (testnet-only key!)
forge script script/Deploy.s.sol --rpc-url aevum --broadcast
# verify source on the explorer:
forge verify-contract --chain-id 44005 --verifier blockscout \
  --verifier-url https://explorer-test.qday.info/api \
  <ADDRESS> src/AevumPay.sol:AevumPay
```

Then run the demo:

```bash
bash scripts/demo.sh   # uses deployments/aevum-testnet.json
```

## Try the UI

Serve `app/` statically (e.g. `python3 -m http.server -d app`) and open
`index.html` with MetaMask on QDay Aevum (chain 44005). The page adds the
network automatically. Set `PAY_ADDRESS` in `app/index.html` to the deployed
contract first.

## Security notes

- Checks-effects-interactions + a reentrancy guard on every function that moves
  tokens. Only the payer can fund / confirm / refund / cancel their invoice.
- `fundInvoice` refuses to fund after expiry; `refundInvoice` only after
  expiry; `confirmDelivery` only while funded. Invalid invoice ids fail closed
  (`NOT_PAYER`, since a nonexistent invoice has payer `address(0)`).
- No admin, no owner, no upgradeability, no fees. The contract can only move
  tUSD8 it holds as escrow, and only along the invoice lifecycle.
- Testnet demo contract — not audited, not for mainnet use.

## Links

- Hackathon: https://dorahacks.io/hackathon/qday/detail
- QDay docs: https://wiki.qday.info — token list: `Knowledge/reference/tokens`
- Faucet: https://faucet.qday.info

## License

MIT.
