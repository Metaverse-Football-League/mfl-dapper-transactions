import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import MFLPack from 0x8ebcbfd516b1da27
import MFLPlayer from 0x8ebcbfd516b1da27
import MFLClub from 0x8ebcbfd516b1da27

/**
  This tx creates all the collections needed for MFL
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
        if acct.borrow<&MFLClub.Collection>(from: MFLClub.CollectionStoragePath) == nil {
          let collection <- MFLClub.createEmptyCollection()
          acct.save(<-collection, to: MFLClub.CollectionStoragePath)
          acct.link<&MFLClub.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(MFLClub.CollectionPublicPath, target: MFLClub.CollectionStoragePath)
        }
    }

}
