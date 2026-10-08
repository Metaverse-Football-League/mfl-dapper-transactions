# mfl-dapper-transactions
This repository contains transactions that have been whitelisted by Dapper.

The actual contracts corresponding to these transactions are currently here: https://github.com/Metaverse-Football-League/mfl-smart-contracts/tree/feat-dapper-wallet (feat-dapper-wallet branch)

## Tests

`tests/` holds Cadence tests (Flow test framework) for the NFTStorefrontV2 player and club transactions: listing with expiry, relisting, legacy V1 listing removal, purchase before and after expiry, cleanup of expired listings, cancel.
They run the mainnet transactions against the contracts of a local `mfl-smart-contracts` checkout:

```bash
SMART_CONTRACTS_DIR=../mfl-smart-contracts ./tests/run.sh
```
