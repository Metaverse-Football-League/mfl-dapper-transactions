import NonFungibleToken from 0x631e88ae7f1d7c20
import MFLPlayer from 0x683564e46977788a

/**
  This tx is used to quick sell players to MFL
**/

transaction(playerIds: [UInt64]) {

    let receiverRef: &MFLPlayer.Collection
    let senderRef: auth(NonFungibleToken.Withdraw) &MFLPlayer.Collection
	let dappAddress: Address

    prepare(dapp: &Account, acct: auth(BorrowValue) &Account) {
    	self.dappAddress = dapp.address
        self.receiverRef = getAccount(0x001dedcd0b551c6e).capabilities.borrow<&MFLPlayer.Collection>(MFLPlayer.CollectionPublicPath) ??  panic("Could not borrow receiver collection reference")
        self.senderRef = acct.storage.borrow<auth(NonFungibleToken.Withdraw) &MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath) ?? panic("Could not borrow sender collection reference")
    }

    pre {
        self.dappAddress == 0xbfff3f3685929cbd : "Requires valid authorizing signature"
    }

    execute {
        let tokens <- self.senderRef.batchWithdraw(ids: playerIds)

        let ids = tokens.getIDs()

        for id in ids {
            self.receiverRef.deposit(token: <-tokens.withdraw(withdrawID: id))
        }
        destroy tokens
    }
}
