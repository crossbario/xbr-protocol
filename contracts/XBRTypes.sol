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


/**
 * The `XBR Types <https://github.com/crossbario/xbr-protocol/blob/master/contracts/XBRTypes.sol>`__
 * library collect XBR type definitions used throughout the other XBR contracts.
 */
library XBRTypes {

    // FIXME: this does not work .. hence we put this constant into XBRNetwork.ANYADR
    // address public constant ANYADR = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;

    /// All XBR network member levels defined.
    enum MemberLevel { NULL, ACTIVE, VERIFIED, RETIRED, PENALTY, BLOCKED, RETIRING }

    /// XBR Domain status values
    enum DomainStatus { NULL, ACTIVE, CLOSED }

    /// XBR Carrier Node types
    enum NodeType { NULL, MASTER, CORE, EDGE }

    /// Market state for a given data market. The market can only be joined and new channels
    /// can only be opened when the market is in state OPEN. When the market operator is closing
    /// the market, state is moved to CLOSING. Once all channels have been closed, state is
    /// moved to CLOSED. Once all actors have left (and any securities have been redeemed),
    /// the market is moved to LIQUIDATED.
    enum MarketState { NULL, OPEN, CLOSING, CLOSED, LIQUIDATED }

    /// Current state of an actor in a market.
    enum ActorState { NULL, JOINED, LEAVING, LEFT }

    /// All XBR market actor types defined.
    enum ActorType { NULL, PROVIDER, CONSUMER, PROVIDER_CONSUMER }

    /// All XBR state channel types defined.
    enum ChannelType { NULL, PAYMENT, PAYING }

    /// All XBR state channel states defined.
    enum ChannelState { NULL, OPEN, CLOSING, CLOSED, FAILED }

    /// Lava Protocol (https://lavaprotocol.com) ERC20 metatransaction.
    struct LavaPacket {
        // do not touch / and keep synced to https://github.com/admazzola/lava-wallet/blob/master/contracts/LavaWallet.sol
        string methodName;
        address relayAuthority; // either a contract or an account
        address from;
        address to;
        address wallet;  // the wallet contract address
        address token;
        uint256 tokens;
        uint256 relayerRewardTokens;
        uint256 expires;
        uint256 nonce;
    }

    /// Container type for holding XBR network membership information.
    struct Member {
        /// Block number when the member was (initially) registered in the XBR network.
        uint256 registered;

        /// The IPFS Multihash of the XBR EULA being agreed to and stored as one
        /// ZIP file archive on IPFS.
        string eula;

        /// Optional public member profile. An IPFS Multihash of the member profile
        /// stored in IPFS.
        string profile;

        /// Current member level.
        MemberLevel level;

        /// If the transaction to join the XBR network as a new member was was pre-signed
        /// off-chain by the new member, this is the signature the user supplied. If the
        /// user on-boarded by directly interacting with the XBR contracts on-chain, this
        /// will be empty.
        bytes signature;
    }

    /// Container type for holding XBR Domain information.
    struct Domain {
        /// Block number when the domain was created.
        uint256 created;

        /// Domain sequence.
        uint32 seq;

        /// Domain status
        DomainStatus status;

        /// Domain owner.
        address owner;

        /// Domain signing key (Ed25519 public key).
        bytes32 key;

        /// Software stack license file on IPFS (required).
        string license;

        /// Optional domain terms on IPFS.
        string terms;

        /// Optional domain metadata on IPFS.
        string meta;

        bytes signature;

        /// Nodes within the domain.
        bytes16[] nodes;
    }

    /// Container type for holding XBR Domain Nodes information.
    struct Node {
        /// Block number when the node was paired to the respective domain.
        uint256 paired;

        bytes16 domain;

        /// Type of node.
        NodeType nodeType;

        /// Node key (Ed25519 public key).
        bytes32 key;

        /// Optional (encrypted) node configuration on IPFS.
        string config;

        bytes signature;
    }

    /// Network level (global) stats for an XBR network member.
    struct MemberMarketStats {
        /// Number of markets the member is currently owner (operator) of.
        uint32 marketsOwned;

        /// Number of markets the member is currently joined to as a (buyer, seller, buyer+seller) actor.
        uint32 marketsJoined;

        /// Total sum of consumer/provider securities put at stake as a buyer/seller-actor in any joined market.
        uint256 marketSecuritiesSent;

        uint256 marketSecuritiesReceived;
    }

    struct MemberChannelStats {
        uint32 paymentChannels;
        uint32 payingChannels;
        uint32 activePaymentChannels;
        uint32 activePayingChannels;
        /// Total sum of deposits initially put into (currently still active / open) payment/paying channels by the buyer/seller-actor in any joined market.
        uint256 activePaymentChannelDeposits;
        uint256 activePayingChannelDeposits;
    }

    /// Container type for holding XBR market actor information.
    struct Actor {
        /// Block number when the actor has joined the respective market.
        uint256 joined;

        /// Security deposited by the actor when joining the market.
        uint256 security;

        /// Metadata attached to an actor in a market.
        string meta;

        /// This is the signature the user (actor) supplied for joining a market.
        bytes signature;

        /// Current state of an actor in a market.
        ActorState state;

        /// All payment (paying) channels of the respective buyer (seller) actor.
        address[] channels;

        mapping(address => mapping(bytes16 => Consent)) delegates;
    }

    /// Container type for holding XBR market information.
    struct Market {
        /// Block number when the market was created.
        uint256 created;

        /// Market sequence number.
        uint32 seq;

        /// Market owner (aka "market operator").
        address owner;

        /// The coin (ERC20 token) to be used in the market as the means of payment.
        address coin;

        /// Market terms (IPFS Multihash).
        string terms;

        /// Market metadata (IPFS Multihash).
        string meta;

        /// Market maker address.
        address maker;

        /// Security deposit required by data providers (sellers) to join the market.
        uint256 providerSecurity;

        /// Security deposit required by data consumers (buyers) to join the market.
        uint256 consumerSecurity;

        /// Market fee rate for the market operator.
        uint256 marketFee;

        /// This is the signature the user (market owner/operator) supplied for opening the market.
        bytes signature;

        /// Adresses of provider (seller) actors joined in the market.
        address[] providerActorAdrs;

        /// Adresses of consumer (buyer) actors joined in the market.
        address[] consumerActorAdrs;

        /// Provider (seller) actors joined in the market by actor address.
        mapping(address => Actor) providerActors;

        /// Consumer (buyer) actors joined in the market by actor address.
        mapping(address => Actor) consumerActors;

        /// Current payment channel by (buyer) delegate.
        mapping(address => address) currentPaymentChannelByDelegate;

        /// Current paying channel by (seller) delegate.
        mapping(address => address) currentPayingChannelByDelegate;
    }

    /// Container type for holding XBR data service API information.
    struct Api {
        /// Block number when the API was added to the respective catalog.
        uint256 published;

        /// Multihash of API Flatbuffers schema (required).
        string schema;

        /// Multihash of API meta-data (optional).
        string meta;

        /// This is the signature the user (actor) supplied when publishing the API.
        bytes signature;
    }

    /// Container type for holding XBR catalog information.
    struct Catalog {
        /// Block number when the catalog was created.
        uint256 created;

        /// Catalog sequence number.
        uint32 seq;

        /// Catalog owner (aka "catalog publisher").
        address owner;

        /// Catalog terms (IPFS Multihash).
        string terms;

        /// Catalog metadata (IPFS Multihash).
        string meta;

        /// This is the signature the member supplied for creating the catalog.
        bytes signature;

        /// The APIs part of this catalog.
        mapping(bytes16 => Api) apis;
    }

    struct Consent {
        /// Block number when the catalog was created.
        uint256 updated;

        /// Consent granted or revoked.
        bool consent;

        /// The WAMP URI prefix to be used by the delegate in the data plane realm.
        string servicePrefix;

        /// This is the signature the user (actor) supplied when setting the consent status.
        bytes signature;
    }

    /// Container type for holding channel static information.
    ///
    /// NOTE: This struct has a companion struct `ChannelState` with all
    /// varying state. The split-up is necessary as the EVM limits stack-depth
    /// to 16, and we need more channel attributes than that.
    struct Channel {
        /// Block number when the channel was created.
        uint256 created;

        /// Channel sequence number.
        uint32 seq;

        /// Current payment channel type (either payment or paying channel).
        ChannelType ctype;

        /// The XBR Market ID this channel is operating payments (or payouts) for.
        bytes16 marketId;

        /// The channel ID.
        bytes16 channelId;

        /// The sender of the payments in this channel. Either a XBR consumer (for
        /// payment channels) or the XBR market maker (for paying channels).
        address actor;

        /// The delegate of the channel, e.g. the XBR consumer delegate in case
        /// of a payment channel or the XBR provider delegate in case of a paying
        /// channel that is allowed to consume or provide data with off-chain
        /// transactions and  payments running under this channel.
        address delegate;

        /// The off-chain market maker that operates this payment or paying channel.
        address marketmaker;

        /// Recipient of the payments in this channel. Either the XBR market operator
        /// (for payment channels) or a XBR provider (for paying channels).
        address recipient;

        /// Amount of tokens (denominated in the respective market token) held in
        /// this channel (initially deposited by the actor).
        uint256 amount;

        /// Signature supplied (by the actor) when opening the channel.
        bytes signature;
    }

    /// Container type for holding channel (closing) state information.
    struct ChannelClosingState {
        /// Current payment channel state.
        ChannelState state;

        /// Block timestamp when the channel was requested to close (before timeout).
        uint256 closingAt;

        /// When this channel is closing, the sequence number of the closing transaction.
        uint32 closingSeq;

        /// When this channel is closing, the off-chain closing balance of the closing transaction.
        uint256 closingBalance;

        /// Block timestamp when the channel was closed (finally, after the timeout).
        uint256 closedAt;

        /// When this channel has closed, the sequence number of the final accepted closing transaction.
        uint32 closedSeq;

        /// When this channel is closing, the closing balance of the final accepted closing transaction.
        uint256 closedBalance;

        /// Closing transaction signature by (buyer or seller) delegate supplied when requesting to close the channel.
        bytes delegateSignature;

        /// Closing transaction signature by market maker supplied when requesting to close the channel.
        bytes marketmakerSignature;
    }

    /// Lava Protocol (https://lavaprotocol.com) ERC20 metatransaction.
    struct EIP712LavaTransaction {
        // do not touch / and keep synced to https://github.com/admazzola/lava-wallet/blob/master/contracts/LavaWallet.sol
        string methodName;
        address relayAuthority; // either a contract or an account
        address from;
        address to;
        address wallet;  // the wallet contract address
        address token;
        uint256 tokens;
        uint256 relayerRewardTokens;
        uint256 expires;
        uint256 nonce;
    }

    /// EIP712 type for XBR as a type domain.
    struct EIP712Domain {
        /// The type domain name, makes signatures from different domains incompatible.
        string  name;

        /// The type domain version.
        string  version;
    }

    /// EIP712 type for use in member registration.
    struct EIP712MemberRegister {
        /// Verifying chain ID, which binds the signature to that chain
        /// for cross-chain replay-attack protection.
        uint256 chainId;

        /// Verifying contract address, which binds the signature to that address
        /// for cross-contract replay-attack protection.
        address verifyingContract;

        /// Registered member address.
        address member;

        /// Block number when the member registered in the XBR network.
        uint256 registered;

        /// Multihash of EULA signed by the member when registering.
        string eula;

        /// Optional profile meta-data multihash.
        string profile;
    }

    /// EIP712 type for use in member unregistration.
    struct EIP712MemberUnregister {
        /// Verifying chain ID, which binds the signature to that chain
        /// for cross-chain replay-attack protection.
        uint256 chainId;

        /// Verifying contract address, which binds the signature to that address
        /// for cross-contract replay-attack protection.
        address verifyingContract;

        /// Address of the member that was unregistered.
        address member;

        /// Block number when the member retired from the XBR network.
        uint256 retired;
    }

    /// EIP712 type for use in domain creation.
    struct EIP712DomainCreate {
        /// Verifying chain ID, which binds the signature to that chain
        /// for cross-chain replay-attack protection.
        uint256 chainId;

        /// Verifying contract address, which binds the signature to that address
        /// for cross-contract replay-attack protection.
        address verifyingContract;

        /// The member that created the domain.
        address member;

        /// Block number when the member registered in the XBR network.
        uint256 created;

        /// The ID of the domain created (a 16 bytes UUID which is globally unique to that market).
        bytes16 domainId;

        /// Domain signing key (Ed25519 public key).
        bytes32 domainKey;

        /// Multihash for the license for the software stack running the domain.
        string license;

        /// Multihash for the terms applying to this domain.
        string terms;

        /// Multihash for optional meta-data supplied for the domain.
        string meta;
    }

    /// EIP712 type for use in publishing APIs to catalogs.
    struct EIP712NodePair {
        /// Verifying chain ID, which binds the signature to that chain
        /// for cross-chain replay-attack protection.
        uint256 chainId;

        /// Verifying contract address, which binds the signature to that address
        /// for cross-contract replay-attack protection.
        address verifyingContract;

        /// The XBR network member pairing the node.
        address member;

        /// Block number when the node was paired to the domain.
        uint256 paired;

        /// The ID of the node to pair. Must be globally unique (not yet existing).
        bytes16 nodeId;

        /// The ID of the domain to pair the node with.
        bytes16 domainId;

        /// The type of node to pair the node under.
        NodeType nodeType;

        /// The Ed25519 public node key.
        bytes32 nodeKey;

        /// Optional IPFS Multihash pointing to node configuration stored on IPFS.
        string config;
    }

    /// EIP712 type for use in catalog creation.
    struct EIP712CatalogCreate {
        /// Verifying chain ID, which binds the signature to that chain
        /// for cross-chain replay-attack protection.
        uint256 chainId;

        /// Verifying contract address, which binds the signature to that address
        /// for cross-contract replay-attack protection.
        address verifyingContract;

        /// The member that created the catalog.
        address member;

        /// Block number when the member registered in the XBR network.
        uint256 created;

        /// The ID of the catalog created (a 16 bytes UUID which is globally unique to that market).
        bytes16 catalogId;

        /// Multihash for the terms applying to this catalog.
        string terms;

        /// Multihash for optional meta-data supplied for the catalog.
        string meta;
    }

    /// EIP712 type for use in publishing APIs to catalogs.
    struct EIP712ApiPublish {
        /// Verifying chain ID, which binds the signature to that chain
        /// for cross-chain replay-attack protection.
        uint256 chainId;

        /// Verifying contract address, which binds the signature to that address
        /// for cross-contract replay-attack protection.
        address verifyingContract;

        /// The XBR network member publishing the API.
        address member;

        /// Block number when the API was published to the catalog.
        uint256 published;

        /// The ID of the catalog the API is published to.
        bytes16 catalogId;

        /// The ID of the API published.
        bytes16 apiId;

        /// Multihash of API Flatbuffers schema (required).
        string schema;

        /// Multihash of API meta-data (optional).
        string meta;
    }

    /// EIP712 type for use in market creation.
    struct EIP712MarketCreate {
        /// Verifying chain ID, which binds the signature to that chain
        /// for cross-chain replay-attack protection.
        uint256 chainId;

        /// Verifying contract address, which binds the signature to that address
        /// for cross-contract replay-attack protection.
        address verifyingContract;

        /// The member that created the catalog.
        address member;

        /// Block number when the market was created.
        uint256 created;

        /// The ID of the market created (a 16 bytes UUID which is globally unique to that market).
        bytes16 marketId;

        /// Coin used as means of payment in market. Must be an ERC20 compatible token.
        address coin;

        /// Multihash for the market terms applying to this market.
        string terms;

        /// Multihash for optional market meta-data supplied for the market.
        string meta;

        /// The address of the market maker responsible for this market. The market
        /// maker of a market is the link between off-chain channels and on-chain channels,
        /// and operates the channels by processing transactions.
        address maker;

        // FIXME: enabling the following  runs into stack-depth limit of 12!
        //        => move to attributes (under "meta" multihash)

        /// Any mandatory security that actors that join this market as data providers (selling data
        /// as seller actors) must supply when joining this market. May be 0.
        // uint256 providerSecurity;

        /// Any mandatory security that actors that join this market as data consumer (buying data
        /// as buyer actors) must supply when joining this market. May be 0.
        // uint256 consumerSecurity;

        /// The market fee that applies in this market. May be 0.
        uint256 marketFee;
    }

    /// EIP712 type for use in joining markets.
    struct EIP712MarketJoin {
        /// Verifying chain ID, which binds the signature to that chain
        /// for cross-chain replay-attack protection.
        uint256 chainId;

        /// Verifying contract address, which binds the signature to that address
        /// for cross-contract replay-attack protection.
        address verifyingContract;

        /// The XBR network member joining the specified market as a market actor.
        address member;

        /// Block number when the member as joined the market,
        uint256 joined;

        /// The ID of the market joined.
        bytes16 marketId;

        /// The actor type as which to join, which can be "buyer" or "seller" or "buyer+seller".
        uint8 actorType;

        /// Optional multihash for additional meta-data supplied
        /// for the actor joining the market.
        string meta;
    }

    /// EIP712 type for use in leaving markets.
    struct EIP712MarketLeave {
        /// Verifying chain ID, which binds the signature to that chain
        /// for cross-chain replay-attack protection.
        uint256 chainId;

        /// Verifying contract address, which binds the signature to that address
        /// for cross-contract replay-attack protection.
        address verifyingContract;

        /// The XBR network member leaving the specified market as the given market actor type.
        address member;

        /// Block number when the member left the market.
        uint256 left;

        /// The ID of the market left.
        bytes16 marketId;

        /// The actor type as which to leave, which can be "buyer" or "seller" or "buyer+seller".
        uint8 actorType;
    }

    /// EIP712 type for use in data consent tracking.
    struct EIP712Consent {
        /// Verifying chain ID, which binds the signature to that chain
        /// for cross-chain replay-attack protection.
        uint256 chainId;

        /// Verifying contract address, which binds the signature to that address
        /// for cross-contract replay-attack protection.
        address verifyingContract;

        /// The XBR network member giving consent.
        address member;

        /// Block number when the consent was status set.
        uint256 updated;

        /// The ID of the market in which consent was given.
        bytes16 marketId;

        /// Address of delegate consent (status) applies to.
        address delegate;

        /// The actor type for which the consent was set for the delegate.
        uint8 delegateType;

        /// The ID of the XBR data catalog consent was given for.
        bytes16 apiCatalog;

        /// Consent granted or revoked.
        bool consent;

        /// The WAMP URI prefix to be used by the delegate in the data plane realm.
        string servicePrefix;
    }

    /// EIP712 type for use in opening channels. The initial opening of a channel
    /// is one on-chain transaction (as is the final close), but all actual
    /// in-channel transactions happen off-chain.
    struct EIP712ChannelOpen {
        /// Verifying chain ID, which binds the signature to that chain
        /// for cross-chain replay-attack protection.
        uint256 chainId;

        /// Verifying contract address, which binds the signature to that address
        /// for cross-contract replay-attack protection.
        address verifyingContract;

        /// The type of channel, can be payment channel (for use by buyer delegates) or
        /// paying channel (for use by seller delegates).
        uint8 ctype;

        /// Block number when the channel was opened.
        uint256 openedAt;

        /// The ID of the market in which the channel was opened.
        bytes16 marketId;

        /// The ID of the channel created (a 16 bytes UUID which is globally unique to that
        /// channel, in particular the channel ID is unique even across different markets).
        bytes16 channelId;

        /// The actor that created this channel.
        address actor;

        /// The delegate authorized to use this channel for off-chain transactions.
        address delegate;

        /// The address of the market maker that will operate the channel and
        /// perform the off-chain transactions.
        address marketmaker;

        /// The final recipient of the payout from the channel when the channel is closed.
        address recipient;

        /// The amount of tokens initially put into this channel by the actor. The value is
        /// denominated in the payment token used in the market.
        uint256 amount;
    }

    /// EIP712 type for use in closing channels.The final closing of a channel
    /// is one on-chain transaction (as is the final close), but all actual
    /// in-channel transactions happened before off-chain.
    struct EIP712ChannelClose {
        /// Verifying chain ID, which binds the signature to that chain
        /// for cross-chain replay-attack protection.
        uint256 chainId;

        /// Verifying contract address, which binds the signature to that address
        /// for cross-contract replay-attack protection.
        address verifyingContract;

        /// Block number when the channel close was signed.
        uint256 closeAt;

        /// The ID of the market in which the channel to be closed was initially opened.
        bytes16 marketId;

        /// The ID of the channel to close.
        bytes16 channelId;

        /// The sequence number of the channel closed.
        uint32 channelSeq;

        /// The remaining closing balance at which the channel is closed.
        uint256 balance;

        /// Indication whether the data signed is considered final, which amounts
        /// to a promise that no further, newer signed data will be supplied later.
        bool isFinal;
    }

    /// Lava Protocol project wallet address on mainnet (https://etherscan.io/address/0x1bf797219482a29013d804ad96d1c6f84fba4c45)
    address public constant LAVA_PROJECT_WALLET_ADR = 0x1Bf797219482A29013d804Ad96D1C6F84FBA4C45;

    /// EIP712 type data. - DO NOT TOUCH THE STRING VALUE!
    // solhint-disable-next-line
    bytes32 constant EIP712_LAVADOMAIN_TYPEHASH = keccak256("EIP712Domain(string contractName,string version,uint256 chainId,address verifyingContract)");

    /// EIP712 type data. - DO NOT TOUCH THE STRING VALUE!
    // solhint-disable-next-line
    bytes32 constant EIP712_LAVAPACKET_TYPEHASH = keccak256("LavaPacket(string methodName,address relayAuthority,address from,address to,address wallet,address token,uint256 tokens,uint256 relayerRewardTokens,uint256 expires,uint256 nonce)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_MEMBER_REGISTER_TYPEHASH = keccak256("EIP712MemberRegister(uint256 chainId,address verifyingContract,address member,uint256 registered,string eula,string profile)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_MEMBER_UNREGISTER_TYPEHASH = keccak256("EIP712MemberUnregister(uint256 chainId,address verifyingContract,address member,uint256 retired)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_DOMAIN_CREATE_TYPEHASH = keccak256("EIP712DomainCreate(uint256 chainId,address verifyingContract,address member,uint256 created,bytes16 domainId,bytes32 domainKey,string license,string terms,string meta)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_NODE_PAIR_TYPEHASH = keccak256("EIP712NodePair(uint256 chainId,address verifyingContract,address member,uint256 paired,bytes16 nodeId,bytes16 domainId,uint8 nodeType,bytes32 nodeKey,string config)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_CATALOG_CREATE_TYPEHASH = keccak256("EIP712CatalogCreate(uint256 chainId,address verifyingContract,address member,uint256 created,bytes16 catalogId,string terms,string meta)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_API_PUBLISH_TYPEHASH = keccak256("EIP712ApiPublish(uint256 chainId,address verifyingContract,address member,uint256 published,bytes16 catalogId,bytes16 apiId,string terms,string meta)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_MARKET_CREATE_TYPEHASH = keccak256("EIP712MarketCreate(uint256 chainId,address verifyingContract,address member,uint256 created,bytes16 marketId,address coin,string terms,string meta,address maker,uint256 marketFee)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_MARKET_JOIN_TYPEHASH = keccak256("EIP712MarketJoin(uint256 chainId,address verifyingContract,address member,uint256 joined,bytes16 marketId,uint8 actorType,string meta)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_MARKET_LEAVE_TYPEHASH = keccak256("EIP712MarketLeave(uint256 chainId,address verifyingContract,address member,uint256 left,bytes16 marketId,uint8 actorType)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_CONSENT_TYPEHASH = keccak256("EIP712Consent(uint256 chainId,address verifyingContract,address member,uint256 updated,bytes16 marketId,address delegate,uint8 delegateType,bytes16 apiCatalog,bool consent)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_CHANNEL_OPEN_TYPEHASH = keccak256("EIP712ChannelOpen(uint256 chainId,address verifyingContract,uint8 ctype,uint256 openedAt,bytes16 marketId,bytes16 channelId,address actor,address delegate,address marketmaker,address recipient,uint256 amount)");

    /// EIP712 type data.
    // solhint-disable-next-line
    bytes32 constant EIP712_CHANNEL_CLOSE_TYPEHASH = keccak256("EIP712ChannelClose(uint256 chainId,address verifyingContract,uint256 closeAt,bytes16 marketId,bytes16 channelId,uint32 channelSeq,uint256 balance,bool isFinal)");

    /// Check if the given address is a contract.
    function isContract(address adr) public view returns (bool) {
        uint256 codeLength;

        assembly {
            // Retrieve the size of the code on target address, this needs assembly .
            codeLength := extcodesize(adr)
        }

        return codeLength > 0;
    }

    /// Splits a signature (65 octets) into components (a "vrs"-tuple).
    function splitSignature (bytes memory signature_rsv) public pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(signature_rsv.length == 65, "INVALID_SIGNATURE_LENGTH");

        // Split a signature given as a bytes string into components.
        assembly
        {
            r := mload(add(signature_rsv, 32))
            s := mload(add(signature_rsv, 64))
            v := and(mload(add(signature_rsv, 65)), 255)
        }
        if (v < 27) {
            v += 27;
        }

        return (v, r, s);
    }

    function hash(EIP712Domain memory domain_) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256(bytes(domain_.name)),
            keccak256(bytes(domain_.version))
        ));
    }

    function domainSeparator () private pure returns (bytes32) {
        // makes signatures from different domains incompatible.
        // see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md#arbitrary-messages
        return hash(EIP712Domain({
            name: "XBR",
            version: "1"
        }));
    }

    function getLavaProtocolDomainHash(string memory contractName, string memory version,
        uint256 chainId, address verifyingContract) public pure returns (bytes32) {
        // do not touch / and keep synced to https://github.com/admazzola/lava-wallet/blob/master/contracts/LavaWallet.sol
        return keccak256(abi.encode(
            EIP712_LAVADOMAIN_TYPEHASH,
            keccak256(bytes(contractName)),
            keccak256(bytes(version)),
            chainId,
            verifyingContract
        ));
    }

    function getLavaProtocolPacketHash(string memory methodName, address relayAuthority, address from,
        address to, address wallet, address token, uint256 tokens, uint256 relayerRewardTokens,
        uint256 expires, uint256 nonce) public pure returns (bytes32) {
        // do not touch / and keep synced to https://github.com/admazzola/lava-wallet/blob/master/contracts/LavaWallet.sol
        return keccak256(abi.encode(
            EIP712_LAVAPACKET_TYPEHASH,
            keccak256(bytes(methodName)),
            relayAuthority,
            from,
            to,
            wallet,
            token,
            tokens,
            relayerRewardTokens,
            expires,
            nonce
        ));
    }

    function hash (EIP712LavaTransaction memory obj) private pure returns (bytes32) {
        // do not touch / and keep synced to https://github.com/admazzola/lava-wallet/blob/master/contracts/LavaWallet.sol
        return keccak256(abi.encodePacked(
            "\x19\x01",
            // FIXME: read chain_id at run-time
            getLavaProtocolDomainHash("Lava Wallet", "1", 1, LAVA_PROJECT_WALLET_ADR),
            getLavaProtocolPacketHash(obj.methodName, obj.relayAuthority, obj.from, obj.to, obj.wallet,
                obj.token, obj.tokens, obj.relayerRewardTokens, obj.expires, obj.nonce)
        ));
    }

    function hash (EIP712MemberRegister memory obj) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_MEMBER_REGISTER_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.member,
            obj.registered,
            keccak256(bytes(obj.eula)),
            keccak256(bytes(obj.profile))
        ));
    }

    function hash (EIP712MemberUnregister memory obj) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_MEMBER_UNREGISTER_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.member,
            obj.retired
        ));
    }

    function hash (EIP712DomainCreate memory obj) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_DOMAIN_CREATE_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.member,
            obj.created,
            obj.domainId,
            obj.domainKey,
            keccak256(bytes(obj.license)),
            keccak256(bytes(obj.terms)),
            keccak256(bytes(obj.meta))
        ));
    }

    function hash (EIP712NodePair memory obj) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_NODE_PAIR_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.member,
            obj.paired,
            obj.nodeId,
            obj.domainId,
            obj.nodeType,
            obj.nodeKey,
            keccak256(bytes(obj.config))
        ));
    }

    function hash (EIP712CatalogCreate memory obj) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_CATALOG_CREATE_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.member,
            obj.created,
            obj.catalogId,
            keccak256(bytes(obj.terms)),
            keccak256(bytes(obj.meta))
        ));
    }

    function hash (EIP712ApiPublish memory obj) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_API_PUBLISH_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.member,
            obj.published,
            obj.catalogId,
            obj.apiId,
            keccak256(bytes(obj.schema)),
            keccak256(bytes(obj.meta))
        ));
    }

    function hash (EIP712MarketCreate memory obj) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_MARKET_CREATE_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.member,
            obj.created,
            obj.marketId,
            obj.coin,
            keccak256(bytes(obj.terms)),
            keccak256(bytes(obj.meta)),
            obj.maker,
            // obj.providerSecurity,
            // obj.consumerSecurity,
            obj.marketFee
        ));
    }

    function hash (EIP712MarketJoin memory obj) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_MARKET_JOIN_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.member,
            obj.joined,
            obj.marketId,
            obj.actorType,
            keccak256(bytes(obj.meta))
        ));
    }

    function hash (EIP712MarketLeave memory obj) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_MARKET_JOIN_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.member,
            obj.left,
            obj.marketId,
            obj.actorType
        ));
    }

    function hash (EIP712Consent memory obj) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_CONSENT_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.member,
            obj.updated,
            obj.marketId,
            obj.delegate,
            obj.delegateType,
            obj.apiCatalog,
            obj.consent,
            keccak256(bytes(obj.servicePrefix))
        ));
    }

    function hash (EIP712ChannelOpen memory obj) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_CHANNEL_OPEN_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.ctype,
            obj.openedAt,
            obj.marketId,
            obj.channelId,
            obj.actor,
            obj.delegate,
            obj.marketmaker,
            obj.recipient,
            obj.amount
        ));
    }

    function hash (EIP712ChannelClose memory obj) private pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_CHANNEL_CLOSE_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.closeAt,
            obj.marketId,
            obj.channelId,
            obj.channelSeq,
            obj.balance,
            obj.isFinal
        ));
    }

    /// Verify signature on typed data for registering a member.
    function verify (address signer, EIP712MemberRegister memory obj,
        bytes memory signature) public pure returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    /// Verify signature on typed data for unregistering a member.
    function verify (address signer, EIP712MemberUnregister memory obj,
        bytes memory signature) public pure returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    /// Verify signature on typed data for creating a domain.
    function verify (address signer, EIP712DomainCreate memory obj,
        bytes memory signature) public pure returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    /// Verify signature on typed data for pairing a node.
    function verify (address signer, EIP712NodePair memory obj,
        bytes memory signature) public pure returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    /// Verify signature on typed data for creating a catalog.
    function verify (address signer, EIP712CatalogCreate memory obj,
        bytes memory signature) public pure returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    /// Verify signature on typed data for publishing an API to a catalog.
    function verify (address signer, EIP712ApiPublish memory obj,
        bytes memory signature) public pure returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    /// Verify signature on typed data for creating a market.
    function verify (address signer, EIP712MarketCreate memory obj,
        bytes memory signature) public pure returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    /// Verify signature on typed data for joining a market.
    function verify (address signer, EIP712MarketJoin memory obj,
        bytes memory signature) public pure returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    /// Verify signature on typed data for leaving a market.
    function verify (address signer, EIP712MarketLeave memory obj,
        bytes memory signature) public pure returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    /// Verify signature on typed data for setting consent.
    function verify (address signer, EIP712Consent memory obj,
        bytes memory signature) public pure returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    /// Verify signature on typed data for opening a channel.
    function verify (address signer, EIP712ChannelOpen memory obj,
        bytes memory signature) public pure returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    /// Verify signature on typed data for closing a channel.
    function verify (address signer, EIP712ChannelClose memory obj,
        bytes memory signature) public pure returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    /// Check if the given address is a contract.
    function isContract(address adr) public view returns (bool) {
        uint256 codeLength;

        assembly {
            // Retrieve the size of the code on target address, this needs assembly .
            codeLength := extcodesize(adr)
        }

        return codeLength > 0;
    }
}
