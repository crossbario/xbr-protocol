///////////////////////////////////////////////////////////////////////////////
//
//  Copyright (C) 2018-2020 Crossbar.io Technologies GmbH and contributors.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
///////////////////////////////////////////////////////////////////////////////

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

// https://openzeppelin.org/api/docs/math_SafeMath.html
// import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./XBRMaintained.sol";
import "./XBRTypes.sol";
import "./XBRNetwork.sol";
import "./XBRCatalog.sol";


/**
 * The `XBR Market <https://github.com/crossbario/xbr-protocol/blob/master/contracts/XBRMarket.sol>`__
 * contract manages XBR data markets and serves as an anchor for all payment and paying channels for
 * each respective market.
 */
contract XBRMarket is Initializable {

    // Add safe math functions to uint256 using SafeMath lib from OpenZeppelin
    using SafeMath for uint256;

    /// Event emitted when a new market was created.
    event MarketCreated (bytes16 indexed marketId, uint created, uint32 marketSeq, address owner, address coin, string terms,
        string meta, address maker, uint256 providerSecurity, uint256 consumerSecurity, uint256 marketFee);

    /// Event emitted when a market was updated.
    event MarketUpdated (bytes16 indexed marketId, uint32 marketSeq, address owner, address coin, string terms, string meta,
        address maker, uint256 providerSecurity, uint256 consumerSecurity, uint256 marketFee);

    /// Event emitted when a market was closed.
    event MarketClosed (bytes16 indexed marketId);

    /// Event emitted when a new actor joined a market.
    event ActorJoined (bytes16 indexed marketId, address actor, uint8 actorType, uint256 joined,
        uint256 security, string meta);

    /// Event emitted when an actor has left a market.
    event ActorLeft (bytes16 indexed marketId, address actor, uint8 actorType, uint256 left, uint256 securitiesToBeRefunded);

    /// Event emitted when an actor has set consent on a ``(market, delegate, api)`` triple.
    event ConsentSet (address member, uint256 updated, bytes16 marketId, address delegate,
        uint8 delegateType, bytes16 apiCatalog, bool consent, string servicePrefix);

    /// Channel closing timeout in number of blocks for closing a channel non-cooperatively.
    uint256 public NONCOOPERATIVE_CHANNEL_CLOSE_TIMEOUT;

    /// Instance of XBRNetwork contract this contract is linked to.
    XBRNetwork public network;

    /// Instance of XBRCatalog contract this contract is linked to.
    XBRCatalog public catalog;

    /// Created markets are sequence numbered using this counter (to allow deterministic collision-free IDs for markets)
    uint32 public marketSeq;

    /// Current XBR Markets ("market directory")
    mapping(bytes16 => XBRTypes.Market) public markets;

    /// List of IDs of current XBR Markets.
    bytes16[] public marketIds;

    /// Index: maker address => market ID
    mapping(address => bytes16) public marketsByMaker;

    /// Index: market owner address => [market ID]
    mapping(address => bytes16[]) public marketsByOwner;

    /// Index: market actor address => [market ID]
    mapping(address => bytes16[]) public marketsByActor;

    /// Network level (global) stats for an XBR network member.
    mapping(address => XBRTypes.MemberMarketStats) public memberStats;

    // Constructor for this contract, only called once (when deploying the network).
    //
    // @param networkAdr The XBR network contract this instance is associated with.
    function initialize (address networkAdr, address catalogAdr) public initializer {
        NONCOOPERATIVE_CHANNEL_CLOSE_TIMEOUT = 1440;
        marketSeq = 1;

        network = XBRNetwork(networkAdr);
        catalog = XBRCatalog(catalogAdr);
    }

    /// Create a new XBR market. The sender of the transaction must be XBR network member
    /// and automatically becomes owner of the new market.
    ///
    /// @param marketId The ID of the market to create. Must be unique (not yet existing).
    /// @param coin The ERC20 coin to be used as the means of payment in the market.
    /// @param terms Multihash for market terms set by the market owner.
    /// @param meta Multihash for optional market metadata.
    /// @param maker The address of the XBR market maker that will run this market. The delegate of the market owner.
    /// @param providerSecurity The amount of coins a XBR provider joining the market must deposit.
    /// @param consumerSecurity The amount of coins a XBR consumer joining the market must deposit.
    /// @param marketFee The fee taken by the market (beneficiary is the market owner). The fee is a percentage of
    ///                  the revenue of the XBR Provider that receives coins paid for transactions.
    ///                  The fee must be between 0% (inclusive) and 100% (inclusive), and is expressed as
    ///                  a fraction of the total supply of coins in the ERC20 token specified for the market.
    function createMarket (bytes16 marketId, address coin, string memory terms, string memory meta, address maker,
        uint256 providerSecurity, uint256 consumerSecurity, uint256 marketFee) public {

        _createMarket(msg.sender, block.number, marketId, coin, terms, meta, maker,
            providerSecurity, consumerSecurity, marketFee, "");
    }

    /// Create a new XBR market for a member. The member must be XBR network member, must have signed the
    /// transaction data, and will become owner of the new market.
    ///
    /// Note: This version uses pre-signed data where the actual blockchain transaction is
    /// submitted by a gateway paying the respective gas (in ETH) for the blockchain transaction.
    ///
    /// @param member The member that creates the market (will become market owner).
    /// @param created Block number when the market was created.
    /// @param marketId The ID of the market to create. Must be unique (not yet existing).
    /// @param coin The ERC20 coin to be used as the means of payment in the market.
    /// @param terms Multihash for market terms set by the market owner.
    /// @param meta Multihash for optional market metadata.
    /// @param maker The address of the XBR market maker that will run this market. The delegate of the market owner.
    /// @param providerSecurity The amount of coins a XBR provider joining the market must deposit.
    /// @param consumerSecurity The amount of coins a XBR consumer joining the market must deposit.
    /// @param marketFee The fee taken by the market (beneficiary is the market owner). The fee is a percentage of
    ///                  the revenue of the XBR Provider that receives coins paid for transactions.
    ///                  The fee must be between 0% (inclusive) and 100% (inclusive), and is expressed as
    ///                  a fraction of the total supply of coins in the ERC20 token specified for the market.
    /// @param signature EIP712 signature created by the member.
    function createMarketFor (address member, uint256 created, bytes16 marketId, address coin,
        string memory terms, string memory meta, address maker, uint256 providerSecurity, uint256 consumerSecurity,
        uint256 marketFee, bytes memory signature) public {

        require(XBRTypes.verify(member, XBRTypes.EIP712MarketCreate(network.verifyingChain(), network.verifyingContract(),
            member, created, marketId, coin, terms, meta, maker, marketFee), signature),
            "INVALID_MARKET_CREATE_SIGNATURE");

        // signature must have been created in a window of PRESIGNED_TXN_MAX_AGE blocks from the current one
        require(created <= block.number && (block.number <= network.PRESIGNED_TXN_MAX_AGE() ||
            created >= (block.number - network.PRESIGNED_TXN_MAX_AGE())), "INVALID_CREATED_BLOCK_NUMBER");

        _createMarket(member, created, marketId, coin, terms, meta, maker,
            providerSecurity, consumerSecurity, marketFee, signature);
    }

    function _createMarket (address member, uint256 created, bytes16 marketId, address coin, string memory terms,
        string memory meta, address maker, uint256 providerSecurity, uint256 consumerSecurity, uint256 marketFee,
        bytes memory signature) private {

        (, , , XBRTypes.MemberLevel member_level, ) = network.members(member);

        // the market operator (owner) must be a registered member
        require(member_level == XBRTypes.MemberLevel.ACTIVE ||
                member_level == XBRTypes.MemberLevel.VERIFIED, "SENDER_NOT_A_MEMBER");

        // market must not yet exist (to generate a new marketId: )
        require(markets[marketId].owner == address(0), "MARKET_ALREADY_EXISTS");

        // the market operator (owning member) must be specifically allowed to use the given coin, or the coin
        // must be allowed to be used in new markets by any member (eg DAI)
        require(network.coins(coin, member) == true || network.coins(coin, network.ANYADR()) == true, "INVALID_COIN");

        // must provide a valid market maker address already when creating a market
        require(maker != address(0), "INVALID_MAKER");

        // the market maker can only work for one market
        require(marketsByMaker[maker] == bytes16(0), "MAKER_ALREADY_WORKING_FOR_OTHER_MARKET");

        // provider security must be non-negative (and not larger than the total token supply)
        require(providerSecurity >= 0 && providerSecurity <= IERC20(coin).totalSupply(), "INVALID_PROVIDER_SECURITY");

        // consumer security must be non-negative (and not larger than the total token supply)
        require(consumerSecurity >= 0 && consumerSecurity <= IERC20(coin).totalSupply(), "INVALID_CONSUMER_SECURITY");

        // market operator fee: [0%, 100%] <-> [0, coin.totalSupply]
        require(marketFee >= 0 && marketFee <= IERC20(coin).totalSupply(), "INVALID_MARKET_FEE");

        // now remember out new market ..
        markets[marketId] = XBRTypes.Market(created, marketSeq, member, coin, terms, meta, maker,
            providerSecurity, consumerSecurity, marketFee, signature, new address[](0), new address[](0));

        // .. and the market-maker-to-market mapping
        marketsByMaker[maker] = marketId;

        // .. and the market-owner-to-market mapping
        marketsByOwner[member].push(marketId);

        // .. and list of market IDs
        marketIds.push(marketId);

        // .. and the member network-level stats
        memberStats[member].marketsOwned += 1;

        // increment market sequence for next market
        marketSeq = marketSeq + 1;

        // notify observers (eg a dormant market maker waiting to be associated)
        emit MarketCreated(marketId, created, marketSeq, member, coin, terms, meta, maker,
            providerSecurity, consumerSecurity, marketFee);
    }

    // function closeMarket (bytes16 marketId) public {
    //     // the market must exist
    //     require(markets[marketId].owner != address(0), "NO_SUCH_MARKET");

    //     // the market must be owner by the sender
    //     require(markets[marketId].owner == msg.sender, "SENDER_NOT_OWNER");

    //     require(false, "NOT_IMPLEMENTED");
    // }

    /// Join the given XBR market as the specified type of actor, which must be PROVIDER or CONSUMER.
    ///
    /// @param marketId The ID of the XBR data market to join.
    /// @param actorType The type of actor under which to join: PROVIDER or CONSUMER.
    /// @param meta The XBR market provider/consumer metadata. IPFS Multihash pointing to a JSON file with metadata.
    function joinMarket (bytes16 marketId, uint8 actorType, string memory meta) public returns (uint256) {

        return _joinMarket(msg.sender, block.number, marketId, actorType, meta, "");
    }

    /// Join the specified member to the given XBR market as the specified type of actor,
    /// which must be PROVIDER or CONSUMER.
    ///
    /// Note: This version uses pre-signed data where the actual blockchain transaction is
    /// submitted by a gateway paying the respective gas (in ETH) for the blockchain transaction.
    ///
    /// @param member The member that creates the market (will become market owner).
    /// @param joined Block number when the member joined the market.
    /// @param marketId The ID of the XBR data market to join.
    /// @param actorType The type of actor under which to join: PROVIDER or CONSUMER.
    /// @param meta The XBR market provider/consumer metadata. IPFS Multihash pointing to a JSON file with metadata.
    /// @param signature EIP712 signature created by the member.
    function joinMarketFor (address member, uint256 joined, bytes16 marketId, uint8 actorType,
        string memory meta, bytes memory signature) public returns (uint256) {

        require(XBRTypes.verify(member, XBRTypes.EIP712MarketJoin(network.verifyingChain(), network.verifyingContract(),
            member, joined, marketId, actorType, meta), signature), "INVALID_MARKET_JOIN_SIGNATURE");

        // signature must have been created in a window of PRESIGNED_TXN_MAX_AGE blocks from the current one
        require(joined <= block.number && (block.number <= network.PRESIGNED_TXN_MAX_AGE() ||
            joined >= (block.number - network.PRESIGNED_TXN_MAX_AGE())), "INVALID_REGISTERED_BLOCK_NUMBER");

        return _joinMarket(member, joined, marketId, actorType, meta, signature);
    }

    function _joinMarket (address member, uint256 joined, bytes16 marketId, uint8 actorType,
        string memory meta, bytes memory signature) private returns (uint256) {

        (, , , XBRTypes.MemberLevel member_level, ) = network.members(member);

        // the joining sender must be a registered member
        require(member_level == XBRTypes.MemberLevel.ACTIVE, "SENDER_NOT_A_MEMBER");

        // the market to join must exist
        require(markets[marketId].owner != address(0), "NO_SUCH_MARKET");

        // the market owner cannot join as an actor (provider/consumer) in the market
        require(markets[marketId].owner != member, "SENDER_IS_OWNER");

        // the joining member must join as a data provider (seller) or data consumer (buyer)
        require(actorType == uint8(XBRTypes.ActorType.PROVIDER) ||
                actorType == uint8(XBRTypes.ActorType.CONSUMER) ||
                actorType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER), "INVALID_ACTOR_TYPE");

        // get the security amount required for joining the market (if any)
        uint256 security = 0;
        if (actorType == uint8(XBRTypes.ActorType.PROVIDER) || actorType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER)) {
            // the joining member must not be joined as a provider already
            require(uint8(markets[marketId].providerActors[member].joined) == 0, "ALREADY_JOINED_AS_PROVIDER");
            security += markets[marketId].providerSecurity;
        }

        if (actorType == uint8(XBRTypes.ActorType.CONSUMER) || actorType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER)) {
            // the joining member must not be joined as a consumer already
            require(uint8(markets[marketId].consumerActors[member].joined) == 0, "ALREADY_JOINED_AS_CONSUMER");
            security += markets[marketId].consumerSecurity;
        }

        // transfer (if any) security to the market owner (for ActorType.CONSUMER or ActorType.PROVIDER)
        if (security > 0) {
            // https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#IERC20
            bool success = IERC20(markets[marketId].coin).transferFrom(member, markets[marketId].owner, security);
            require(success, "JOIN_MARKET_TRANSFER_FROM_FAILED");
        }

        // remember actor (by actor address) within market
        if (actorType == uint8(XBRTypes.ActorType.PROVIDER) || actorType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER)) {
            markets[marketId].providerActors[member] = XBRTypes.Actor(joined, markets[marketId].providerSecurity, meta,
                signature, XBRTypes.ActorState.JOINED, new address[](0));
            markets[marketId].providerActorAdrs.push(member);
        }

        if (actorType == uint8(XBRTypes.ActorType.CONSUMER) || actorType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER)) {
            markets[marketId].consumerActors[member] = XBRTypes.Actor(joined, markets[marketId].consumerSecurity, meta,
                signature, XBRTypes.ActorState.JOINED, new address[](0));
            markets[marketId].consumerActorAdrs.push(member);
        }

        // remember market joined for the actor. note: this list can contain dups, as a given actor might join as both buyer and seller
        // to the same market subsequently. an actor might also leave, and then rejoin a market. so this list should only be treated
        // as a non-unique covering index
        marketsByActor[member].push(marketId);

        // .. and the member network-level stats
        memberStats[member].marketsJoined += 1;
        memberStats[member].marketSecuritiesSent += security;

        // emit event ActorJoined(bytes16 marketId, address actor, ActorType actorType, uint joined,
        //                        uint256 security, string meta)
        emit ActorJoined(marketId, member, actorType, joined, security, meta);

        // return effective security transferred
        return security;
    }

    /// Leave the given XBR market as the specified type of actor.
    ///
    /// @param marketId The ID of the XBR data market to leave.
    /// @param actorType The type of actor under which to leave: PROVIDER or CONSUMER pr PROVIDER-CONSUMER.
    function leaveMarket (bytes16 marketId, uint8 actorType) public returns (uint256) {
        return _leaveMarket(msg.sender, block.number, marketId, actorType, "");
    }

    /// Leave the given XBR market as the specified type of actor.
    ///
    /// IMPORTANT: This version uses pre-signed data where the actual blockchain transaction is
    /// submitted by a gateway paying the respective gas (in ETH) for the blockchain transaction.
    ///
    /// @param member Address of member (which must be actor in the market) that is leaving the market.
    /// @param left Block number at which the member left the market.
    /// @param marketId The ID of the XBR data market to leave.
    /// @param actorType The type of actor under which to leave: PROVIDER or CONSUMER pr PROVIDER-CONSUMER.
    /// @param signature EIP712 signature, signed by the leaving actor.
    function leaveMarketFor (address member, uint256 left, bytes16 marketId, uint8 actorType, bytes memory signature) public returns (uint256) {

        require(XBRTypes.verify(member, XBRTypes.EIP712MarketLeave(network.verifyingChain(), network.verifyingContract(),
            member, left, marketId, actorType), signature), "INVALID_SIGNATURE");

        // signature must have been created in a window of PRESIGNED_TXN_MAX_AGE blocks from the current one
        require(left <= block.number && (block.number <= network.PRESIGNED_TXN_MAX_AGE() ||
            left >= (block.number - network.PRESIGNED_TXN_MAX_AGE())), "INVALID_BLOCK_NUMBER");

        return _leaveMarket(member, left, marketId, actorType, signature);
    }

    function _leaveMarket (address member, uint256 left, bytes16 marketId, uint8 actorType, bytes memory signature) public returns (uint256) {

        // workaround because I cannot find the fucking option to disable
        // the "Warning: Unused function parameter." shit
        require(signature.length >= 0);

        (, , , XBRTypes.MemberLevel member_level, ) = network.members(member);

        // the joining sender must be a registered member
        require(member_level == XBRTypes.MemberLevel.ACTIVE, "SENDER_NOT_A_MEMBER");

        // the market must exist
        require(markets[marketId].owner != address(0), "NO_SUCH_MARKET");

        // consent to the delegate acting as a data provider (seller) or data consumer (buyer)
        require(actorType == uint8(XBRTypes.ActorType.PROVIDER) ||
                actorType == uint8(XBRTypes.ActorType.CONSUMER) ||
                actorType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER), "INVALID_ACTOR_TYPE");

        uint256 securitiesToBeRefunded = 0;

        if (actorType == uint8(XBRTypes.ActorType.PROVIDER) || actorType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER)) {
            // the member must be a provider actor in the market
            require(uint8(markets[marketId].providerActors[member].joined) != 0, "MEMBER_NOT_PROVIDER");
            require(uint8(markets[marketId].providerActors[member].state) == uint8(XBRTypes.ActorState.JOINED), "PROVIDER_NOT_JOINED");

            if (markets[marketId].providerActors[member].security > 0) {
                // if the member provided a security when joining as a provider, note that, and set actor state "LEAVING"
                securitiesToBeRefunded += markets[marketId].providerActors[member].security;
                markets[marketId].providerActors[member].state = XBRTypes.ActorState.LEAVING;
            } else {
                // when the member did not provide a security, immediately remove the actor
                markets[marketId].providerActors[member] = XBRTypes.Actor(0, 0, "", "", XBRTypes.ActorState.NULL, new address[](0));
            }
        }

        if (actorType == uint8(XBRTypes.ActorType.CONSUMER) || actorType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER)) {
            // the member must be a consumer actor in the market
            require(uint8(markets[marketId].consumerActors[member].joined) != 0, "MEMBER_NOT_CONSUMER");
            require(uint8(markets[marketId].consumerActors[member].state) == uint8(XBRTypes.ActorState.JOINED), "CONSUMER_NOT_JOINED");

            if (markets[marketId].consumerActors[member].security > 0) {
                // if the member provided a security when joining as a provider, note that, and set actor state "LEAVING"
                securitiesToBeRefunded += markets[marketId].consumerActors[member].security;
                markets[marketId].consumerActors[member].state = XBRTypes.ActorState.LEAVING;
            } else {
                // when the member did not provide a security, immediately remove the actor
                markets[marketId].consumerActors[member] = XBRTypes.Actor(0, 0, "", "", XBRTypes.ActorState.NULL, new address[](0));
            }
        }

        emit ActorLeft(marketId, member, actorType, left, securitiesToBeRefunded);

        return securitiesToBeRefunded;
    }

    /// Track consent of an actor in a market to allow the specified seller or buyer delegate
    /// to provide or consume data under the respective API catalog in the given market.
    ///
    /// @param marketId The ID of the XBR data market in which to provide or consume data. Any
    ///                 terms attached to the market or the API apply.
    /// @param delegate The address of the off-chain provider or consumer delegate, which is a piece
    ///                 of software acting on behalf and under consent of the actor in the market.
    /// @param delegateType The type of off-chain delegate, a data provider or data consumer.
    /// @param apiCatalog The ID of the API or API catalog to which the consent shall apply.
    /// @param consent Consent granted or revoked.
    /// @param servicePrefix The WAMP URI prefix to be used by the delegate in the data plane realm.
    function setConsent (bytes16 marketId, address delegate, uint8 delegateType, bytes16 apiCatalog,
        bool consent, string memory servicePrefix) public {

        return _setConsent(msg.sender, block.number, marketId, delegate, delegateType,
            apiCatalog, consent, servicePrefix, "");
    }

    /// Track consent of an actor in a market to allow the specified seller or buyer delegate
    /// to provide or consume data under the respective API catalog in the given market.
    ///
    /// IMPORTANT: This version uses pre-signed data where the actual blockchain transaction is
    /// submitted by a gateway paying the respective gas (in ETH) for the blockchain transaction.
    ///
    /// @param member Address of member (which must be actor in the market) that sets consent.
    /// @param updated Block number at which the consent setting member has created the signature.
    /// @param marketId The ID of the XBR data market in which to provide or consume data. Any
    ///                 terms attached to the market or the API apply.
    /// @param delegate The address of the off-chain provider or consumer delegate, which is a piece
    ///                 of software acting on behalf and under consent of the actor in the market.
    /// @param delegateType The type of off-chain delegate, a data provider or data consumer.
    /// @param apiCatalog The ID of the API or API catalog to which the consent shall apply.
    /// @param consent Consent granted or revoked.
    /// @param servicePrefix The WAMP URI prefix to be used by the delegate in the data plane realm.
    /// @param signature EIP712 signature, signed by the consent setting member.
    function setConsentFor (address member, uint256 updated, bytes16 marketId, address delegate,
        uint8 delegateType, bytes16 apiCatalog, bool consent, string memory servicePrefix,
        bytes memory signature) public {

        require(XBRTypes.verify(member, XBRTypes.EIP712Consent(network.verifyingChain(), network.verifyingContract(),
            member, updated, marketId, delegate, delegateType, apiCatalog, consent, servicePrefix), signature),
            "INVALID_CONSENT_SIGNATURE");

        // signature must have been created in a window of PRESIGNED_TXN_MAX_AGE blocks from the current one
        require(updated <= block.number && (block.number <= network.PRESIGNED_TXN_MAX_AGE() ||
            updated >= (block.number - network.PRESIGNED_TXN_MAX_AGE())), "INVALID_CONSENT_BLOCK_NUMBER");

        return _setConsent(member, updated, marketId, delegate, delegateType,
            apiCatalog, consent, servicePrefix, signature);
    }

    function _setConsent (address member, uint256 updated, bytes16 marketId, address delegate,
        uint8 delegateType, bytes16 apiCatalog, bool consent, string memory servicePrefix,
        bytes memory signature) public {

        (, , , XBRTypes.MemberLevel member_level, ) = network.members(member);

        // the joining sender must be a registered member
        require(member_level == XBRTypes.MemberLevel.ACTIVE, "SENDER_NOT_A_MEMBER");

        // the market must exist
        require(markets[marketId].owner != address(0), "NO_SUCH_MARKET");

        // consent to the delegate acting as a data provider (seller) or data consumer (buyer)
        require(delegateType == uint8(XBRTypes.ActorType.PROVIDER) ||
                delegateType == uint8(XBRTypes.ActorType.CONSUMER) ||
                delegateType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER), "INVALID_ACTOR_TYPE");

        if (delegateType == uint8(XBRTypes.ActorType.PROVIDER) || delegateType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER)) {
            // the member must be a provider actor in the market
            require(uint8(markets[marketId].providerActors[member].joined) != 0, "MEMBER_NOT_PROVIDER");
        }

        if (delegateType == uint8(XBRTypes.ActorType.CONSUMER) || delegateType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER)) {
            // the member must be a consumer actor in the market
            require(uint8(markets[marketId].consumerActors[member].joined) != 0, "MEMBER_NOT_CONSUMER");
        }

        // must provide a valid delegate address, but the delegate doesn't need to be member!
        require(delegate != address(0), "INVALID_CHANNEL_DELEGATE");

        // the catalog must exist
        (uint256 catalogCreated, , , , , ) = catalog.catalogs(apiCatalog);
        require(catalogCreated != 0, "NO_SUCH_CATALOG");

        // must have a service prefix set
        require(keccak256(abi.encode(servicePrefix)) != keccak256(abi.encode("")), "SERVICE_PREFIX_EMPTY");

        // store consent status as provider delegate
        if (delegateType == uint8(XBRTypes.ActorType.PROVIDER) || delegateType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER)) {
            markets[marketId].providerActors[member].delegates[delegate][apiCatalog] = XBRTypes.Consent(
                updated, consent, servicePrefix, signature);
        }

        // store consent status as consumer delegate
        if (delegateType == uint8(XBRTypes.ActorType.CONSUMER) || delegateType == uint8(XBRTypes.ActorType.PROVIDER_CONSUMER)) {
            markets[marketId].consumerActors[member].delegates[delegate][apiCatalog] = XBRTypes.Consent(
                updated, consent, servicePrefix, signature);
        }

        // notify observers of changed consent status
        emit ConsentSet(member, updated, marketId, delegate, delegateType, apiCatalog, consent, servicePrefix);
    }

    /// Get the total number of markets defined.
    function countMarkets() public view returns (uint) {
        return marketIds.length;
    }

    /*
    // TypeError: Only libraries are allowed to use the mapping type in public or external functions.
    function getMarket(bytes16 marketId) public view returns (XBRTypes.Market memory) {
        return markets[marketId];
    }
    */

    /// Get the market owner for the given market.
    function getMarketOwner(bytes16 marketId) public view returns (address) {
        return markets[marketId].owner;
    }

    /// Get the coin ussed as a means of payment for the given market.
    function getMarketCoin(bytes16 marketId) public view returns (address) {
        return markets[marketId].coin;
    }

    /// Get the market fee set by the market operator that applies for the given market.
    function getMarketFee(bytes16 marketId) public view returns (uint256) {
        return markets[marketId].marketFee;
    }

    /// Get the market maker for the given market.
    function getMarketMaker(bytes16 marketId) public view returns (address) {
        return markets[marketId].maker;
    }

    /// Get the n-th market owned by the given member.
    function getMarketsByOwner(address owner, uint index) public view returns (bytes16) {
        return marketsByOwner[owner][index];
    }

    /// Check if the specified member is actor in the given market.
    function isActor(bytes16 marketId, address actor, XBRTypes.ActorType actorType) public view returns (bool) {
        if (markets[marketId].owner == address(0)) {
            return false;
        } else {
            if (actorType ==  XBRTypes.ActorType.CONSUMER) {
                return markets[marketId].consumerActors[actor].joined > 0;
            } else if (actorType ==  XBRTypes.ActorType.PROVIDER) {
                return markets[marketId].providerActors[actor].joined > 0;
            } else {
                return false;
            }
        }
    }

    /// Get the number of market owned by the specified member.
    function countMarketsByOwner(address owner) public view returns (uint) {
        return marketsByOwner[owner].length;
    }

    /// Get market actor data for the given actor (address) and actor type in the specified market.
    function getMarketActor (bytes16 marketId, address actor, uint8 actorType) public view
        returns (uint, uint256, string memory, bytes memory)
    {
        // the market must exist
        require(markets[marketId].owner != address(0), "NO_SUCH_MARKET");

        // must ask for a data provider (seller) or data consumer (buyer)
        require(actorType == uint8(XBRTypes.ActorType.PROVIDER) ||
                actorType == uint8(XBRTypes.ActorType.CONSUMER), "INVALID_ACTOR_TYPE");

        if (actorType == uint8(XBRTypes.ActorType.CONSUMER)) {
            XBRTypes.Actor storage _actor = markets[marketId].consumerActors[actor];
            return (_actor.joined, _actor.security, _actor.meta, _actor.signature);
        } else {
            XBRTypes.Actor storage _actor = markets[marketId].providerActors[actor];
            return (_actor.joined, _actor.security, _actor.meta, _actor.signature);
        }
    }

    /**
     * Lookup all provider actors in a XBR Market.
     *
     * @param marketId The XBR Market to provider actors for.
     * @return List of provider actor addresses in the market.
     */
    function getAllMarketProviders(bytes16 marketId) public view returns (address[] memory) {
        return markets[marketId].providerActorAdrs;
    }

    /**
     * Lookup all consumer actors in a XBR Market.
     *
     * @param marketId The XBR Market to consumer actors for.
     * @return List of consumer actor addresses in the market.
     */
    function getAllMarketConsumers(bytes16 marketId) public view returns (address[] memory) {
        return markets[marketId].consumerActorAdrs;
    }

    /**
     * Lookup all payment channels for an consumer actor in a XBR Market.
     *
     * @param marketId The XBR Market to get payment channels for.
     * @param actor The XBR actor to get payment channels for.
     * @return List of contract addresses of payment channels in the market.
     */
    function getAllPaymentChannels(bytes16 marketId, address actor) public view returns (address[] memory) {
        return markets[marketId].consumerActors[actor].channels;
    }

    /**
     * Lookup all paying channels for an provider actor in a XBR Market.
     *
     * @param marketId The XBR Market to get paying channels for.
     * @param actor The XBR actor to get paying channels for.
     * @return List of contract addresses of paying channels in the market.
     */
    function getAllPayingChannels(bytes16 marketId, address actor) public view returns (address[] memory) {
        return markets[marketId].providerActors[actor].channels;
    }

    /**
     * Lookup the current payment channel to use for the given delegate in the given market.
     *
     * @param marketId The XBR Market to get the current payment channel address for.
     * @param delegate The delegate to get the current payment channel address for.
     * @return Current payment channel address for the given delegate/market.
     */
    function currentPaymentChannelByDelegate(bytes16 marketId, address delegate) public view returns (address) {
        return markets[marketId].currentPaymentChannelByDelegate[delegate];
    }

    /**
     * Lookup the current paying channel to use for the given delegate in the given market.
     *
     * @param marketId The XBR Market to get the current paying channel address for.
     * @param delegate The delegate to get the current paying channel address for.
     * @return Current paying channel address for the given delegate/market.
     */
    function currentPayingChannelByDelegate(bytes16 marketId, address delegate) public view returns (address) {
        return markets[marketId].currentPayingChannelByDelegate[delegate];
    }
}
