#!/bin/bash
# Runs the Cadence tests of the storefront V2 transactions on the Flow test framework.
# Needs the Flow CLI and a checkout of mfl-smart-contracts:
#   SMART_CONTRACTS_DIR=../mfl-smart-contracts ./tests/run.sh
set -e
cd "$(dirname "$0")"
: "${SMART_CONTRACTS_DIR:?set SMART_CONTRACTS_DIR to a checkout of mfl-smart-contracts}"
ln -sfn "$(cd "$OLDPWD" && cd "$SMART_CONTRACTS_DIR" && pwd)/contracts" .contracts

# Copy the mainnet transactions with string imports and the test MFL account address.
rm -rf cadence && mkdir cadence
for f in transactions/create_player_listing_v2.tx.cdc transactions/create_club_listing_v2.tx.cdc transactions/purchase_player_marketplace_v2.tx.cdc transactions/purchase_club_marketplace_v2.tx.cdc scripts/get_player_metadata_from_storefront_listing_v2.script.cdc scripts/get_club_metadata_from_storefront_listing_v2.script.cdc transactions/create_player_listing.tx.cdc transactions/remove_listing_v2.tx.cdc; do
  sed -E -e 's/^import ([A-Za-z0-9]+) from 0x[0-9a-f]+/import "\1"/' -e 's/0x15e71a9f7fe7d53d/0x0000000000000007/g' ../mainnet/$f > cadence/$(basename $f)
done

# The test runner cannot decode struct types declared in a script: expose the result name through a wrapper main.
for s in cadence/get_*_metadata_from_storefront_listing_v2.script.cdc; do
  sed -i.bak 's/^fun main(/fun original(/' $s && rm $s.bak
  printf '\naccess(all) fun main(storefrontAddress: Address, merchantAccountAddress: Address, listingResourceID: UInt64, expectedPrice: UFix64): String {\n    return original(storefrontAddress: storefrontAddress, merchantAccountAddress: merchantAccountAddress, listingResourceID: listingResourceID, expectedPrice: expectedPrice).name\n}\n' >> $s
done

flow test listings_v2_test.cdc
