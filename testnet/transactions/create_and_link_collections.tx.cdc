import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import MFLPack from 0x683564e46977788a
import MFLPlayer from 0x683564e46977788a
import MFLClub from 0x683564e46977788a

/**
  This tx creates all the collections needed for MFL
  and exposes public capabilities to interact with them.
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

        if acct.storage.borrow<&MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath) == nil {
            let collection <- MFLPlayer.createEmptyCollection(nftType: Type<@MFLPlayer.NFT>())
            acct.storage.save(<-collection, to: MFLPlayer.CollectionStoragePath)

            acct.capabilities.unpublish(MFLPlayer.CollectionPublicPath)
            let collectionCap = acct.capabilities.storage.issue<&MFLPlayer.Collection>(MFLPlayer.CollectionStoragePath)
            acct.capabilities.publish(collectionCap, at: MFLPlayer.CollectionPublicPath)
        }

        if acct.storage.borrow<&MFLClub.Collection>(from: MFLClub.CollectionStoragePath) == nil {
            let collection <- MFLClub.createEmptyCollection(nftType: Type<@MFLClub.NFT>())
            acct.storage.save(<-collection, to: MFLClub.CollectionStoragePath)

            acct.capabilities.unpublish(MFLClub.CollectionPublicPath)
            let collectionCap = acct.capabilities.storage.issue<&MFLClub.Collection>(MFLClub.CollectionStoragePath)
            acct.capabilities.publish(collectionCap, at: MFLClub.CollectionPublicPath)
        }
    }

}
