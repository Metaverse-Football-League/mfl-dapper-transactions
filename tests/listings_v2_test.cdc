import Test
import "NFTStorefrontV2"
import "NFTStorefront"
import "MFLPlayer"
import "MFLClub"

access(all) let mfl = Test.getAccount(0x0000000000000007)
access(all) let seller = Test.createAccount()
access(all) let buyer = Test.createAccount()
access(all) let stranger = Test.createAccount()

access(all) let ROYALTY = 0.05
access(all) let DAY: UInt64 = 86400

access(all) fun deploy(_ name: String, _ path: String) {
    let err = Test.deployContract(name: name, path: path, arguments: [])
    Test.expect(err, Test.beNil())
}

access(all) fun run(_ code: String, _ signers: [Test.TestAccount], _ args: [AnyStruct]): Test.TransactionResult {
    let addrs: [Address] = []
    for s in signers { addrs.append(s.address) }
    return Test.executeTransaction(Test.Transaction(code: code, authorizers: addrs, signers: signers, arguments: args))
}

access(all) fun now(): UInt64 {
    let r = Test.executeScript("access(all) fun main(): UInt64 { return UInt64(getCurrentBlock().timestamp) }", [])
    return r.returnValue! as! UInt64
}

access(all) fun v2ListingIDs(_ addr: Address, _ nftType: Type, _ nftID: UInt64): [UInt64] {
    let code = "import \"NFTStorefrontV2\"\naccess(all) fun main(a: Address, t: Type, id: UInt64): [UInt64] { let s = getAccount(a).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(NFTStorefrontV2.StorefrontPublicPath); if s == nil { return [] }; return s!.getExistingListingIDs(nftType: t, nftID: id) }"
    let r = Test.executeScript(code, [addr, nftType, nftID])
    Test.expect(r, Test.beSucceeded())
    return r.returnValue! as! [UInt64]
}

access(all) fun v2Expiry(_ addr: Address, _ listingID: UInt64): UInt64 {
    let code = "import \"NFTStorefrontV2\"\naccess(all) fun main(a: Address, id: UInt64): UInt64 { return getAccount(a).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(NFTStorefrontV2.StorefrontPublicPath)!.borrowListing(listingResourceID: id)!.getDetails().expiry }"
    let r = Test.executeScript(code, [addr, listingID])
    Test.expect(r, Test.beSucceeded())
    return r.returnValue! as! UInt64
}

access(all) fun v1ListingCount(_ addr: Address): Int {
    let code = "import \"NFTStorefront\"\naccess(all) fun main(a: Address): Int { let s = getAccount(a).capabilities.borrow<&{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath); if s == nil { return 0 }; return s!.getListingIDs().length }"
    let r = Test.executeScript(code, [addr])
    Test.expect(r, Test.beSucceeded())
    return r.returnValue! as! Int
}

access(all) fun ownsPlayer(_ addr: Address, _ id: UInt64): Bool {
    let code = "import \"MFLPlayer\"\naccess(all) fun main(a: Address, id: UInt64): Bool { return getAccount(a).capabilities.borrow<&MFLPlayer.Collection>(MFLPlayer.CollectionPublicPath)!.getIDs().contains(id) }"
    return Test.executeScript(code, [addr, id]).returnValue! as! Bool
}

access(all) fun ownsClub(_ addr: Address, _ id: UInt64): Bool {
    let code = "import \"MFLClub\"\naccess(all) fun main(a: Address, id: UInt64): Bool { return getAccount(a).capabilities.borrow<&MFLClub.Collection>(MFLClub.CollectionPublicPath)!.getIDs().contains(id) }"
    return Test.executeScript(code, [addr, id]).returnValue! as! Bool
}

access(all) fun mintPlayer(_ id: UInt64, _ to: Address) {
    let code = "import \"MFLPlayer\"\nimport \"MetadataViews\"\ntransaction(id: UInt64, to: Address) { prepare(acct: auth(BorrowValue) &Account) { let admin = acct.storage.borrow<auth(MFLPlayer.PlayerAdminAction) &MFLPlayer.PlayerAdmin>(from: MFLPlayer.PlayerAdminStoragePath)!; let nft <- admin.mintPlayer(id: id, metadata: {\"name\": \"Player\", \"overall\": UInt32(70), \"positions\": [\"ST\"], \"nationalities\": [\"FRANCE\"]}, season: 1, image: MetadataViews.IPFSFile(cid: \"cid\", path: nil)); getAccount(to).capabilities.borrow<&MFLPlayer.Collection>(MFLPlayer.CollectionPublicPath)!.deposit(token: <-nft) } }"
    Test.expect(run(code, [mfl], [id, to]), Test.beSucceeded())
}

access(all) fun mintClub(_ id: UInt64, _ to: Address) {
    let code = "import \"MFLClub\"\ntransaction(id: UInt64, to: Address) { prepare(acct: auth(BorrowValue) &Account) { let admin = acct.storage.borrow<auth(MFLClub.ClubAdminAction) &MFLClub.ClubAdmin>(from: MFLClub.ClubAdminStoragePath)!; let nft <- admin.mintClub(id: id, squads: <-[], nftMetadata: {\"name\": \"Club\", \"description\": \"d\"}, metadata: {\"name\": \"Club\", \"description\": \"d\"}); getAccount(to).capabilities.borrow<&MFLClub.Collection>(MFLClub.CollectionPublicPath)!.deposit(token: <-nft) } }"
    Test.expect(run(code, [mfl], [id, to]), Test.beSucceeded())
}

access(all) fun createPlayerListingV2(_ id: UInt64, _ price: UFix64, _ expiry: UInt64): Test.TransactionResult {
    return run(Test.readFile("cadence/create_player_listing_v2.tx.cdc"), [mfl, seller], [id, price, ROYALTY, expiry])
}

access(all) fun purchasePlayerV2(_ listingID: UInt64, _ price: UFix64): Test.TransactionResult {
    return run(Test.readFile("cadence/purchase_player_marketplace_v2.tx.cdc"), [mfl, buyer], [seller.address, mfl.address, listingID, price])
}

access(all) fun setup() {
    deploy("DapperUtilityCoin", "./.contracts/_libs/DapperUtilityCoin.cdc")
    deploy("TokenForwarding", "./.contracts/_libs/TokenForwarding.cdc")
    deploy("NFTStorefront", "./.contracts/_libs/NFTStorefront.cdc")
    deploy("NFTStorefrontV2", "./.contracts/_libs/NFTStorefrontV2.cdc")
    deploy("MFLAdmin", "./.contracts/core/MFLAdmin.cdc")
    deploy("MFLPackTemplate", "./.contracts/packs/MFLPackTemplate.cdc")
    deploy("MFLViews", "./.contracts/views/MFLViews.cdc")
    deploy("MFLPlayer", "./.contracts/players/MFLPlayer.cdc")
    deploy("MFLClub", "./.contracts/clubs/MFLClub.cdc")

    // The MFL/Dapper account (0x07) holds the DUC supply and receives the royalty.
    let publishReceiver = "import \"FungibleToken\"\ntransaction { prepare(acct: auth(IssueStorageCapabilityController, PublishCapability) &Account) { acct.capabilities.publish(acct.capabilities.storage.issue<&{FungibleToken.Receiver}>(/storage/dapperUtilityCoinVault), at: /public/dapperUtilityCoinReceiver) } }"
    Test.expect(run(publishReceiver, [mfl], []), Test.beSucceeded())

    // Seller and buyer: DUC forwarder to Dapper (like real Dapper wallets) + MFL collections.
    let setupUser = "import \"FungibleToken\"\nimport \"TokenForwarding\"\nimport \"MFLPlayer\"\nimport \"MFLClub\"\ntransaction(dapper: Address) { prepare(acct: auth(SaveValue, IssueStorageCapabilityController, PublishCapability) &Account) { let fwd <- TokenForwarding.createNewForwarder(recipient: getAccount(dapper).capabilities.get<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)); acct.storage.save(<-fwd, to: /storage/dapperUtilityCoinReceiver); acct.capabilities.publish(acct.capabilities.storage.issue<&{FungibleToken.Receiver}>(/storage/dapperUtilityCoinReceiver), at: /public/dapperUtilityCoinReceiver); acct.storage.save(<-MFLPlayer.createEmptyCollection(nftType: Type<@MFLPlayer.NFT>()), to: MFLPlayer.CollectionStoragePath); acct.capabilities.publish(acct.capabilities.storage.issue<&MFLPlayer.Collection>(MFLPlayer.CollectionStoragePath), at: MFLPlayer.CollectionPublicPath); acct.storage.save(<-MFLClub.createEmptyCollection(nftType: Type<@MFLClub.NFT>()), to: MFLClub.CollectionStoragePath); acct.capabilities.publish(acct.capabilities.storage.issue<&MFLClub.Collection>(MFLClub.CollectionStoragePath), at: MFLClub.CollectionPublicPath) } }"
    Test.expect(run(setupUser, [seller], [mfl.address]), Test.beSucceeded())
    Test.expect(run(setupUser, [buyer], [mfl.address]), Test.beSucceeded())

    mintPlayer(1, seller.address)
    mintPlayer(2, seller.address)
    mintPlayer(3, seller.address)
    mintPlayer(4, seller.address)
    mintClub(10, seller.address)
}

access(all) fun testCreatePlayerListingV2StoresExpiry() {
    let expiry = now() + 3 * DAY
    Test.expect(createPlayerListingV2(1, 100.0, expiry), Test.beSucceeded())
    let ids = v2ListingIDs(seller.address, Type<@MFLPlayer.NFT>(), 1)
    Test.assertEqual(1, ids.length)
    Test.assertEqual(expiry, v2Expiry(seller.address, ids[0]))
}

access(all) fun testRelistReplacesExistingV2Listing() {
    let first = v2ListingIDs(seller.address, Type<@MFLPlayer.NFT>(), 1)
    Test.expect(createPlayerListingV2(1, 120.0, now() + 5 * DAY), Test.beSucceeded())
    let ids = v2ListingIDs(seller.address, Type<@MFLPlayer.NFT>(), 1)
    Test.assertEqual(1, ids.length)
    Test.assert(ids[0] != first[0], message: "relisting should create a new listing")
}

access(all) fun testRejectsExpiryInThePast() {
    let result = createPlayerListingV2(2, 100.0, now() - 10)
    Test.expect(result, Test.beFailed())
    Test.assertError(result, errorMessage: "Expiry must be in the future")
}

access(all) fun testRejectsUnknownDappSigner() {
    let code = Test.readFile("cadence/create_player_listing_v2.tx.cdc")
    let result = run(code, [stranger, seller], [UInt64(2), 100.0, ROYALTY, now() + DAY])
    Test.expect(result, Test.beFailed())
    Test.assertError(result, errorMessage: "Requires valid authorizing signature")
}

access(all) fun testRemovesLegacyV1ListingOfSameNFT() {
    let v1 = Test.readFile("cadence/create_player_listing.tx.cdc")
    Test.expect(run(v1, [mfl, seller], [UInt64(2), 50.0, ROYALTY]), Test.beSucceeded())
    Test.assertEqual(1, v1ListingCount(seller.address))
    Test.expect(createPlayerListingV2(2, 60.0, now() + 2 * DAY), Test.beSucceeded())
    Test.assertEqual(0, v1ListingCount(seller.address))
    Test.assertEqual(1, v2ListingIDs(seller.address, Type<@MFLPlayer.NFT>(), 2).length)
}

access(all) fun testMetadataScriptReadsV2Listing() {
    let id = v2ListingIDs(seller.address, Type<@MFLPlayer.NFT>(), 1)[0]
    let r = Test.executeScript(Test.readFile("cadence/get_player_metadata_from_storefront_listing_v2.script.cdc"), [seller.address, mfl.address, id, 120.0])
    Test.expect(r, Test.beSucceeded())
    Test.assertEqual("Player", r.returnValue! as! String)
}

access(all) fun testPurchaseBeforeExpirySucceeds() {
    let id = v2ListingIDs(seller.address, Type<@MFLPlayer.NFT>(), 1)[0]
    Test.expect(purchasePlayerV2(id, 120.0), Test.beSucceeded())
    Test.assert(ownsPlayer(buyer.address, 1), message: "buyer should own player 1")
    Test.assert(!ownsPlayer(seller.address, 1), message: "seller should not own player 1")
}

access(all) fun testPurchaseAfterExpiryFailsAndCleanupRemovesListing() {
    Test.expect(createPlayerListingV2(3, 80.0, now() + DAY), Test.beSucceeded())
    let id = v2ListingIDs(seller.address, Type<@MFLPlayer.NFT>(), 3)[0]

    Test.moveTime(by: 172800.0)

    let result = purchasePlayerV2(id, 80.0)
    Test.expect(result, Test.beFailed())
    Test.assertError(result, errorMessage: "Listing is expired")
    Test.assert(ownsPlayer(seller.address, 3), message: "seller keeps player 3")

    // Anyone (here: the MFL account) can sweep expired listings, no seller signature needed.
    let cleanup = "import \"NFTStorefrontV2\"\ntransaction(storefrontAddress: Address) { prepare(acct: &Account) { let s = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(NFTStorefrontV2.StorefrontPublicPath)!; s.cleanupExpiredListings(fromIndex: 0, toIndex: UInt64(s.getListingIDs().length - 1)) } }"
    Test.expect(run(cleanup, [mfl], [seller.address]), Test.beSucceeded())
    Test.assertEqual(0, v2ListingIDs(seller.address, Type<@MFLPlayer.NFT>(), 3).length)

    // The seller can relist after expiry.
    Test.expect(createPlayerListingV2(3, 80.0, now() + 7 * DAY), Test.beSucceeded())
    Test.assertEqual(1, v2ListingIDs(seller.address, Type<@MFLPlayer.NFT>(), 3).length)
}

access(all) fun testSellerCanCancelV2Listing() {
    let id = v2ListingIDs(seller.address, Type<@MFLPlayer.NFT>(), 3)[0]
    Test.expect(run(Test.readFile("cadence/remove_listing_v2.tx.cdc"), [seller], [id]), Test.beSucceeded())
    Test.assertEqual(0, v2ListingIDs(seller.address, Type<@MFLPlayer.NFT>(), 3).length)
}

access(all) fun testClubListingV2CreateAndPurchase() {
    let expiry = now() + 4 * DAY
    let created = run(Test.readFile("cadence/create_club_listing_v2.tx.cdc"), [mfl, seller], [UInt64(10), 500.0, ROYALTY, expiry])
    Test.expect(created, Test.beSucceeded())
    let ids = v2ListingIDs(seller.address, Type<@MFLClub.NFT>(), 10)
    Test.assertEqual(1, ids.length)
    Test.assertEqual(expiry, v2Expiry(seller.address, ids[0]))

    let meta = Test.executeScript(Test.readFile("cadence/get_club_metadata_from_storefront_listing_v2.script.cdc"), [seller.address, mfl.address, ids[0], 500.0])
    Test.expect(meta, Test.beSucceeded())
    Test.assertEqual("Club License #10", meta.returnValue! as! String)

    let purchase = run(Test.readFile("cadence/purchase_club_marketplace_v2.tx.cdc"), [mfl, buyer], [seller.address, mfl.address, ids[0], 500.0])
    Test.expect(purchase, Test.beSucceeded())
    Test.assert(ownsClub(buyer.address, 10), message: "buyer should own club 10")
}

access(all) fun testClubListingV2RejectsPastExpiry() {
    mintClub(11, seller.address)
    let result = run(Test.readFile("cadence/create_club_listing_v2.tx.cdc"), [mfl, seller], [UInt64(11), 500.0, ROYALTY, now()])
    Test.expect(result, Test.beFailed())
}
