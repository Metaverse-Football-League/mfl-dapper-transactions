import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import DapperUtilityCoin from 0x82ec283f88a62e65
import MFLPack from 0x683564e46977788a
import NFTStorefrontV2 from 0x94b06cfca1d8a476

// This transaction purchases a Pack on a peer-to-peer marketplace (i.e. **not** directly from a dapp). This transaction
// will also initialize the buyer's Pack collection on their account if it has not already been initialized.
transaction(storefrontAddress: Address, merchantAccountAddress: Address, listingResourceID: UInt64, expectedPrice: UFix64) {
    let paymentVault: @{FungibleToken.Vault}
    let nftCollection: &MFLPack.Collection
    let storefront: &{NFTStorefrontV2.StorefrontPublic}
    let listing: &{NFTStorefrontV2.ListingPublic}
    let salePrice: UFix64
    let balanceBeforeTransfer: UFix64
    let mainDapperUtilityCoinVault: auth(FungibleToken.Withdraw) &DapperUtilityCoin.Vault

    prepare(dapper: auth(BorrowValue) &Account, buyer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability, SaveValue) &Account) {
        // Initialize the MFLPack collection if the buyer does not already have one
        if buyer.storage.borrow<&MFLPack.Collection>(from: MFLPack.CollectionStoragePath) == nil {
            let collection <- MFLPack.createEmptyCollection(nftType: Type<@MFLPack.NFT>())
            buyer.storage.save(<-collection, to: MFLPack.CollectionStoragePath)

            buyer.capabilities.unpublish(MFLPack.CollectionPublicPath)
            let collectionCap = buyer.capabilities.storage.issue<&MFLPack.Collection>(MFLPack.CollectionStoragePath)
            buyer.capabilities.publish(collectionCap, at: MFLPack.CollectionPublicPath)
        }

        // Get the storefront reference from the seller
        self.storefront = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
                NFTStorefrontV2.StorefrontPublicPath
            ) ?? panic("Could not borrow Storefront for the seller")

        // Get the listing by ID from the storefront
        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
            ?? panic("No Offer with that ID in Storefront")
        self.salePrice = self.listing.getDetails().salePrice

        // Get a DUC vault from Dapper's account
        self.mainDapperUtilityCoinVault = dapper.storage.borrow<auth(FungibleToken.Withdraw) &DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)
            ?? panic("Cannot borrow DapperUtilityCoin vault from account storage")
        self.balanceBeforeTransfer = self.mainDapperUtilityCoinVault.balance
        self.paymentVault <- self.mainDapperUtilityCoinVault.withdraw(amount: self.salePrice)

        // Get the collection from the buyer so the NFT can be deposited into it
        self.nftCollection = buyer.capabilities.borrow<&MFLPack.Collection>(MFLPack.CollectionPublicPath)
            ?? panic("Cannot borrow NFT collection receiver from account")
    }

    // Check that the price is right
    pre {
        self.salePrice == expectedPrice: "unexpected price"
    }

    execute {
        let item <- self.listing.purchase(
            payment: <-self.paymentVault,
            commissionRecipient: nil
        )

        self.nftCollection.deposit(token: <-item)
    }

    // Check that all dapperUtilityCoin was routed back to Dapper
    post {
        self.mainDapperUtilityCoinVault.balance == self.balanceBeforeTransfer: "DapperUtilityCoin leakage"
    }
}
