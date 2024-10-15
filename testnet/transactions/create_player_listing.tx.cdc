import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import DapperUtilityCoin from 0x82ec283f88a62e65
import MFLPlayer from 0x683564e46977788a
import NFTStorefront from 0x94b06cfca1d8a476

/**
  This transaction can be used to place a Player NFT for sale on a marketplace such that a specified percentage of the proceeds of the sale
  go to the dapp as a royalty.
**/

transaction(saleItemID: UInt64, saleItemPrice: UFix64, royaltyPercent: UFix64) {
    let sellerPaymentReceiver: Capability<&{FungibleToken.Receiver}>
    let nftProviderCap: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: auth(NFTStorefront.CreateListing, NFTStorefront.RemoveListing) &NFTStorefront.Storefront
    let dappAddress: Address

    // It's important that the dapp account authorize this transaction so the dapp as the ability
    // to validate and approve the royalty included in the sale.
    prepare(dapp: &Account, seller: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability, LoadValue, SaveValue, CopyValue) &Account) {
        self.dappAddress = dapp.address

        // If the account doesn't already have a Storefront
        if seller.storage.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) == nil {
            // Save a new .Storefront to account storage
            seller.storage.save(
                <- NFTStorefront.createStorefront(),
                to: NFTStorefront.StorefrontStoragePath
            )
            // create a public capability for the .Storefront & publish
            let storefrontPublicCap = seller.capabilities.storage.issue<&{NFTStorefront.StorefrontPublic}>(
                NFTStorefront.StorefrontStoragePath
            )
            seller.capabilities.publish(storefrontPublicCap, at: NFTStorefront.StorefrontPublicPath)
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
        let cap = seller.storage.copy<Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>>(from: MFLPlayer.CollectionStoragePath)
        if cap != nil && cap!.check() {
            self.nftProviderCap = cap!
        } else {
            // clean this storage slot in case something is there already
            seller.storage.load<AnyStruct>(from: MFLPlayer.CollectionStoragePath)
            self.nftProviderCap = seller.capabilities.storage.issue<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(nftProviderCapStoragePath)
            seller.storage.save(self.nftProviderCap, to: MFLPlayer.CollectionStoragePath)
        }
        assert(self.nftProviderCap.check(), message: "Missing or mis-typed collection provider")

        // Get a reference to the user's NFT storefront
        self.storefront = seller.storage.borrow<auth(NFTStorefront.CreateListing, NFTStorefront.RemoveListing) &NFTStorefront.Storefront>(
                from: NFTStorefront.StorefrontStoragePath
            ) ?? panic("Missing or mis-typed NFTStorefront Storefront")

        // Make sure this NFT is not already listed for sale in this storefront.
        let existingOffers = self.storefront.getListingIDs()
        if existingOffers.length > 0 {
            for listingResourceID in existingOffers {
                let listing: &{NFTStorefront.ListingPublic}? = self.storefront.borrowListing(listingResourceID: listingResourceID)
                if listing != nil && listing!.getDetails().nftID == saleItemID && listing!.getDetails().nftType == Type<@MFLPlayer.NFT>(){
                    self.storefront.removeListing(listingResourceID: listingResourceID)
                }
            }
        }
    }

    // Make sure dapp is actually the dapp and not some random account
    pre {
        self.dappAddress == 0xbfff3f3685929cbd : "Requires valid authorizing signature"
    }

    execute {
        // Calculate the amout the seller should receive if the sale executes, and the amount
        // that should be sent to the dapp as a royalty.
        let amountSeller = saleItemPrice * (1.0 - royaltyPercent)
        let amountRoyalty = saleItemPrice - amountSeller

        // Get the royalty recipient's public account object
        let royaltyRecipient = getAccount(0xbfff3f3685929cbd)

        // Get a reference to the royalty recipient's Receiver
        let royaltyReceiverRef = royaltyRecipient.capabilities.get<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
        assert(royaltyReceiverRef.borrow() != nil, message: "Missing or mis-typed DapperUtilityCoin royalty receiver")

        let saleCutSeller = NFTStorefront.SaleCut(
            receiver: self.sellerPaymentReceiver,
            amount: amountSeller
        )

        let saleCutRoyalty = NFTStorefront.SaleCut(
            receiver: royaltyReceiverRef,
            amount: amountRoyalty
        )

        self.storefront.createListing(
            nftProviderCapability: self.nftProviderCap,
            nftType: Type<@MFLPlayer.NFT>(),
            nftID: saleItemID,
            salePaymentVaultType: Type<@DapperUtilityCoin.Vault>(),
            saleCuts: [saleCutSeller, saleCutRoyalty]
        )
    }
}
