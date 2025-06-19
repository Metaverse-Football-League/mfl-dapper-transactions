import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import OffersV2 from 0xb8ea91944fd51c43
import DapperOffersV2 from 0xb8ea91944fd51c43
import DapperUtilityCoin from 0xead892083b3e2c6c
import MFLPlayer from 0x8ebcbfd516b1da27
import MFLOffersResolver from 0x8ebcbfd516b1da27
import Resolver from 0xb8ea91944fd51c43

transaction(
    amount: UFix64,
    royalties: {Address: UFix64},
    playerId: UInt64,
    expiry: UInt64,
) {
	var nftReceiver: Capability<&MFLPlayer.Collection>
	let dapperOffer: auth(DapperOffersV2.Manager) &DapperOffersV2.DapperOffer
	let ducVaultRef: Capability<auth(FungibleToken.Withdraw) &DapperUtilityCoin.Vault>
	let resolverCapability: Capability<&{Resolver.ResolverPublic}>
	let tokenAdminCollection: Capability<auth(DapperOffersV2.ProxyManager) &DapperOffersV2.DapperOffer>
	let dappAddress: Address

    prepare(dapp: auth(Storage, Capabilities) &Account, signer: auth(Storage, Capabilities) &Account, dapper: auth(Storage, Capabilities) &Account) {
    	self.dappAddress = dapp.address

		if signer.storage.borrow<&MFLPlayer.Collection>(from: MFLPlayer.CollectionStoragePath) == nil {
			let collection <- MFLPlayer.createEmptyCollection(nftType: Type<@MFLPlayer.NFT>())
			signer.storage.save(<-collection, to: MFLPlayer.CollectionStoragePath)
		}

        self.nftReceiver = signer.capabilities.get<&MFLPlayer.Collection>(MFLPlayer.CollectionPublicPath)
		if !self.nftReceiver.check() {
			signer.capabilities.unpublish(MFLPlayer.CollectionPublicPath)
			let collectionCap = signer.capabilities.storage.issue<&MFLPlayer.Collection>(MFLPlayer.CollectionStoragePath)
			signer.capabilities.publish(collectionCap, at: MFLPlayer.CollectionPublicPath)
			self.nftReceiver = signer.capabilities.get<&MFLPlayer.Collection>(MFLPlayer.CollectionPublicPath)
        }

        let dapperOfferType = Type<@DapperOffersV2.DapperOffer>()

        // Link the DapperOffer resource
        if signer.storage.borrow<&DapperOffersV2.DapperOffer>(from: DapperOffersV2.DapperOffersStoragePath) == nil {
            let dapperOffer <- DapperOffersV2.createDapperOffer()
            signer.storage.save(<-dapperOffer, to: DapperOffersV2.DapperOffersStoragePath)
            signer.capabilities.publish(
                signer.capabilities.storage.issue<&{DapperOffersV2.DapperOfferPublic}>(DapperOffersV2.DapperOffersStoragePath),
                at: DapperOffersV2.DapperOffersPublicPath
            )

            let managerStoragePath = /storage/mflDapperOfferManager
            let cap = signer.storage.copy<Capability<auth(DapperOffersV2.Manager) &{DapperOffersV2.DapperOfferManager}>>(from: managerStoragePath)
            if cap?.check() != true {
                let managerCap = signer.capabilities.storage.issue<auth(DapperOffersV2.Manager) &{DapperOffersV2.DapperOfferManager}>(DapperOffersV2.DapperOffersStoragePath)
                signer.storage.save(managerCap, to: managerStoragePath)
            }
        }

        // DapperOfferProxyManager Setup
		let proxyStoragePath = /storage/mflDapperOfferProxy
		let copiedProxy = signer.storage.copy<Capability<auth(DapperOffersV2.ProxyManager) &DapperOffersV2.DapperOffer>>(from: proxyStoragePath)
		if copiedProxy?.check() == true {
		   self.tokenAdminCollection = copiedProxy!
		} else {
		   self.tokenAdminCollection = signer.capabilities.storage.issue<auth(DapperOffersV2.ProxyManager) &DapperOffersV2.DapperOffer>(DapperOffersV2.DapperOffersStoragePath)
		   signer.storage.load<AnyStruct>(from: proxyStoragePath)
		   signer.storage.save(self.tokenAdminCollection, to: proxyStoragePath)
		}

        // Setup Proxy Cancel for Dapper
        let capabilityReceiver = dapper.capabilities.get<&{DapperOffersV2.DapperOfferPublic}>(/public/DapperOffersV2).borrow()
            ?? panic("Could not borrow capability receiver reference")
        capabilityReceiver.addProxyCapability(account: signer.address, cap: self.tokenAdminCollection)

        // Setup Proxy Cancel for MFL
        let mflCapabilityReceiver = dapp.capabilities.get<&{DapperOffersV2.DapperOfferPublic}>(/public/DapperOffersV2).borrow()
            ?? panic("Could not borrow MFL capability receiver reference")
        mflCapabilityReceiver.addProxyCapability(account: signer.address, cap: self.tokenAdminCollection)

        // Get the capability to the offer creators NFT collection
        self.nftReceiver = signer.capabilities.get<&MFLPlayer.Collection>(MFLPlayer.CollectionPublicPath)
        assert(self.nftReceiver.check(), message: "Missing or mis-typed collection receiver")

        self.dapperOffer = signer.storage.borrow<auth(DapperOffersV2.Manager) &DapperOffersV2.DapperOffer>(from: DapperOffersV2.DapperOffersStoragePath)
            ?? panic("Missing or mis-typed DapperOffersV2.DapperOffer")


        // Get the capability to the DUC vault
		let ducCapStoragePath = /storage/mflDucProvider
		let copiedDucProvider = dapper.storage.copy<Capability<auth(FungibleToken.Withdraw) &DapperUtilityCoin.Vault>>(from: ducCapStoragePath)
		if copiedDucProvider?.check() == true {
  			self.ducVaultRef = copiedDucProvider!
		} else {
  			self.ducVaultRef = dapper.capabilities.storage.issue<auth(FungibleToken.Withdraw) &DapperUtilityCoin.Vault>(/storage/dapperUtilityCoinVault)
  			dapper.storage.save(self.ducVaultRef, to: ducCapStoragePath)
		}

        assert(self.ducVaultRef.check() != nil, message: "Missing or mis-typed DapperUtilityCoin provider")

        self.resolverCapability = MFLOffersResolver.getResolverCap()
    }

    pre {
        self.dappAddress == 0x15e71a9f7fe7d53d : "Requires valid authorizing signature"
    }

    execute {
        var royaltysList: [OffersV2.Royalty] = []
        for k in royalties.keys {
            royaltysList.append(OffersV2.Royalty(
                receiver: getAccount(k).capabilities.get<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver),
                amount: royalties[k]!
            ))
        }

        let typeId = "A.8ebcbfd516b1da27.MFLPlayer.NFT"

		let offerParamsString: {String: String} = {}
        offerParamsString.insert(key: "resolver", "0")
        offerParamsString.insert(key: "nftId", playerId.toString())
        offerParamsString.insert(key: "_type", "NFT")
        offerParamsString.insert(key: "typeId", typeId)
        offerParamsString.insert(key: "marketplace", "MFL")

        let offerParamsUInt64: {String: UInt64} = { "expiry": expiry }

        self.dapperOffer.createOffer(
            vaultRefCapability: self.ducVaultRef,
            nftReceiverCapability: self.nftReceiver,
            nftType: CompositeType(typeId)!,
            amount: amount,
            royalties: royaltysList,
            offerParamsString: offerParamsString,
            offerParamsUFix64: {},
            offerParamsUInt64: offerParamsUInt64,
            resolverCapability: self.resolverCapability
        )
    }
}
