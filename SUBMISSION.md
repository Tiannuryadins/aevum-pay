# SUBMISSION DRAFT — Aevum Builder Challenge #1 (DoraHacks)

> STATUS: DRAFT — NOT SUBMITTED. Testnet deployment is still pending faucet
> gas (see BUILD-TRANSCRIPT.md). Do NOT submit until the contract is deployed,
> source-verified, and the demo has run end-to-end on testnet. Fields marked
> TBD must be filled in first. Submission on DoraHacks requires a human
> DoraHacks account — that final step is a human step.

## Project

- **Title:** AevumPay — tUSD8 invoice escrow for stablecoin payments
- **Tagline:** One end-to-end stablecoin payment flow on Aevum testnet: invoice,
  escrow, confirm, release — in tUSD8, with expiry refunds.
- **Track / challenge:** Aevum Builder Challenge #1 (QDay.io / Aevum)
- **Team:** Solo — Januar (@januar / Tiannuryadins)

## Links

- **GitHub repo:** TBD — `Tiannuryadins/aevum-pay` (planned name). Creation via
  the GitHub connector was rejected (403, App cannot create repos); needs a
  browser/human to create the repo + install the Muse GitHub App, then push
  the local snapshot. Code is committed locally and ready.
- **Live demo (UI):** TBD — `app/index.html` (static; serve or host on GitHub Pages after deploy)
- **Contract (Aevum testnet):** TBD — `https://explorer-test.qday.info/address/<AevumPay>`
- **Demo transactions:** TBD — see `scripts/demo.sh` output after the live run
- **Hackathon page:** https://dorahacks.io/hackathon/qday/detail

## Description (for the submission form)

AevumPay is a minimal invoice-escrow dApp for stablecoin payments on the QDay
Aevum testnet. A payer creates an invoice for a merchant in tUSD8 (QDay's
testnet USD stablecoin), approves the amount, and funds it into escrow. When
the payer confirms delivery, the escrow releases the tUSD8 to the merchant;
if the payer never confirms and the invoice expires, the payer can refund.
One contract, one flow, fully on-chain and verifiable.

Why escrow: it is the smallest payment primitive a merchant or an AI agent
actually needs — pay on delivery confirmation, with a refund path, no
custodian. The contract has no owner, no admin keys, no fees, and no
upgradeability: it can only move tUSD8 along the invoice lifecycle.

## Architecture

- `AevumPay.sol` — single-file, zero-dependency Solidity 0.8.30 escrow.
  Invoice lifecycle: Created → Funded → Released | Refunded | Cancelled.
  Reentrancy guard + checks-effects-interactions; only the payer can fund,
  confirm, refund, or cancel their invoice.
- `tUSD8` — official QDay testnet stablecoin
  (`0x456569838f1d43009A91ebA4263147Afd7233483`, 6 decimals).
- `app/index.html` — single-file UI (MetaMask + ethers.js, no build step).
- `scripts/demo.sh` — reproducible CLI demo (cast) printing every tx hash.
- `test/AevumPay.t.sol` — 19 Foundry tests (happy path, refund, cancel,
  14 revert cases), all passing.

## Demo (short)

1. Payer (deployer) holds 1 tUSD8 from the faucet.
2. Create invoice #0: merchant `0xafCda03810C1F06Ead618dd588dAE0d963Ab8674`,
   0.50 tUSD8, 1-hour expiry, memo `demo-order-001`.
3. Approve 0.50 tUSD8 → fund invoice (escrow holds 0.50 tUSD8).
4. Confirm delivery → merchant receives 0.50 tUSD8, escrow returns to 0.
5. Every step is a testnet transaction with an explorer link (TBD after run).

Reproduce: `bash scripts/demo.sh` (see README).

## Technologies

Solidity 0.8.30, Foundry (forge/cast), QDay Aevum testnet (EVM, chain 44005),
tUSD8 ERC-20, ethers.js v6, Blockscout source verification.

## Known constraints (honest)

- Testnet demo contract, not audited; not for mainnet use.
- Single-flow scope by design. x402 / ERC-4337 / ERC-8004 are listed by QDay
  as Phase 1.5-live but without published endpoints/addresses at build time,
  so this entry does not claim them.
- Demo video: the required deliverable is a short demo; a 3–5 minute live
  presentation is only needed if selected as a Top 5 finalist (Demo Day
  15 Dec) — that is a human step.

## Submission checklist

- [ ] Deployer funded (faucet — browser step, see BUILD-TRANSCRIPT.md)
- [ ] AevumPay deployed to Aevum testnet (44005)
- [ ] Source verified on https://explorer-test.qday.info
- [ ] `scripts/demo.sh` run end-to-end; tx hashes recorded
- [ ] `deployments/aevum-testnet.json` + README + `app/index.html` filled in
- [ ] GitHub repo public, pushed
- [ ] This draft's TBD fields filled in
- [ ] Submitted on DoraHacks (human step — needs DoraHacks account)
- [ ] Deadline: **11 Dec 2026, 15:00 WIB** (16:00 HKT / 08:00 UTC)
