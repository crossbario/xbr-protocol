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


/// XBR API catalogs contract.
contract XBRCatalog is Initializable {

    // Add safe math functions to uint256 using SafeMath lib from OpenZeppelin
    using SafeMath for uint256;

    /// Event emitted when a new catalog was created.
    event CatalogCreated (bytes16 indexed catalogId, uint256 created, uint32 catalogSeq,
        address owner, string terms, string meta);

    /// Event emitted when an API has been published to a catalog.
    event ApiPublished (bytes16 indexed catalogId, bytes16 apiId, uint256 published,
        string schema, string meta);

    /// Instance of XBRNetwork contract this contract is linked to.
    XBRNetwork public network;

    /// Created catalogs are sequence numbered using this counter (to allow deterministic collision-free IDs for markets)
    uint32 private catalogSeq;

    /// Current XBR Catalogs ("catalog directory")
    mapping(bytes16 => XBRTypes.Catalog) public catalogs;

    /// List of IDs of current XBR Catalogs.
    bytes16[] public catalogIds;

    // Constructor for this contract, only called once (when deploying the network).
    //
    // @param networkAdr The XBR network contract this instance is associated with.
    function initialize (address networkAdr) public initializer {
        network = XBRNetwork(networkAdr);
        catalogSeq = 1;
    }

    /// Create a new XBR catalog. The sender of the transaction must be XBR network member
    /// and automatically becomes owner of the new catalog.
    ///
    /// @param catalogId The ID of the new catalog.
    /// @param terms Multihash for terms that apply to the catalog and to all APIs as published to this catalog.
    /// @param meta Multihash for optional catalog meta-data.
    function createCatalog (bytes16 catalogId, string memory terms, string memory meta) public {

        _createCatalog(msg.sender, block.number, catalogId, terms, meta, "");
    }

    /// Create a new XBR catalog for a member. The member must be XBR network member, must have signed the
    /// transaction data, and will become owner of the new catalog.
    ///
    /// Note: This version uses pre-signed data where the actual blockchain transaction is
    /// submitted by a gateway paying the respective gas (in ETH) for the blockchain transaction.
    ///
    /// @param member Member that creates the catalog and will become owner.
    /// @param created Block number when the catalog was created.
    /// @param catalogId The ID of the new catalog.
    /// @param terms Multihash for terms that apply to the catalog and to all APIs as published to this catalog.
    /// @param meta Multihash for optional catalog meta-data.
    /// @param signature Signature created by the member.
    function createCatalogFor (address member, uint256 created, bytes16 catalogId, string memory terms,
        string memory meta, bytes memory signature) public {

        require(XBRTypes.verify(member, XBRTypes.EIP712CatalogCreate(network.verifyingChain(), network.verifyingContract(),
            member, created, catalogId, terms, meta), signature),
            "INVALID_CATALOG_CREATE_SIGNATURE");

        // signature must have been created in a window of 5 blocks from the current one
        require(created <= block.number && created >= (block.number - 4), "INVALID_CATALOG_CREATE_BLOCK_NUMBER");

        _createCatalog(member, created, catalogId, terms, meta, signature);
    }

    function _createCatalog (address member, uint256 created, bytes16 catalogId, string memory terms,
        string memory meta, bytes memory signature) private {

        (, , , XBRTypes.MemberLevel member_level, ) = network.members(member);

        // the catalog owner must be a registered member
        require(member_level == XBRTypes.MemberLevel.ACTIVE ||
                member_level == XBRTypes.MemberLevel.VERIFIED, "SENDER_NOT_A_MEMBER");

        // catalogs must not yet exist
        require(catalogs[catalogId].owner == address(0), "CATALOG_ALREADY_EXISTS");

        // store new catalog object
        catalogs[catalogId] = XBRTypes.Catalog(created, catalogSeq, member, terms, meta, signature);

        // add catalogId to list of all catalog IDs
        catalogIds.push(catalogId);

        // notify observers of new catalogs
        emit CatalogCreated(catalogId, created, catalogSeq, member, terms, meta);

        // increment catalog sequence for next catalog
        catalogSeq = catalogSeq + 1;
    }

    /// Publish the given API to the specified catalog.
    ///
    /// @param catalogId The ID of the XBR API catalog to publish the API to.
    /// @param apiId The ID of the new API (must be unique).
    /// @param schema Multihash of API Flatbuffers schema (required).
    /// @param meta Multihash for optional meta-data.
    function publishApi (bytes16 catalogId, bytes16 apiId, string memory schema, string memory meta) public {

        _publishApi(msg.sender, block.number, catalogId, apiId, schema, meta, "");
    }

    /// Publish the given API to the specified catalog.
    ///
    /// Note: This version uses pre-signed data where the actual blockchain transaction is
    /// submitted by a gateway paying the respective gas (in ETH) for the blockchain transaction.
    ///
    /// @param member Member that is publishing the API.
    /// @param published Block number when the API was published.
    /// @param catalogId The ID of the XBR API catalog to publish the API to.
    /// @param apiId The ID of the new API (must be unique).
    /// @param schema Multihash of API Flatbuffers schema (required).
    /// @param meta Multihash for optional meta-data.
    /// @param signature Signature created by the member.
    function publishApiFor (address member, uint256 published, bytes16 catalogId, bytes16 apiId,
        string memory schema, string memory meta, bytes memory signature) public {

        require(XBRTypes.verify(member, XBRTypes.EIP712ApiPublish(network.verifyingChain(), network.verifyingContract(),
            member, published, catalogId, apiId, schema, meta), signature), "INVALID_API_PUBLISH_SIGNATURE");

        // signature must have been created in a window of 5 blocks from the current one
        require(published <= block.number && published >= (block.number - 4), "INVALID_API_PUBLISH_BLOCK_NUMBER");

        _publishApi(member, published, catalogId, apiId, schema, meta, signature);
    }

    function _publishApi (address member, uint256 published, bytes16 catalogId, bytes16 apiId,
        string memory schema, string memory meta, bytes memory signature) private {

        (, , , XBRTypes.MemberLevel member_level, ) = network.members(member);

        // the publishing user must be a registered member
        require(member_level == XBRTypes.MemberLevel.ACTIVE, "SENDER_NOT_A_MEMBER");

        // the catalog to publish to must exist
        require(catalogs[catalogId].owner != address(0), "NO_SUCH_CATALOG");

        // the publishing member must be owner of the catalog
        require(catalogs[catalogId].owner == member, "SENDER_IS_NOT_OWNER");

        // the API, identified by the ID, must not yet exist
        require(catalogs[catalogId].apis[apiId].published == 0, "API_ALREADY_EXISTS");

        // add API to API-map of catalog
        catalogs[catalogId].apis[apiId] = XBRTypes.Api(published, schema, meta, signature);
    }
}
