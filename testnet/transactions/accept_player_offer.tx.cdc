import NonFungibleToken from 0x631e88ae7f1d7c20
import FungibleToken from 0x9a0766d93b6608b7
import OffersV2 from 0x8a5f647e58dde1ee
import DapperOffersV2 from 0x8a5f647e58dde1ee
import MetadataViews from 0x631e88ae7f1d7c20
import MFLPlayer from 0x683564e46977788a
import DapperUtilityCoin from 0x82ec283f88a62e65

transaction(nftID: UInt64, offerId: UInt64, dapperOfferAddress: Address) {
    let dapperOffer: &DapperOffersV2.DapperOffer
    let offer: &{OffersV2.OfferPublic}
    let receiverCapability: Capability<&{FungibleToken.Receiver}>
	let dappAddress: Address

    prepare(dapp: &Account, signer: auth(Storage) &Account) {
    	self.dappAddress = dapp.address

        // Get the DapperOffers resource
        self.dapperOffer = getAccount(dapperOfferAddress).capabilities.get<&DapperOffersV2.DapperOffer>(DapperOffersV2.DapperOffersPublicPath).borrow()
            ?? panic("Could not borrow DapperOffer from provided address")
        // Set the fungible token receiver capabillity
        self.receiverCapability = signer.capabilities.get<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
        assert(self.receiverCapability.borrow() != nil, message: "Missing or mis-typed DapperUtilityCoin receiver")

        // Get the NFT resource and withdraw the NFT from the signers account
        let nftCollection = signer.storage.borrow<auth(NonFungibleToken.Withdraw) &MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath)
            ?? panic("Cannot borrow NFT collection receiver from account")
		let nft <- (nftCollection.withdraw(withdrawID: nftID) as! @AnyResource) as! @{NonFungibleToken.NFT}

        // Get the DapperOffer details
        self.offer = self.dapperOffer.borrowOffer(offerId: offerId)
            ?? panic("No Offer with that ID in DapperOffer")
		let details = self.offer.getDetails()

        self.offer.accept(
            item: <-nft,
            receiverCapability: self.receiverCapability
        )
    }

    pre {
        self.dappAddress == 0xbfff3f3685929cbd : "Requires valid authorizing signature"
    }

    execute {
        // delete the offer
        self.dapperOffer.cleanup(offerId: offerId)
    }
}
