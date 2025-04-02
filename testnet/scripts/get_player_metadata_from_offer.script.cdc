import MetadataViews from 0x631e88ae7f1d7c20
import MFLPlayer from 0x683564e46977788a

access(all)
struct OfferV2Metadata {
	access(all) let amount: UFix64
	access(all) let royalties: {Address: UFix64}
	access(all) let params: {String: String}

	init(amount: UFix64, royalties: {Address: UFix64}, playerId: UInt64) {
		let playerData = MFLPlayer.getPlayerData(id: playerId)
                ?? panic("could not get player data")
		let view = MFLPlayer.resolveViewFromData(Type<MetadataViews.Display>(), playerData: playerData)
		 	?? panic("could not get display view")
		let displayView = view as! MetadataViews.Display

 		paramsString["assetName"] =  displayView.name
		paramsString["assetImageUrl"] = displayView.thumbnail.uri()
		paramsString["assetDescription"] = displayView.description
		paramsString["typeId"] = "Type<@MFLPlayer.NFT>()"

		self.amount = amount
		self.royalties = royalties
		self.params = paramsString
	}
}

access(all)
fun main(amount: UFix64, royalties: {Address: UFix64}, playerId: UInt64, expiry: UInt64): OfferV2Metadata {
	return OfferV2Metadata(amount: amount, royalties: royalties, playerId: playerId)
}
