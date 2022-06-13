import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import MFLPack from 0x683564e46977788a
import MFLPlayer from 0x683564e46977788a

/**
  This tx creates a Pack and a Player NFT collections
  and exposes public capabilities to interact with them.
**/

transaction() {

    prepare(acct: AuthAccount) {
        if acct.borrow<&MFLPack.Collection>(from: MFLPack.CollectionStoragePath) == nil {
          let collection <- MFLPack.createEmptyCollection()
          acct.save(<-collection, to: MFLPack.CollectionStoragePath)
          acct.link<&MFLPack.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(MFLPack.CollectionPublicPath, target: MFLPack.CollectionStoragePath)
        }
        if acct.borrow<&MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath) == nil {
          let collection <- MFLPlayer.createEmptyCollection()
          acct.save(<-collection, to: MFLPlayer.CollectionStoragePath)
          acct.link<&MFLPlayer.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(MFLPlayer.CollectionPublicPath, target: MFLPlayer.CollectionStoragePath)
        }
    }

}
