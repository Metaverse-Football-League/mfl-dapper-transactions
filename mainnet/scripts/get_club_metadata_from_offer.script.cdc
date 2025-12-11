import MetadataViews from 0x1d7e57aa55817448
import MFLClub from 0x8ebcbfd516b1da27

access(all)
struct OfferV2Metadata {
	access(all) let amount: UFix64
	access(all) let royalties: {Address: UFix64}
	access(all) let params: {String: String}

	init(amount: UFix64, royalties: {Address: UFix64}, clubId: UInt64) {
		let clubData = MFLClub.getClubData(id: clubId)
                ?? panic("could not get club data")
		let view = MFLClub.resolveViewFromData(Type<MetadataViews.Display>(), clubData: clubData)
		 	?? panic("could not get display view")
		let displayView = view as! MetadataViews.Display

		let params: {String: String} = {}
 		params["assetName"] =  displayView.name
		params["assetImageUrl"] = displayView.thumbnail.uri()
		params["assetDescription"] = displayView.description
		params["typeId"] = "A.8ebcbfd516b1da27.MFLClub.NFT"
		params["_type"] = "NFT"
		params["nftId"] =  clubId.toString()

		self.amount = amount
		self.royalties = royalties
		self.params = params
	}
}

access(all)
fun main(amount: UFix64, royalties: {Address: UFix64}, clubId: UInt64, expiry: UInt64): OfferV2Metadata {
	return OfferV2Metadata(amount: amount, royalties: royalties, clubId: clubId)
}
