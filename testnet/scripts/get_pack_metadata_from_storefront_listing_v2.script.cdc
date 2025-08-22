import MetadataViews from 0x631e88ae7f1d7c20
import NFTStorefrontV2 from 0x2d55b98eb200daef
import MFLPack from 0x683564e46977788a

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
    let marketCollectionRef = account.capabilities.borrow<&{NFTStorefrontV2.Storefront}>(
           NFTStorefrontV2.StorefrontPublicPath
       ) ?? panic("Could not borrow Storefront")

    let saleItem = marketCollectionRef.borrowListing(listingResourceID: listingResourceID)
        ?? panic("No item with that ID")

    let listingDetails = saleItem.getDetails()!

    let collection = account.capabilities.borrow<&MFLPack.Collection>(MFLPack.CollectionPublicPath)
        ?? panic("Could not borrow a reference to the collection")

	let nft = collectionRef.borrowNFT(listingDetails.nftID)!
    let displayView = nft.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display

	let purchaseData = PurchaseData(
		id: listingDetails.nftID,
		name: displayView.name,
		amount: listingDetails.salePrice,
		description: displayView.description,
		imageURL: displayView.thumbnail.uri(),
	)

	return purchaseData
}
