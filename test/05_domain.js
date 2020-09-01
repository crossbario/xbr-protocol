///////////////////////////////////////////////////////////////////////////////
//
//  XBR Open Data Markets - https://xbr.network
//
//  Copyright (C) Crossbar.io Technologies GmbH and contributors
//
//  Licensed under the Apache 2.0 License:
//  https://opensource.org/licenses/Apache-2.0
//
///////////////////////////////////////////////////////////////////////////////

const utils = require("./utils.js");
const w3_utils = require("web3-utils");
const eth_sig_utils = require("eth-sig-util");
const eth_util = require("ethereumjs-util");
const BN = require('bn.js');

const XBRNetwork = artifacts.require("./XBRNetwork.sol");
const XBRToken = artifacts.require("./XBRToken.sol");
const XBRDomain = artifacts.require("./XBRDomain.sol");


const EIP712DomainCreate = {
    types: {
        EIP712Domain: [
            { name: 'name', type: 'string' },
            { name: 'version', type: 'string' },
        ],
        EIP712DomainCreate: [
            {name: 'chainId', type: 'uint256'},
            {name: 'verifyingContract', type: 'address'},
            {name: 'member', type: 'address'},
            {name: 'created', type: 'uint256'},
            {name: 'domainId', type: 'bytes16'},
            {name: 'domainKey', type: 'bytes32'},
            {name: 'license', type: 'string'},
            {name: 'terms', type: 'string'},
            {name: 'meta', type: 'string'},
        ]
    },
    primaryType: 'EIP712DomainCreate',
    domain: {
        name: 'XBR',
        version: '1'
    },
    message: null
};


function sign_create_domain(key_, data_) {
    EIP712DomainCreate['message'] = data_;
    var key = eth_util.toBuffer(key_);
    var sig = eth_sig_utils.signTypedData(key, {data: EIP712DomainCreate});
    return sig;
}


const EIP712NodePair = {
    types: {
        EIP712Domain: [
            { name: 'name', type: 'string' },
            { name: 'version', type: 'string' },
        ],
        EIP712NodePair: [
            {name: 'chainId', type: 'uint256'},
            {name: 'verifyingContract', type: 'address'},
            {name: 'member', type: 'address'},
            {name: 'paired', type: 'uint256'},
            {name: 'nodeId', type: 'bytes16'},
            {name: 'domainId', type: 'bytes16'},
            {name: 'nodeType', type: 'uint8'},
            {name: 'nodeKey', type: 'bytes32'},
            {name: 'config', type: 'string'},
        ]
    },
    primaryType: 'EIP712NodePair',
    domain: {
        name: 'XBR',
        version: '1'
    },
    message: null
};


function sign_pair_node(key_, data_) {
    EIP712NodePair['message'] = data_;
    var key = eth_util.toBuffer(key_);
    var sig = eth_sig_utils.signTypedData(key, {data: EIP712NodePair});
    return sig;
}


contract('XBRNetwork', accounts => {

    //const gasLimit = 6721975;
    const gasLimit = 0xfffffffffff;
    //const gasLimit = 100000000;

    // deployed instance of XBRNetwork
    var network;

    // deployed instance of XBRToken
    var token;

    // deployed instance of XBRDomain
    var domain;

    var chainId;
    var verifyingContract;

    // enum MemberLevel { NULL, ACTIVE, VERIFIED, RETIRED, PENALTY, BLOCKED }
    const MemberLevel_NULL = 0;
    const MemberLevel_ACTIVE = 1;
    const MemberLevel_VERIFIED = 2;
    const MemberLevel_RETIRED = 3;
    const MemberLevel_PENALTY = 4;
    const MemberLevel_BLOCKED = 5;

    // enum DomainStatus { NULL, ACTIVE, CLOSED }
    const DomainStatus_NULL = 0;
    const DomainStatus_ACTIVE = 1;
    const DomainStatus_CLOSED = 2;

    // enum ActorType { NULL, PROVIDER, CONSUMER, PROVIDER_CONSUMER }
    const ActorType_NULL = 0;
    const ActorType_PROVIDER = 1;
    const ActorType_CONSUMER = 2;
    const ActorType_PROVIDER_CONSUMER = 3;

    // enum NodeType { NULL, MASTER, CORE, EDGE }
    const NodeType_NULL = 0;
    const NodeType_MASTER = 1;
    const NodeType_CORE = 2;
    const NodeType_EDGE = 3;

    // the XBR Project
    const owner = accounts[0];

    // 2 test XBR market owners
    const alice = accounts[1];
    const alice_market_maker1 = accounts[2];

    const bob = accounts[3];
    const bob_market_maker1 = accounts[4];

    // 2 test XBR data providers
    const charlie = accounts[5];
    const charlie_provider_delegate1 = accounts[6];

    const donald = accounts[7];
    const donald_provider_delegate1 = accounts[8];

    // 2 test XBR data consumers
    const edith = accounts[9];
    const edith_provider_delegate1 = accounts[10];

    const frank = accounts[11];
    const frank_provider_delegate1 = accounts[12];

    beforeEach('setup contract for each test', async function () {
        token = await XBRToken.deployed();
        network = await XBRNetwork.deployed();
        domain = await XBRDomain.deployed();

        chainId = await network.verifyingChain();
        verifyingContract = await network.verifyingContract();

        const eula = await network.eula();
        const profile = "QmQMtxYtLQkirCsVmc3YSTFQWXHkwcASMnu5msezGEwHLT";

        const _alice = await network.members(alice);
        const _alice_level = _alice.level.toNumber();
        if (_alice_level == MemberLevel_NULL) {
            await network.registerMember(eula, profile, {from: alice, gasLimit: gasLimit});
        }

        const _charlie = await network.members(charlie);
        const _charlie_level = _charlie.level.toNumber();
        if (_charlie_level == MemberLevel_NULL) {
            await network.registerMember(eula, profile, {from: charlie, gasLimit: gasLimit});
        }
    });

    it('XBRDomain.createDomain() : should create new domain', async () => {

        const domainId = utils.sha3("MyDomain1").substring(0, 34);

        const license = await domain.license();
        const terms = "QmcAuALHaH9pxJP9bzo7go8QU9xUraSozBNVynRs81hpqr";
        const meta = "Qmaa4Rw81a3a1VEx4LxB7HADUAXvZFhCoRdBzsMZyZmqHD";

        const domainKey = '0x810e817f420772877eaacb38b77e2054f41378f629067acfebdbd696d7b3bc46';

        const domainSeq_before = await domain.domainSeq();

        await domain.createDomain(domainId, domainKey, license, terms, meta, {from: alice, gasLimit: gasLimit});

        //const domainSeq_after = await domain.domainSeq();
        //assert(domainSeq_after.eq(domainSeq_before.add(new BN(1))), "domain sequence not incremented");

        // const domain_ = await domain.domains(domainId);
        // assert(domain_.created.gt(1), "wrong created attribute in domain");
        // assert(domain_.seq.eq(domainSeq_before), "wrong seq attribute in domain");
        // assert.equal(domain_.status, DomainStatus_ACTIVE, "wrong status attribute in domain");
        // assert.equal(domain_.owner, alice, "wrong owner attribute in domain");
        // assert.equal(domain_.key, domainKey, "wrong key attribute in domain");
        // assert.equal(domain_.license, license, "wrong license attribute in domain");
        // assert.equal(domain_.terms, terms, "wrong terms attribute in domain");
        // assert.equal(domain_.meta, meta, "wrong meta attribute in domain");
        // assert.equal(domain_.signature, null, "wrong signature attribute in domain");
    });

    it('XBRDomain.createDomainFor() : should create new domain', async () => {

        const domainId = utils.sha3("MyDomain2").substring(0, 34);

        // charlie = accounts[5]
        const member = w3_utils.toChecksumAddress('0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC');
        const member_key = '0x395df67f0c2d2d9fe1ad08d1bc8b6627011959b79c53d7dd6a3536a33ab8a4fd';

        const created = await web3.eth.getBlockNumber();

        const license = await domain.license();
        const terms = "QmcAuALHaH9pxJP9bzo7go8QU9xUraSozBNVynRs81hpqr";
        const meta = "Qmaa4Rw81a3a1VEx4LxB7HADUAXvZFhCoRdBzsMZyZmqHD";

        const domainKey = '0x810e817f420772877eaacb38b77e2054f41378f629067acfebdbd696d7b3bc46';

        const domainSeq_before = await domain.domainSeq();

        const msg = {
            'chainId': chainId,
            'verifyingContract': verifyingContract,
            'member': member,
            'created': created,
            'domainId': domainId,
            'domainKey': domainKey,
            'license': license,
            'terms': terms,
            'meta': meta,
        }
        const signature = sign_create_domain(member_key, msg);

        await domain.createDomainFor(member, created, domainId, domainKey, license,
            terms, meta, signature, {from: alice, gasLimit: gasLimit});

        const domainSeq_after = await domain.domainSeq();
        assert(domainSeq_after.eq(domainSeq_before.add(new BN(1))), "domain sequence not incremented");

        const domain_ = await domain.domains(domainId);
        assert(domain_.created.gt(1), "wrong created attribute in domain");
        assert(domain_.seq.eq(domainSeq_before), "wrong seq attribute in domain");
        assert.equal(domain_.status, DomainStatus_ACTIVE, "wrong status attribute in domain");
        assert.equal(domain_.owner, member, "wrong owner attribute in domain");
        assert.equal(domain_.key, domainKey, "wrong key attribute in domain");
        assert.equal(domain_.license, license, "wrong license attribute in domain");
        assert.equal(domain_.terms, terms, "wrong terms attribute in domain");
        assert.equal(domain_.meta, meta, "wrong meta attribute in domain");
        assert.equal(domain_.signature, signature, "wrong signature attribute in domain");
    });

    it('XBRDomain.pairNode() : should pair new node', async () => {

        const domainId = utils.sha3("MyDomain1").substring(0, 34);
        const nodeId = utils.sha3("MyNode1").substring(0, 34);

        const nodeType = NodeType_EDGE;
        const nodeKey = '0xbae3cb9f8d280a5d7a945c0ac3407f22290778fb470b4220e3667559100c12da';
        const config = 'QmQ5JFWUMNhDGLigbqzWkJxJiB3mKRgT8L99pq7tx6ypKW';

        const paired = await web3.eth.getBlockNumber();

        await domain.pairNode(nodeId, domainId, nodeType, nodeKey, config, {from: alice, gasLimit: gasLimit});

        const node_ = await domain.nodes(nodeId);

        assert(node_.paired.gte(paired), "wrong paired attribute in node");
        assert.equal(node_.domain, domainId, "wrong domain attribute in node");
        assert.equal(node_.nodeType, NodeType_EDGE, "wrong nodeType attribute in node");
        assert.equal(node_.key, nodeKey, "wrong key attribute in node");
        assert.equal(node_.config, config, "wrong config attribute in node");
        assert.equal(node_.signature, null, "wrong signature attribute in node");
    });

    it('XBRDomain.pairNodeFor() : should pair new node', async () => {

        const domainId = utils.sha3("MyDomain2").substring(0, 34);
        const nodeId = utils.sha3("MyNode2").substring(0, 34);

        // charlie = accounts[5]
        const member = w3_utils.toChecksumAddress('0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC');
        const member_key = '0x395df67f0c2d2d9fe1ad08d1bc8b6627011959b79c53d7dd6a3536a33ab8a4fd';

        const paired = await web3.eth.getBlockNumber();

        const nodeType = NodeType_EDGE;
        const nodeKey = '0xba1a0068a4c49c7a764cd5b1b553f6cef0a81573b9eeb6a6d3f753dc9b93f728';
        const config = 'QmQ5JFWUMNhDGLigbqzWkJxJiB3mKRgT8L99pq7tx6ypKW';

        const msg = {
            'chainId': chainId,
            'verifyingContract': verifyingContract,
            'member': member,
            'paired': paired,
            'nodeId': nodeId,
            'domainId': domainId,
            'nodeType': nodeType,
            'nodeKey': nodeKey,
            'config': config,
        }
        const signature = sign_pair_node(member_key, msg);

        await domain.pairNodeFor(member, paired, nodeId, domainId, nodeType,
                nodeKey, config, signature, {from: alice, gasLimit: gasLimit});

        const node_ = await domain.nodes(nodeId);

        assert(node_.paired.gte(paired), "wrong paired attribute in node");
        assert.equal(node_.domain, domainId, "wrong domain attribute in node");
        assert.equal(node_.nodeType, NodeType_EDGE, "wrong nodeType attribute in node");
        assert.equal(node_.key, nodeKey, "wrong key attribute in node");
        assert.equal(node_.config, config, "wrong config attribute in node");
        assert.equal(node_.signature, signature, "wrong signature attribute in node");
    });
});
