import MetadataViews from 0x1d7e57aa55817448
import NFTStorefront from 0x4eb8a10cb9f87357
import MFLClub from 0x8ebcbfd516b1da27


access(all)
struct PurchaseData {

    access(all)
    let id: UInt64

    access(all)
    let name: String

    access(all)
    let amount: UFix64

    access(all)
    let description: String?

    access(all)
    let imageURL: String?

    init(id: UInt64, name: String, amount: UFix64, description: String?, imageURL: String?) {
        self.id = id
        self.name = name
        self.amount = amount
        self.description = description
        self.imageURL = imageURL
    }
}


access(all)
fun main(storefrontAddress: Address, merchantAccountAddress: Address, listingResourceID: UInt64, expectedPrice: UFix64): PurchaseData {

  let account = getAccount(storefrontAddress)
    let marketCollectionRef = account.capabilities.borrow<&{NFTStorefront.StorefrontPublic}>(
           NFTStorefront.StorefrontPublicPath
       ) ?? panic("Could not borrow Storefront")

    let saleItem = marketCollectionRef.borrowListing(listingResourceID: listingResourceID)
        ?? panic("No item with that ID")

    let listingDetails = saleItem.getDetails()!

    let collection = account.capabilities.borrow<&MFLClub.Collection>(MFLClub.CollectionPublicPath)
        ?? panic("Could not borrow a reference to the collection")

    let nft = collection.borrowViewResolver(id: listingDetails.nftID ) ?? panic("Could not borrow the view resolved")

    if let view = nft.resolveView(Type<MetadataViews.Display>()) {

        let display = view as! MetadataViews.Display
        let purchaseData = PurchaseData(
            id: listingDetails.nftID,
            name: display.name,
            amount: listingDetails.salePrice,
            description: display.description,
            imageURL: display.thumbnail.uri(),
        )

        return purchaseData
    }
    panic("No NFT")
}
