import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x683564e46977788a
import MFLPlayer from 0x683564e46977788a

/** 
  This tx creates a Player NFT collection
  and exposes a public capability to interact with it. 
**/

transaction() {

    prepare(acct: AuthAccount) {
        if acct.borrow<&MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath) == nil {
          let collection <- MFLPlayer.createEmptyCollection()
          acct.save(<-collection, to: MFLPlayer.CollectionStoragePath)
          acct.link<&MFLPlayer.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(MFLPlayer.CollectionPublicPath, target: MFLPlayer.CollectionStoragePath)
        }
    }
    
}
