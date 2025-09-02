import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import DapperUtilityCoin from 0x82ec283f88a62e65
import MFLPack from 0x683564e46977788a
import NFTStorefrontV2 from 0x2d55b98eb200daef

transaction(
    saleItemID: UInt64,
    saleItemPrice: UFix64,
    royaltyPercent: UFix64,
    expiry: UInt64,
) {
  	let sellerPaymentReceiver: Capability<&{FungibleToken.Receiver}>
	let nftProviderCap: Capability<auth(NonFungibleToken.Withdraw) &MFLPack.Collection>
	let storefront: auth(NFTStorefrontV2.CreateListing, NFTStorefrontV2.RemoveListing) &NFTStorefrontV2.Storefront
	let dappAddress: Address

    prepare(dapp: &Account, seller: auth(BorrowValue, CopyValue, LoadValue, SaveValue, IssueStorageCapabilityController, PublishCapability) &Account) {
        self.dappAddress = dapp.address

        // If the account doesn't already have a Storefront
        // Create a new empty Storefront
        if seller.storage.borrow<&NFTStorefrontV2.Storefront>(from: NFTStorefrontV2.StorefrontStoragePath) == nil {

            // Create a new empty Storefront
            let storefront <- NFTStorefrontV2.createStorefront() as! @NFTStorefrontV2.Storefront

            // save it to the account
            seller.storage.save(<-storefront, to: NFTStorefrontV2.StorefrontStoragePath)

            // create a public capability for the Storefront
            let storefrontPublicCap = seller.capabilities.storage.issue<&{NFTStorefrontV2.StorefrontPublic}>(
                    NFTStorefrontV2.StorefrontStoragePath
                )
            seller.capabilities.publish(storefrontPublicCap, at: NFTStorefrontV2.StorefrontPublicPath)
        }

        // Get a reference to the receiver that will receive the fungible tokens if the sale executes.
        self.sellerPaymentReceiver = seller.capabilities.get<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
        assert(self.sellerPaymentReceiver.check(), message: "Missing or mis-typed DapperUtilityCoin receiver")

    	// Get a capability to access the user's NFT collection.
       	let nftProviderCapStoragePath: StoragePath = /storage/MFLPackCollectionCap
       	let cap = seller.storage.copy<Capability<auth(NonFungibleToken.Withdraw) &MFLPack.Collection>>(from: nftProviderCapStoragePath)
       	if cap != nil && cap!.check() {
       	    self.nftProviderCap = cap!
       	} else {
       	    // clean this storage slot in case something is there already
       	    seller.storage.load<AnyStruct>(from: nftProviderCapStoragePath)
       	    self.nftProviderCap = seller.capabilities.storage.issue<auth(NonFungibleToken.Withdraw) &MFLPack.Collection>(MFLPack.CollectionStoragePath)
       	    seller.storage.save(self.nftProviderCap, to: nftProviderCapStoragePath)
       	}
        assert(self.nftProviderCap.check(), message: "Missing or mis-typed collection provider")

        self.storefront = seller.storage.borrow<auth(NFTStorefrontV2.CreateListing, NFTStorefrontV2.RemoveListing) &NFTStorefrontV2.Storefront>(
                from: NFTStorefrontV2.StorefrontStoragePath
            ) ?? panic("Could not get a Storefront from the signer's account at path (NFTStorefrontV2.StorefrontStoragePath)!"
                        .concat("Make sure the signer has initialized their account with a NFTStorefrontV2 storefront!"))
    }

    // Make sure dapp is actually the dapp and not some random account
    pre {
        self.dappAddress == 0xbfff3f3685929cbd : "Requires valid authorizing signature"
    }

    execute {
    	let nftType = Type<@MFLPack.NFT>()
    	let salePaymentVaultType = Type<@DapperUtilityCoin.Vault>()

        let amountSeller = saleItemPrice * (1.0 - royaltyPercent)
        let saleCutSeller = NFTStorefrontV2.SaleCut(
            receiver: self.sellerPaymentReceiver,
            amount: amountSeller
        )

        // Get the royalty recipient's public account object
        let royaltyRecipient = getAccount(0xbfff3f3685929cbd)
        // Get a reference to the royalty recipient's Receiver
        let royaltyReceiverRef = royaltyRecipient.capabilities.get<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
        assert(royaltyReceiverRef.borrow() != nil, message: "Missing or mis-typed DapperUtilityCoin royalty receiver")
        let amountRoyalty = saleItemPrice - amountSeller
        let saleCutRoyalty = NFTStorefrontV2.SaleCut(
            receiver: royaltyReceiverRef,
            amount: amountRoyalty
        )

  		// check for existing listings of the NFT
        var existingListingIDs = self.storefront.getExistingListingIDs(
            nftType: nftType,
            nftID: saleItemID
        )
        // remove existing listings
        for listingID in existingListingIDs {
            self.storefront.removeListing(listingResourceID: listingID)
        }

        // Create listing
        self.storefront.createListing(
            nftProviderCapability: self.nftProviderCap,
            nftType: nftType,
            nftID: saleItemID,
            salePaymentVaultType: salePaymentVaultType,
            saleCuts: [saleCutSeller, saleCutRoyalty],
            marketplacesCapability: nil,
			customID: nil,
			commissionAmount: 0.0,
			expiry: expiry
        )
    }
}
