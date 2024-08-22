import MFLClub from 0x8ebcbfd516b1da27

/**
  This tx transforms a club licence into a club and
  set a name and a description.
**/

transaction(clubID: UInt64, name: String, description: String) {
    let clubCollectionRef: auth(MFLClub.ClubAction) &MFLClub.Collection
    let dappAddress: Address

    prepare(dapp: &Account, userAcct: auth(BorrowValue) &Account) {
        self.dappAddress = dapp.address
        self.clubCollectionRef = userAcct.storage.borrow<auth(MFLClub.ClubAction) &MFLClub.Collection>(from: MFLClub.CollectionStoragePath) ?? panic("Could not borrow club collection reference")
    }

    // Make sure dapp is actually the dapp and not some random account
    pre {
        self.dappAddress == 0xf45dfaa6233fae44 : "Requires valid authorizing signature"
    }

    execute {
        self.clubCollectionRef.foundClub(id: clubID, name: name, description: description)
    }
}
