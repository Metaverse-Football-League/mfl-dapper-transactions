access(all) struct AcceptOfferMetadata {
	access(all) let offerId: UInt64
	access(all) let nftId: UInt64

	init(nftId: UInt64, offerId: UInt64) {
		self.nftId = nftId
		self.offerId = offerId
	}
}

access(all) fun main(nftId: UInt64, offerId: UInt64, dapperOfferAddress: Address): AcceptOfferMetadata {
	return AcceptOfferMetadata(nftId: nftId, offerId: offerId)
}
