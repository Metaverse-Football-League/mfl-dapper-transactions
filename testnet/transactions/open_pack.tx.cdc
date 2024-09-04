import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import MFLPack from 0x683564e46977788a
import MFLPlayer from 0x683564e46977788a
import MFLClub from 0x683564e46977788a

/**
  This tx opens a pack, this will burn it and emit an event catched by the MFL backend to distribute the pack content.
  This will also create a player Collection (if the account doesn't have one).
 **/

 transaction(revealID: UInt64) {
    let collectionRef: auth(MFLPack.PackAction) &MFLPack.Collection

    prepare(owner: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, UnpublishCapability) &Account) {
        self.collectionRef = owner.storage.borrow<auth(MFLPack.PackAction) &MFLPack.Collection>(from: MFLPack.CollectionStoragePath)!
        
        if owner.capabilities.borrow<&MFLPlayer.Collection>(MFLPlayer.CollectionPublicPath) == nil {
            if owner.storage.borrow<&MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath) == nil {
                owner.storage.save(<- MFLPlayer.createEmptyCollection(nftType: Type<@MFLPlayer.NFT>()), to: MFLPlayer.CollectionStoragePath)
            }

            owner.capabilities.unpublish(MFLPlayer.CollectionPublicPath)
            let playerCollectionCap = owner.capabilities.storage.issue<&MFLPlayer.Collection>(MFLPlayer.CollectionStoragePath)
            owner.capabilities.publish(playerCollectionCap, at: MFLPlayer.CollectionPublicPath)
        }

        if owner.capabilities.borrow<&MFLClub.Collection>(MFLClub.CollectionPublicPath) == nil {
            if owner.storage.borrow<&MFLClub.Collection>(from: MFLClub.CollectionStoragePath) == nil {
                owner.storage.save(<- MFLClub.createEmptyCollection(nftType: Type<@MFLClub.NFT>()), to: MFLClub.CollectionStoragePath)
            }

            owner.capabilities.unpublish(MFLClub.CollectionPublicPath)
            let playerCollectionCap = owner.capabilities.storage.issue<&MFLClub.Collection>(MFLClub.CollectionStoragePath)
            owner.capabilities.publish(playerCollectionCap, at: MFLClub.CollectionPublicPath)
        }
    }

    execute {
        self.collectionRef.openPack(id: revealID)
    }
}
