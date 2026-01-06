## BitFi Fee Hedge (Clarity)

Minimal contracts for a BTC fee‑hedge prototype using a trusted oracle trait. The core contract stores hedge positions, locks STX, and settles based on oracle‑reported fee data and height.

### Contracts
- `contracts/BitFi.clar`: Hedge contract with position lifecycle, oracle whitelisting, and settlement logic.
- `contracts/oracle-trait.clar`: Trait defining `get-bitcoin-fee` return shape.
- `contracts/simple-oracle.clar`: Simple admin‑updated oracle implementation for local use.

### Oracle Trait
`get-bitcoin-fee` returns a response with:
- `fee`: current BTC fee (uint)
- `last-updated`: height when the fee was last updated (uint)
- `current-height`: height reported by the oracle (uint)

### BitFi Contract Highlights
State:
- Positions map with owner, strike, amount, long/short, created/expiry height, oracle, and settled flag.
- Admin (set once), oracle whitelist, total locked balance, and max staleness in blocks.

Public functions:
- `set-admin(new-admin)`: one‑time admin initialization.
- `set-oracle-approved(oracle, approved)`: admin‑only whitelist toggle.
- `set-max-stale-blocks(max-blocks)`: admin‑only staleness window.
- `create-hedge(amount, strike-fee, is-long, expires-at, oracle)`: locks STX and stores a position.
- `settle-hedge(id, oracle)`: settles a live position using oracle data.
- `expire-hedge(id, oracle)`: refunds after expiry.

Read‑only helpers:
- `get-position(id)`, `get-admin`, `get-total-locked`, `get-max-stale-blocks`.

### Simple Oracle (Local)
State:
- `admin`, `fee`, `last-updated`, `current-height`.

Public functions:
- `set-admin(new-admin)`: one‑time admin initialization.
- `update-fee(new-fee, new-height)`: admin‑only update.

Read‑only:
- `get-bitcoin-fee`, `get-admin`.
