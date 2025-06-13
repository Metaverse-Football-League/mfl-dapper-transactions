access(all) struct CancelOfferMetadata {
	access(all) let offerId: UInt64
	init(offerId: UInt64) {
		self.offerId = offerId
	}
}

access(all) fun main(offerId: UInt64): CancelOfferMetadata {
		return CancelOfferMetadata(offerId: offerId)
}
