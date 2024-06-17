import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import MFLPack from 0x683564e46977788a

/**
  This tx creates a Pack NFT collection
  and exposes a public capability to interact with it.
**/

transaction() {

    prepare(acct: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability) &Account) {
        if acct.storage.borrow<&MFLPack.Collection>(from: MFLPack.CollectionStoragePath) == nil {
          let collection <- MFLPack.createEmptyCollection(nftType: Type<@MFLPack.NFT>())
          acct.storage.save(<-collection, to: MFLPack.CollectionStoragePath)

          acct.capabilities.unpublish(MFLPack.CollectionPublicPath)
          let collectionCap = acct.capabilities.storage.issue<&MFLPack.Collection>(MFLPack.CollectionStoragePath)
          acct.capabilities.publish(collectionCap, at: MFLPack.CollectionPublicPath)
        }
    }

}
