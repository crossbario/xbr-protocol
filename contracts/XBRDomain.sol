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

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

// https://openzeppelin.org/api/docs/math_SafeMath.html
// import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

//import "./XBRMaintained.sol";
import "./XBRTypes.sol";
import "./XBRToken.sol";
import "./XBRNetwork.sol";


/// XBR API catalogs contract.
contract XBRDomain is Initializable {

    // Add safe math functions to uint256 using SafeMath lib from OpenZeppelin
    using SafeMath for uint256;

    /// Event emitted when a new domain was created.
    event DomainCreated (bytes16 indexed domainId, uint32 domainSeq, XBRTypes.DomainStatus status, address owner,
        bytes32 domainKey, string license, string terms, string meta);

    /// Event emitted when a domain was updated.
    event DomainUpdated (bytes16 indexed domainId, uint32 domainSeq, XBRTypes.DomainStatus status, address owner,
        bytes32 domainKey, string license, string terms, string meta);

    /// Event emitted when a domain was closed.
    event DomainClosed (bytes16 indexed domainId, XBRTypes.DomainStatus status);

    /// Event emitted when a new node was paired with the domain.
    event NodePaired (bytes16 indexed domainId, bytes16 nodeId, uint256 paired, bytes32 nodeKey, string config);

    /// Event emitted when a node was updated.
    event NodeUpdated (bytes16 indexed domainId, bytes16 nodeId, uint256 updated, bytes32 nodeKey, string config);

    /// Event emitted when a node was released from a domain.
    event NodeReleased (bytes16 indexed domainId, bytes16 nodeId, uint256 released);

    /// Instance of XBRNetwork contract this contract is linked to.
    XBRNetwork public network;

    /// IPFS multihash of the `Crossbar.io FX LICENSE <https://github.com/crossbario/crossbarfx/blob/master/crossbarfx/LICENSE>`__.
    string public license;

    /// Created domains are sequence numbered using this counter (to allow deterministic collision-free IDs for domains)
    uint32 public domainSeq;

    /// Current XBR Domains ("domain directory")
    mapping(bytes16 => XBRTypes.Domain) public domains;

    /// Current XBR Nodes ("node directory");
    mapping(bytes16 => XBRTypes.Node) public nodes;

    /// Index: node public key => (market ID, node ID)
    mapping(bytes32 => bytes16) public nodesByKey;

    /// List of IDs of current XBR Domains.
    bytes16[] public domainIds;

    // Constructor for this contract, only called once (when deploying the network).
    //
    // @param networkAdr The XBR network contract this instance is associated with.
    function initialize (address networkAdr) public initializer {
        license = "QmZSrrVWh6pCxzKcWLJMA2jg3Q3tx4RMvg1eMdVSwjmRug";
        domainSeq = 1;
        network = XBRNetwork(networkAdr);
    }

    /// Create a new XBR domain.
    ///
    /// @param domainId The ID of the domain to create. Must be globally unique (not yet existing).
    /// @param domainKey The domain signing key. A Ed25519 (https://ed25519.cr.yp.to/) public key.
    /// @param stackLicense The license for the software stack running the domain. IPFS Multihash
    ///                     pointing to a JSON/YAML file signed by the project release key.
    /// @param terms Multihash for terms that apply to the domain and to all APIs as published to this catalog.
    /// @param meta Multihash for optional domain meta-data.
    function createDomain (bytes16 domainId, bytes32 domainKey, string memory stackLicense, string memory terms,
        string memory meta) public {

        _createDomain(msg.sender, block.number, domainId, domainKey, stackLicense, terms, meta, "");
    }

    /// Create a new XBR domain.
    ///
    /// Note: This version uses pre-signed data where the actual blockchain transaction is
    /// submitted by a gateway paying the respective gas (in ETH) for the blockchain transaction.
    ///
    /// @param member Member that creates the domain and will become owner.
    /// @param created Block number when the catalog was created.
    /// @param domainId The ID of the domain to create. Must be globally unique (not yet existing).
    /// @param domainKey The domain signing key. A Ed25519 (https://ed25519.cr.yp.to/) public key.
    /// @param stackLicense The license for the software stack running the domain. IPFS Multihash
    ///                     pointing to a JSON/YAML file signed by the project release key.
    /// @param terms Multihash for terms that apply to the domain and to all APIs as published to this catalog.
    /// @param meta Multihash for optional domain meta-data.
    /// @param signature Signature created by the member.
    function createDomainFor (address member, uint256 created, bytes16 domainId, bytes32 domainKey,
        string memory stackLicense, string memory terms, string memory meta, bytes memory signature) public {

        require(XBRTypes.verify(member, XBRTypes.EIP712DomainCreate(network.verifyingChain(), network.verifyingContract(),
            member, created, domainId, domainKey, stackLicense, terms, meta), signature),
            "INVALID_SIGNATURE");

        // signature must have been created in a window of 5 blocks from the current one
        require(created <= block.number && created >= (block.number - 4), "INVALID_BLOCK_NUMBER");

        _createDomain(member, created, domainId, domainKey, stackLicense, terms, meta, signature);
    }

    function _createDomain (address member, uint256 created, bytes16 domainId, bytes32 domainKey,
        string memory stackLicense, string memory terms, string memory meta, bytes memory signature) private {
        (, , , XBRTypes.MemberLevel member_level, ) = network.members(member);

        // the domain owner must be a registered member
        require(member_level == XBRTypes.MemberLevel.ACTIVE ||
                member_level == XBRTypes.MemberLevel.VERIFIED, "SENDER_NOT_A_MEMBER");

        // check that the LICENSE the member accepted is the one we expect
        require(keccak256(abi.encode(stackLicense)) ==
                keccak256(abi.encode(license)), "INVALID_LICENSE");

        // domain must not yet exist
        require(domains[domainId].owner == address(0), "DOMAIN_ALREADY_EXISTS");

        // store new domain object
        domains[domainId] = XBRTypes.Domain(created, domainSeq, XBRTypes.DomainStatus.ACTIVE, member,
            domainKey, stackLicense, terms, meta, signature, new bytes16[](0));

        // add domainId to list of all domain IDs
        domainIds.push(domainId);

        // notify observers of new domains
        emit DomainCreated(domainId, domainSeq, XBRTypes.DomainStatus.ACTIVE, member,
            domainKey, stackLicense, terms, meta);

        // increment domain sequence for next domain
        domainSeq = domainSeq + 1;
    }

    // /**
    //  * Close an existing XBR domain. The sender must be owner of the domain, and the domain
    //  * must not have any nodes paired (anymore).
    //  *
    //  * @param domainId The ID of the domain to close.
    //  */
    // function closeDomain (bytes16 domainId) public {
    //     require(false, "NOT_IMPLEMENTED");
    // }

    /**
     * Returns domain status.
     *
     * @param domainId The ID of the domain to lookup status.
     * @return The current status of the domain.
     */
    function getDomainStatus(bytes16 domainId) public view returns (XBRTypes.DomainStatus) {
        return domains[domainId].status;
    }

    /**
     * Returns domain owner.
     *
     * @param domainId The ID of the domain to lookup owner.
     * @return The address of the owner of the domain.
     */
    function getDomainOwner(bytes16 domainId) public view returns (address) {
        return domains[domainId].owner;
    }

    /**
     * Returns domain (signing) key.
     *
     * @param domainId The ID of the domain to lookup key.
     * @return The Ed25519 public signing key for the domain.
     */
    function getDomainKey(bytes16 domainId) public view returns (bytes32) {
        return domains[domainId].key;
    }

    /**
     * Returns domain license.
     *
     * @param domainId The ID of the domain to lookup license.
     * @return IPFS Multihash pointer to domain license file on IPFS.
     */
    function getDomainLicense(bytes16 domainId) public view returns (string memory) {
        return domains[domainId].license;
    }

    /**
     * Returns domain terms.
     *
     * @param domainId The ID of the domain to lookup terms.
     * @return IPFS Multihash pointer to domain terms on IPFS.
     */
    function getDomainTerms(bytes16 domainId) public view returns (string memory) {
        return domains[domainId].terms;
    }

    /**
     * Returns domain meta data.
     *
     * @param domainId The ID of the domain to lookup meta data.
     * @return IPFS Multihash pointer to domain metadata file on IPFS.
     */
    function getDomainMeta(bytes16 domainId) public view returns (string memory) {
        return domains[domainId].meta;
    }

    /// Pair a node with a XBR Domain.
    ///
    /// @param nodeId The ID of the node to pair. Must be globally unique (not yet existing).
    /// @param domainId The ID of the domain to pair the node with.
    /// @param nodeType The type of node to pair the node under.
    /// @param nodeKey The Ed25519 public node key.
    /// @param config Optional IPFS Multihash pointing to node configuration stored on IPFS
    function pairNode (bytes16 nodeId, bytes16 domainId, XBRTypes.NodeType nodeType, bytes32 nodeKey,
        string memory config) public {

        _pairNode(msg.sender, block.number, nodeId, domainId, nodeType, nodeKey, config, "");
    }

    /// Pair a node with a XBR Domain.
    ///
    /// Note: This version uses pre-signed data where the actual blockchain transaction is
    /// submitted by a gateway paying the respective gas (in ETH) for the blockchain transaction.
    ///
    /// @param member Member that is pairing the node (must be domain owner).
    /// @param paired Block number when the node was paired to the domain.
    /// @param nodeId The ID of the node to pair. Must be globally unique (not yet existing).
    /// @param domainId The ID of the domain to pair the node with.
    /// @param nodeType The type of node to pair the node under.
    /// @param nodeKey The Ed25519 public node key.
    /// @param config Optional IPFS Multihash pointing to node configuration stored on IPFS
    /// @param signature Signature created by the member.
    function pairNodeFor (address member, uint256 paired, bytes16 nodeId, bytes16 domainId,
        XBRTypes.NodeType nodeType, bytes32 nodeKey, string memory config, bytes memory signature) public {

        require(XBRTypes.verify(member, XBRTypes.EIP712NodePair(network.verifyingChain(), network.verifyingContract(),
            member, paired, nodeId, domainId, nodeType, nodeKey, config), signature), "INVALID_SIGNATURE");

        // signature must have been created in a window of 5 blocks from the current one
        require(paired <= block.number && paired >= (block.number - 4), "INVALID_BLOCK_NUMBER");

        _pairNode(member, paired, nodeId, domainId, nodeType, nodeKey, config, signature);
    }

    function _pairNode (address member, uint256 paired, bytes16 nodeId, bytes16 domainId,
        XBRTypes.NodeType nodeType, bytes32 nodeKey, string memory config, bytes memory signature) private {

        // domain to which the node is paired must exist
        require(domains[domainId].owner != address(0), "NO_SUCH_DOMAIN");

        // member must be owner of the domain
        require(domains[domainId].owner == member, "NOT_AUTHORIZED");

        // node must not yet be paired to any (!) domain
        require(uint8(nodes[nodeId].nodeType) == 0, "NODE_ALREADY_PAIRED");
        require(nodesByKey[nodeKey] == bytes16(0), "DUPLICATE_NODE_KEY");

        // must provide a valid node type
        require(uint8(nodeType) == uint8(XBRTypes.NodeType.MASTER) ||
                uint8(nodeType) == uint8(XBRTypes.NodeType.CORE) ||
                uint8(nodeType) == uint8(XBRTypes.NodeType.EDGE), "INVALID_NODE_TYPE");

        // remember node
        nodes[nodeId] = XBRTypes.Node(paired, domainId, nodeType, nodeKey, config, signature);

        // update index
        nodesByKey[nodeKey] = nodeId;

        // update list of nodes for domain
        domains[domainId].nodes.push(nodeId);

        // notify observers
        emit NodePaired(domainId, nodeId, paired, nodeKey, config);
    }

    // /**
    //  * Release a node currently paired with an XBR domain. The sender must be owner of the domain.
    //  *
    //  * @param nodeId The ID of the node to release.
    //  */
    // function releaseNode (bytes16 nodeId) public {
    //     require(false, "NOT_IMPLEMENTED");
    // }

    /**
     * Lookup node ID by node public key.
     *
     * @param nodeKey The node public key to lookup
     * @return The Ed25519 public key of the node.
     */
    function getNodeByKey(bytes32 nodeKey) public view returns (bytes16) {
        return nodesByKey[nodeKey];
    }

    /**
     * Returns domain for a node.
     *
     * @param nodeId The ID of the node to lookup the domain for.
     * @return The domain the node is currently paired with.
     */
    function getNodeDomain(bytes16 nodeId) public view returns (bytes16) {
        return nodes[nodeId].domain;
    }

    /**
     * Returns node type for a node.
     *
     * @param nodeId The ID of the node to lookup the node type for.
     * @return The node type.
     */
    function getNodeType(bytes16 nodeId) public view returns (XBRTypes.NodeType) {
        return nodes[nodeId].nodeType;
    }

    /**
     * Returns node public key for a node.
     *
     * @param nodeId The ID of the node to lookup the node public key for.
     * @return The node public key.
     */
    function getNodeKey(bytes16 nodeId) public view returns (bytes32) {
        return nodes[nodeId].key;
    }

    /**
     * Returns config for a node.
     *
     * @param nodeId The ID of the node to lookup the config for.
     * @return IPFS Multihash pointer to node config.
     */
    function getNodeConfig(bytes16 nodeId) public view returns (string memory) {
        return nodes[nodeId].config;
    }
}
