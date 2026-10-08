import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import DapperUtilityCoin from 0xead892083b3e2c6c
import MFLPlayer from 0x8ebcbfd516b1da27
import NFTStorefront from 0x4eb8a10cb9f87357
import NFTStorefrontV2 from 0x4eb8a10cb9f87357

/**
  This transaction can be used to place a Player NFT for sale on a marketplace (NFTStorefrontV2) such that a specified percentage of the proceeds of the sale
  go to the dapp as a royalty. The listing expires at `expiry` (unix timestamp in seconds).
**/

transaction(saleItemID: UInt64, saleItemPrice: UFix64, royaltyPercent: UFix64, expiry: UInt64) {
    let sellerPaymentReceiver: Capability<&{FungibleToken.Receiver}>
    let nftProviderCap: Capability<auth(NonFungibleToken.Withdraw) &MFLPlayer.Collection>
    let storefront: auth(NFTStorefrontV2.CreateListing, NFTStorefrontV2.RemoveListing) &NFTStorefrontV2.Storefront
    let dappAddress: Address

    // It's important that the dapp account authorize this transaction so the dapp as the ability
    // to validate and approve the royalty included in the sale.
    prepare(dapp: &Account, seller: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability, LoadValue, SaveValue, CopyValue) &Account) {
        self.dappAddress = dapp.address

        // If the account doesn't already have a StorefrontV2
        if seller.storage.borrow<&NFTStorefrontV2.Storefront>(from: NFTStorefrontV2.StorefrontStoragePath) == nil {
            // Save a new StorefrontV2 to account storage
            seller.storage.save(
                <- NFTStorefrontV2.createStorefront(),
                to: NFTStorefrontV2.StorefrontStoragePath
            )
            // create a public capability for the StorefrontV2 & publish
            let storefrontPublicCap = seller.capabilities.storage.issue<&{NFTStorefrontV2.StorefrontPublic}>(
                NFTStorefrontV2.StorefrontStoragePath
            )
            seller.capabilities.publish(storefrontPublicCap, at: NFTStorefrontV2.StorefrontPublicPath)
        }

        // Get a reference to the receiver that will receive the fungible tokens if the sale executes.
        self.sellerPaymentReceiver = seller.capabilities.get<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
        assert(self.sellerPaymentReceiver.check(), message: "Missing or mis-typed DapperUtilityCoin receiver")

        // If the user does not have their collection set up
        if seller.storage.borrow<&MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath) == nil {
          let collection <- MFLPlayer.createEmptyCollection(nftType: Type<@MFLPlayer.NFT>())
          seller.storage.save(<-collection, to: MFLPlayer.CollectionStoragePath)

          seller.capabilities.unpublish(MFLPlayer.CollectionPublicPath)
          let collectionCap = seller.capabilities.storage.issue<&MFLPlayer.Collection>(MFLPlayer.CollectionStoragePath)
          seller.capabilities.publish(collectionCap, at: MFLPlayer.CollectionPublicPath)
        }

        // Get a capability to access the user's NFT collection.
        let nftProviderCapStoragePath: StoragePath = /storage/MFLPlayerCollectionCap
        let cap = seller.storage.copy<Capability<auth(NonFungibleToken.Withdraw) &MFLPlayer.Collection>>(from: nftProviderCapStoragePath)
        if cap != nil && cap!.check() {
            self.nftProviderCap = cap!
        } else {
            // clean this storage slot in case something is there already
            seller.storage.load<AnyStruct>(from: nftProviderCapStoragePath)
            self.nftProviderCap = seller.capabilities.storage.issue<auth(NonFungibleToken.Withdraw) &MFLPlayer.Collection>(MFLPlayer.CollectionStoragePath)
            seller.storage.save(self.nftProviderCap, to: nftProviderCapStoragePath)
        }
        assert(self.nftProviderCap.check(), message: "Missing or mis-typed collection provider")

        // Get a reference to the user's NFT StorefrontV2
        self.storefront = seller.storage.borrow<auth(NFTStorefrontV2.CreateListing, NFTStorefrontV2.RemoveListing) &NFTStorefrontV2.Storefront>(
                from: NFTStorefrontV2.StorefrontStoragePath
            ) ?? panic("Missing or mis-typed NFTStorefrontV2 Storefront")

        // Remove a legacy (NFTStorefront V1) listing of this NFT, if any, so the NFT is never listed twice.
        if let legacyStorefront = seller.storage.borrow<auth(NFTStorefront.RemoveListing) &NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) {
            for listingResourceID in legacyStorefront.getListingIDs() {
                let listing: &{NFTStorefront.ListingPublic}? = legacyStorefront.borrowListing(listingResourceID: listingResourceID)
                if listing != nil && listing!.getDetails().nftID == saleItemID && listing!.getDetails().nftType == Type<@MFLPlayer.NFT>() {
                    legacyStorefront.removeListing(listingResourceID: listingResourceID)
                }
            }
        }
    }

    // Make sure dapp is actually the dapp and not some random account
    pre {
        self.dappAddress == 0x15e71a9f7fe7d53d : "Requires valid authorizing signature"
        expiry > UInt64(getCurrentBlock().timestamp) : "Expiry must be in the future"
    }

    execute {
        let nftType = Type<@MFLPlayer.NFT>()

        // Calculate the amout the seller should receive if the sale executes, and the amount
        // that should be sent to the dapp as a royalty.
        let amountSeller = saleItemPrice * (1.0 - royaltyPercent)
        let amountRoyalty = saleItemPrice - amountSeller

        // Get the royalty recipient's public account object
        let royaltyRecipient = getAccount(0x15e71a9f7fe7d53d)

        // Get a reference to the royalty recipient's Receiver
        let royaltyReceiverRef = royaltyRecipient.capabilities.get<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
        assert(royaltyReceiverRef.borrow() != nil, message: "Missing or mis-typed DapperUtilityCoin royalty receiver")

        let saleCutSeller = NFTStorefrontV2.SaleCut(
            receiver: self.sellerPaymentReceiver,
            amount: amountSeller
        )

        let saleCutRoyalty = NFTStorefrontV2.SaleCut(
            receiver: royaltyReceiverRef,
            amount: amountRoyalty
        )

        // Make sure this NFT is not already listed for sale in this storefront.
        let existingListingIDs = self.storefront.getExistingListingIDs(
            nftType: nftType,
            nftID: saleItemID
        )
        for listingID in existingListingIDs {
            self.storefront.removeListing(listingResourceID: listingID)
        }

        self.storefront.createListing(
            nftProviderCapability: self.nftProviderCap,
            nftType: nftType,
            nftID: saleItemID,
            salePaymentVaultType: Type<@DapperUtilityCoin.Vault>(),
            saleCuts: [saleCutSeller, saleCutRoyalty],
            marketplacesCapability: nil,
            customID: nil,
            commissionAmount: 0.0,
            expiry: expiry
        )
    }
}
