import DapperOffersV2 from 0xb8ea91944fd51c43

transaction(offerId: UInt64) {
    let dapperOffer: auth(DapperOffersV2.Manager) &DapperOffersV2.DapperOffer

    prepare(acct: auth(Storage, Capabilities) &Account) {
        self.dapperOffer = acct.storage.borrow<auth(DapperOffersV2.Manager) &DapperOffersV2.DapperOffer>(from: DapperOffersV2.DapperOffersStoragePath)
            ?? panic("Missing or mis-typed DapperOffer")
    }

    execute {
        self.dapperOffer.removeOffer(offerId: offerId)
    }
}
