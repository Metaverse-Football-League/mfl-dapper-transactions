import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import NFTStorefront from 0x4eb8a10cb9f87357
import DapperUtilityCoin from 0xead892083b3e2c6c
import MFLPack from 0x8ebcbfd516b1da27
import MFLPlayer from 0x8ebcbfd516b1da27
import MFLClub from 0x8ebcbfd516b1da27

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

    prepare(dapp: &Account, dapper: auth(BorrowValue) &Account, buyer: auth(BorrowValue) &Account) {
        self.dappAddress = dapp.address

        // Initialize the MFLPlayer collection if the buyer does not already have one
        if acct.storage.borrow<&MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath) == nil {
            let collection <- MFLPlayer.createEmptyCollection(nftType: Type<@MFLPlayer.NFT>())
            acct.storage.save(<-collection, to: MFLPlayer.CollectionStoragePath)

            acct.capabilities.unpublish(MFLPlayer.CollectionPublicPath)
            let collectionCap = acct.capabilities.storage.issue<&MFLPlayer.Collection>(MFLPlayer.CollectionStoragePath)
            acct.capabilities.publish(collectionCap, at: MFLPlayer.CollectionPublicPath)
        }

        // Initialize the MFLPack collection if the buyer does not already have one
        if acct.storage.borrow<&MFLPack.Collection>(from: MFLPack.CollectionStoragePath) == nil {
            let collection <- MFLPack.createEmptyCollection(nftType: Type<@MFLPack.NFT>())
            acct.storage.save(<-collection, to: MFLPack.CollectionStoragePath)

            acct.capabilities.unpublish(MFLPack.CollectionPublicPath)
            let collectionCap = acct.capabilities.storage.issue<&MFLPack.Collection>(MFLPack.CollectionStoragePath)
            acct.capabilities.publish(collectionCap, at: MFLPack.CollectionPublicPath)
        }

        // Initialize the MFLClub collection if the buyer does not already have one
        if acct.storage.borrow<&MFLClub.Collection>(from: MFLClub.CollectionStoragePath) == nil {
            let collection <- MFLClub.createEmptyCollection(nftType: Type<@MFLClub.NFT>())
            acct.storage.save(<-collection, to: MFLClub.CollectionStoragePath)

            acct.capabilities.unpublish(MFLClub.CollectionPublicPath)
            let collectionCap = acct.capabilities.storage.issue<&MFLClub.Collection>(MFLClub.CollectionStoragePath)
            acct.capabilities.publish(collectionCap, at: MFLClub.CollectionPublicPath)
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
