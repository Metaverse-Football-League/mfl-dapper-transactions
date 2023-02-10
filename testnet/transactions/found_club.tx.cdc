import MFLClub from 0x683564e46977788a

/**
  This tx transforms a club licence into a club and
  set a name and a description.
**/

transaction(clubID: UInt64, name: String, description: String) {
    let clubCollectionRef: &MFLClub.Collection
    let dappAddress: Address

    prepare(dapp: AuthAccount, userAcct: AuthAccount) {
        self.dappAddress = dapp.address
        self.clubCollectionRef = userAcct.borrow<&MFLClub.Collection>(from: MFLClub.CollectionStoragePath) ?? panic("Could not borrow club collection reference")
    }

    // Make sure dapp is actually the dapp and not some random account
    pre {
        self.dappAddress == 0xb43424f512a3e937 : "Requires valid authorizing signature"
    }

    execute {
        self.clubCollectionRef.foundClub(id: clubID, name: name, description: description)
    }
}
