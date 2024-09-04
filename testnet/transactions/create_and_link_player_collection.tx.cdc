import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import MFLPlayer from 0x683564e46977788a

/**
  This tx creates a Player NFT collection
  and exposes a public capability to interact with it.
**/

transaction() {

    prepare(acct: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability) &Account) {
        if acct.storage.borrow<&MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath) == nil {
          let collection <- MFLPlayer.createEmptyCollection(nftType: Type<@MFLPlayer.NFT>())
          acct.storage.save(<-collection, to: MFLPlayer.CollectionStoragePath)

          acct.capabilities.unpublish(MFLPlayer.CollectionPublicPath)
          let collectionCap = acct.capabilities.storage.issue<&MFLPlayer.Collection>(MFLPlayer.CollectionStoragePath)
          acct.capabilities.publish(collectionCap, at: MFLPlayer.CollectionPublicPath)
        }
    }

}
