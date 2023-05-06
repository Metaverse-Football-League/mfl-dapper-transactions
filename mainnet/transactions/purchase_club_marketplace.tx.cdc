import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import DapperUtilityCoin from 0xead892083b3e2c6c
import MFLClub from 0x8ebcbfd516b1da27
import NFTStorefront from 0x4eb8a10cb9f87357

// This transaction purchases a Club on a peer-to-peer marketplace (i.e. **not** directly from a dapp). This transaction
// will also initialize the buyer's Club collection on their account if it has not already been initialized.
transaction(storefrontAddress: Address, merchantAccountAddress: Address, listingResourceID: UInt64, expectedPrice: UFix64) {
    let paymentVault: @FungibleToken.Vault
    let nftCollection: &AnyResource{NonFungibleToken.CollectionPublic}
    let storefront: &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}
    let listing: &NFTStorefront.Listing{NFTStorefront.ListingPublic}
    let salePrice: UFix64
    let balanceBeforeTransfer: UFix64
    let mainDapperUtilityCoinVault: &DapperUtilityCoin.Vault

    prepare(dapper: AuthAccount, buyer: AuthAccount) {
        // Initialize the MFLClub collection if the buyer does not already have one
        if buyer.borrow<&MFLClub.Collection>(from: MFLClub.CollectionStoragePath) == nil {
            buyer.save(<-MFLClub.createEmptyCollection(), to: MFLClub.CollectionStoragePath);
            buyer.link<&MFLClub.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
                MFLClub.CollectionPublicPath,
                target: MFLClub.CollectionStoragePath
            )
                ?? panic("Could not link MFLClub.Collection Pub Path")
        }

        // Get the storefront reference from the seller
        self.storefront = getAccount(storefrontAddress)
            .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(
                NFTStorefront.StorefrontPublicPath
            )!
            .borrow()
            ?? panic("Could not borrow Storefront from provided address")

        // Get the listing by ID from the storefront
        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
            ?? panic("No Offer with that ID in Storefront")
        self.salePrice = self.listing.getDetails().salePrice

        // Get a DUC vault from Dapper's account
        self.mainDapperUtilityCoinVault = dapper.borrow<&DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)
            ?? panic("Cannot borrow DapperUtilityCoin vault from account storage")
        self.balanceBeforeTransfer = self.mainDapperUtilityCoinVault.balance
        self.paymentVault <- self.mainDapperUtilityCoinVault.withdraw(amount: self.salePrice)

       // If the user does not have their collection linked to their account, link it.
        let hasLinkedCollection = buyer.getCapability<&MFLClub.Collection{NonFungibleToken.CollectionPublic}>(MFLClub.CollectionPublicPath)!.check()
        if !hasLinkedCollection {
            buyer.unlink(MFLClub.CollectionPublicPath)
            buyer.link<&MFLClub.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
                MFLClub.CollectionPublicPath,
                target: MFLClub.CollectionStoragePath
            )
        }
        // Get the collection from the buyer so the NFT can be deposited into it
        self.nftCollection = buyer
            .getCapability<&MFLClub.Collection{NonFungibleToken.CollectionPublic}>(MFLClub.CollectionPublicPath)
            .borrow()
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
