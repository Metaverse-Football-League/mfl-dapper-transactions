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
    let collectionRef: &MFLPack.Collection

    prepare(owner: AuthAccount) {
        self.collectionRef = owner.borrow<&MFLPack.Collection>(from: MFLPack.CollectionStoragePath)!
        if !owner.getCapability<&MFLPlayer.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(MFLPlayer.CollectionPublicPath).check() {
            if owner.borrow<&MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath) == nil {
                owner.save(<- MFLPlayer.createEmptyCollection(), to: MFLPlayer.CollectionStoragePath)
            }
            owner.unlink(MFLPlayer.CollectionPublicPath)
            owner.link<&MFLPlayer.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(MFLPlayer.CollectionPublicPath, target: MFLPlayer.CollectionStoragePath)
        }
        if !owner.getCapability<&MFLClub.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(MFLPlayer.CollectionPublicPath).check() {
            if owner.borrow<&MFLClub.Collection>(from: MFLClub.CollectionStoragePath) == nil {
                owner.save(<- MFLClub.createEmptyCollection(), to: MFLClub.CollectionStoragePath)
            }
            owner.unlink(MFLClub.CollectionPublicPath)
            owner.link<&MFLClub.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(MFLClub.CollectionPublicPath, target: MFLClub.CollectionStoragePath)
        }
    }

    execute {
        self.collectionRef.openPack(id: revealID)
    }
}
