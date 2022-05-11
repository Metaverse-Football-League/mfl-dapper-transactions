import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import NFTStorefront from 0x94b06cfca1d8a476
import DapperUtilityCoin from 0x82ec283f88a62e65
import MFLPack from 0x683564e46977788a
import MFLPlayer from 0x683564e46977788a

/** 
  This transaction purchases a pack on from a dapp. This transaction will also initialize the buyer's account with a Pack NFT
  collection and a Player NFT collection if it does not already have them.
**/

transaction(storefrontAddress: Address, listingResourceID: UInt64, expectedPrice: UFix64, expectedBuyerAddress: Address) {
    let paymentVault: @FungibleToken.Vault
    let buyerNFTCollection: &AnyResource{NonFungibleToken.CollectionPublic}
    let storefront: &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}
    let listing: &NFTStorefront.Listing{NFTStorefront.ListingPublic}
    let balanceBeforeTransfer: UFix64
    let mainDUCVault: &DapperUtilityCoin.Vault
    let dappAddress: Address
    let buyerAddress: Address
    let salePrice: UFix64

    prepare(dapp: AuthAccount, dapper: AuthAccount, buyer: AuthAccount) {
        self.dappAddress = dapp.address
        self.buyerAddress = buyer.address

        // Initialize the MFLPlayer collection if the buyer does not already have one
        if buyer.borrow<&MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath) == nil {
            buyer.save(<- MFLPlayer.createEmptyCollection(), to: MFLPlayer.CollectionStoragePath)
            buyer.link<&MFLPlayer.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
                MFLPlayer.CollectionPublicPath,
                target: MFLPlayer.CollectionStoragePath
            )
                ?? panic("Could not link collection Pub Path")
        }

        // Initialize the MFLPack collection if the buyer does not already have one
        if buyer.borrow<&MFLPack.Collection>(from: MFLPack.CollectionStoragePath) == nil {
            buyer.save(<-MFLPack.createEmptyCollection(), to: MFLPack.CollectionStoragePath);
            buyer.link<&MFLPack.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
                MFLPack.CollectionPublicPath,
                target: MFLPack.CollectionStoragePath
            )
                ?? panic("Could not link MFLPack.Collection Pub Path")
        }

        self.storefront = getAccount(storefrontAddress)
            .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath)
            .borrow()
            ?? panic("Could not borrow a reference to the storefront")
        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
            ?? panic("No Listing with that ID in Storefront")
        
        self.salePrice = self.listing.getDetails().salePrice

        self.mainDUCVault = dapper.borrow<&DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)
            ?? panic("Could not borrow reference to Dapper Utility Coin vault")
        self.balanceBeforeTransfer = self.mainDUCVault.balance
        self.paymentVault <- self.mainDUCVault.withdraw(amount: self.salePrice)

        self.buyerNFTCollection = buyer
            .getCapability<&MFLPack.Collection{NonFungibleToken.CollectionPublic}>(MFLPack.CollectionPublicPath)
            .borrow()
            ?? panic("Cannot borrow NFT collection receiver from account")
    }

    pre {
        self.salePrice == expectedPrice: "unexpected price"
        self.dappAddress == 0xbfff3f3685929cbd : "Requires valid authorizing signature"
        self.buyerAddress == expectedBuyerAddress : "invalid buyer's address"
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