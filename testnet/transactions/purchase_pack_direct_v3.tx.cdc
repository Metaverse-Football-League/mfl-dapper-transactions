import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import NFTStorefront from 0x94b06cfca1d8a476
import DapperUtilityCoin from 0x82ec283f88a62e65
import MFLPack from 0x683564e46977788a
import MFLPlayer from 0x683564e46977788a
import MFLClub from 0x683564e46977788a

/**
  This transaction purchases a pack on from a dapp. This transaction will also initialize the buyer's account with a Pack NFT
  collection and a Player NFT collection if it does not already have them.
**/

transaction(storefrontAddress: Address, merchantAccountAddress: Address, listingResourceID: UInt64, expectedPrice: UFix64) {
    let paymentVault: @{FungibleToken.Vault}
    let buyerNFTCollection: &MFLPack.Collection
    let storefront: &{NFTStorefront.StorefrontPublic}
    let listing: &{NFTStorefront.ListingPublic}
    let balanceBeforeTransfer: UFix64
    let mainDUCVault: auth(FungibleToken.Withdraw) &DapperUtilityCoin.Vault
    let dappAddress: Address
    let salePrice: UFix64

    prepare(dapp: &Account, dapper: auth(BorrowValue) &Account, buyer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability, SaveValue) &Account) {
        self.dappAddress = dapp.address

        // Initialize the MFLPlayer collection if the buyer does not already have one
        if buyer.storage.borrow<&MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath) == nil {
            let collection <- MFLPlayer.createEmptyCollection(nftType: Type<@MFLPlayer.NFT>())
            buyer.storage.save(<-collection, to: MFLPlayer.CollectionStoragePath)

            buyer.capabilities.unpublish(MFLPlayer.CollectionPublicPath)
            let collectionCap = buyer.capabilities.storage.issue<&MFLPlayer.Collection>(MFLPlayer.CollectionStoragePath)
            buyer.capabilities.publish(collectionCap, at: MFLPlayer.CollectionPublicPath)
        }

        // Initialize the MFLPack collection if the buyer does not already have one
        if buyer.storage.borrow<&MFLPack.Collection>(from: MFLPack.CollectionStoragePath) == nil {
            let collection <- MFLPack.createEmptyCollection(nftType: Type<@MFLPack.NFT>())
            buyer.storage.save(<-collection, to: MFLPack.CollectionStoragePath)

            buyer.capabilities.unpublish(MFLPack.CollectionPublicPath)
            let collectionCap = buyer.capabilities.storage.issue<&MFLPack.Collection>(MFLPack.CollectionStoragePath)
            buyer.capabilities.publish(collectionCap, at: MFLPack.CollectionPublicPath)
        }

        // Initialize the MFLClub collection if the buyer does not already have one
        if buyer.storage.borrow<&MFLClub.Collection>(from: MFLClub.CollectionStoragePath) == nil {
            let collection <- MFLClub.createEmptyCollection(nftType: Type<@MFLClub.NFT>())
            buyer.storage.save(<-collection, to: MFLClub.CollectionStoragePath)

            buyer.capabilities.unpublish(MFLClub.CollectionPublicPath)
            let collectionCap = buyer.capabilities.storage.issue<&MFLClub.Collection>(MFLClub.CollectionStoragePath)
            buyer.capabilities.publish(collectionCap, at: MFLClub.CollectionPublicPath)
        }

        self.storefront = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefront.StorefrontPublic}>(
                NFTStorefront.StorefrontPublicPath
            ) ?? panic("Could not borrow Storefront for the seller")
        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
            ?? panic("No Listing with that ID in Storefront")

        self.salePrice = self.listing.getDetails().salePrice

        self.mainDUCVault = dapper.storage.borrow<auth(FungibleToken.Withdraw) &DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)
            ?? panic("Cannot borrow DapperUtilityCoin vault from account storage")
        self.balanceBeforeTransfer = self.mainDUCVault.balance
        self.paymentVault <- self.mainDUCVault.withdraw(amount: self.salePrice)

        self.buyerNFTCollection = buyer.capabilities.borrow<&MFLPack.Collection>(from: MFLPack.CollectionPublicPath)
            ?? panic("Cannot borrow NFT collection receiver from account")
    }

    pre {
        self.salePrice == expectedPrice: "unexpected price"
        self.dappAddress == 0xbfff3f3685929cbd : "Requires valid authorizing signature"
    }

    execute {
        let item <- self.listing.purchase(
            payment: <-self.paymentVault
        )

        self.buyerNFTCollection.deposit(token: <-item)
    }

    post {
        self.mainDUCVault.balance == self.balanceBeforeTransfer: "DUC leakage"
    }

}
