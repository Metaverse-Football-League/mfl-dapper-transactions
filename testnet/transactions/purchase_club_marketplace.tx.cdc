import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import DapperUtilityCoin from 0x82ec283f88a62e65
import MFLClub from 0x683564e46977788a
import NFTStorefront from 0x94b06cfca1d8a476

// This transaction purchases a Club on a peer-to-peer marketplace (i.e. **not** directly from a dapp). This transaction
// will also initialize the buyer's Club collection on their account if it has not already been initialized.
transaction(storefrontAddress: Address, merchantAccountAddress: Address, listingResourceID: UInt64, expectedPrice: UFix64) {
    let paymentVault: @{FungibleToken.Vault}
    let nftCollection: &MFLClub.Collection
    let storefront: &{NFTStorefront.StorefrontPublic}
    let listing: &{NFTStorefront.ListingPublic}
    let salePrice: UFix64
    let balanceBeforeTransfer: UFix64
    let mainDapperUtilityCoinVault: &DapperUtilityCoin.Vault

    prepare(dapper: auth(BorrowValue) &Account, buyer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability, SaveValue) &Account) {
        // Initialize the MFLClub collection if the buyer does not already have one
        if buyer.storage.borrow<&MFLClub.Collection>(from: MFLClub.CollectionStoragePath) == nil {
            let collection <- MFLClub.createEmptyCollection(nftType: Type<@MFLClub.NFT>())
            buyer.storage.save(<-collection, to: MFLClub.CollectionStoragePath)

            buyer.capabilities.unpublish(MFLClub.CollectionPublicPath)
            let collectionCap = buyer.capabilities.storage.issue<&MFLClub.Collection>(MFLClub.CollectionStoragePath)
            buyer.capabilities.publish(collectionCap, at: MFLClub.CollectionPublicPath)
        }

        // Get the storefront reference from the seller
        self.storefront = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefront.StorefrontPublic}>(
                NFTStorefront.StorefrontPublicPath
            ) ?? panic("Could not borrow Storefront for the seller")

        // Get the listing by ID from the storefront
        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
            ?? panic("No Offer with that ID in Storefront")
        self.salePrice = self.listing.getDetails().salePrice

        // Get a DUC vault from Dapper's account
        self.mainDapperUtilityCoinVault = dapper.storage.borrow<&DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)
            ?? panic("Cannot borrow DapperUtilityCoin vault from account storage")
        self.balanceBeforeTransfer = self.mainDapperUtilityCoinVault.balance
        self.paymentVault <- self.mainDapperUtilityCoinVault.withdraw(amount: self.salePrice)

        // Get the collection from the buyer so the NFT can be deposited into it
        self.nftCollection = buyer.capabilities.borrow<&MFLClub.Collection>(MFLClub.CollectionPublicPath)
            ?? panic("Cannot borrow NFT collection receiver from account")
    }

    // Check that the price is right
    pre {
        self.salePrice == expectedPrice: "unexpected price"
    }

    execute {
        let item <- self.listing.purchase(
            payment: <-self.paymentVault
        )

        self.nftCollection.deposit(token: <-item)

        // Remove listing-related information from the storefront since the listing has been purchased.
        self.storefront.cleanup(listingResourceID: listingResourceID)
    }

    // Check that all dapperUtilityCoin was routed back to Dapper
    post {
        self.mainDapperUtilityCoinVault.balance == self.balanceBeforeTransfer: "DapperUtilityCoin leakage"
    }
}
