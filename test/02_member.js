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

const w3_utils = require("web3-utils");
const eth_sig_utils = require("eth-sig-util");
const eth_util = require("ethereumjs-util");
const BN = require('bn.js');

const XBRNetwork = artifacts.require("./XBRNetwork.sol");
const XBRToken = artifacts.require("./XBRToken.sol");


const DomainData = {
    types: {
        EIP712Domain: [
            {name: 'name', type: 'string' },
            {name: 'version', type: 'string' },
        ],
        EIP712MemberRegister: [
            {name: 'chainId', type: 'uint256'},
            {name: 'verifyingContract', type: 'address'},
            {name: 'member', type: 'address'},
            {name: 'registered', type: 'uint256'},
            {name: 'eula', type: 'string'},
            {name: 'profile', type: 'string'},
        ]
    },
    primaryType: 'EIP712MemberRegister',
    domain: {
        name: 'XBR',
        version: '1',
    },
    message: null
};



function create_sig(key_, data_) {
    DomainData['message'] = data_;
    var key = eth_util.toBuffer(key_);
    var sig = eth_sig_utils.signTypedData(key, {data: DomainData})
    return sig;
}


contract('XBRNetwork', accounts => {

    //const gasLimit = 6721975;
    const gasLimit = 0xfffffffffff;
    //const gasLimit = 100000000;

    // deployed instance of XBRNetwork
    var network;

    // deployed instance of XBRNetwork
    var token;

    var chainId;
    var verifyingContract;

    // https://solidity.readthedocs.io/en/latest/frequently-asked-questions.html#if-i-return-an-enum-i-only-get-integer-values-in-web3-js-how-to-get-the-named-values

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

    // enum ActorType { NULL, NETWORK, MARKET, PROVIDER, CONSUMER }
    const ActorType_NULL = 0;
    const ActorType_NETWORK = 1;
    const ActorType_MARKET = 2;
    const ActorType_PROVIDER = 3;
    const ActorType_CONSUMER = 4;

    // enum NodeType { NULL, MASTER, CORE, EDGE }
    const NodeType_NULL = 0;
    const NodeType_MASTER = 1;
    const NodeType_CORE = 2;
    const NodeType_EDGE = 3;

    //
    // test accounts setup
    //
    const owner = accounts[0];
    const alice = accounts[1];
    const alice_market_maker1 = accounts[2];
    const bob = accounts[3];
    const bob_delegate1 = accounts[4];
    const charlie = accounts[5];
    const charlie_delegate1 = accounts[6];
    const donald = accounts[7];
    const donald_delegate1 = accounts[8];
    const edith = accounts[9];
    const edith_delegate1 = accounts[10];
    const frank = accounts[11];
    const frank_delegate1 = accounts[12];

    beforeEach('setup contract for each test', async function () {
        network = await XBRNetwork.deployed();
        token = await XBRToken.deployed();

        console.log('Using XBRNetwork         : ' + network.address);
        console.log('Using XBRToken           : ' + token.address);

        // FIXME: none of the following works on Ganache v6.9.1 ..

        // TypeError: Cannot read property 'getChainId' of undefined
        // https://web3js.readthedocs.io/en/v1.2.6/web3-eth.html#getchainid
        // const _chainId1 = await web3.eth.getChainId();

        // DEBUG: _chainId2 undefined
        // const _chainId2 = web3.version.network;
        // console.log('DEBUG: _chainId2', _chainId2);

        chainId = await network.verifyingChain();
        verifyingContract = await network.verifyingContract();
        contribution = await network.contribution();
        organization = await network.organization();

        console.log('Using chainId            : ' + chainId);
        console.log('Using verifyingContract  : ' + verifyingContract);
        console.log('Using contribution       : ' + contribution);
        console.log('Using organization       : ' + organization);
    });

    /*
    afterEach(function (done) {
    });
    */

    /*
    FIXME: making the organization member (of type address) public breaks deployment: "out of gas"
    it('XBRNetwork() : network organization should be the owner', async () => {
        const _organization = await network.organization();

        assert.equal(_organization, owner, "network organization was initialized correctly");
    });
    */

    it('XBRNetwork() : token should be the network token', async () => {
        const _token = await network.token();

        console.log("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX: " + _token);

        assert.equal(_token, token.address, "network token was initialized correctly");
    });

    it('XBRNetwork() : owner account should be initially registered', async () => {

        const _owner = await network.members(owner);
        const _level = _owner.level.toNumber();

        assert.equal(_level, MemberLevel_VERIFIED, "wrong member level");
    });

    it('XBRNetwork() : non-owner accounts should be initially unregistered', async () => {

        const _alice = await network.members(alice);
        const _alice_level = _alice.level.toNumber();
        assert.equal(_alice_level, MemberLevel_NULL, "wrong member level " + _alice_level);

        const _bob = await network.members(bob);
        const _bob_level = _bob.level.toNumber();
        assert.equal(_bob_level, MemberLevel_NULL, "wrong member level " + _bob_level);

        const _charlie = await network.members(charlie);
        const _charlie_level = _charlie.level.toNumber();
        assert.equal(_charlie_level, MemberLevel_NULL, "wrong member level " + _charlie_level);

        const _donald = await network.members(donald);
        const _donald_level = _donald.level.toNumber();
        assert.equal(_donald_level, MemberLevel_NULL, "wrong member level " + _donald_level);

        const _edith = await network.members(edith);
        const _edith_level = _edith.level.toNumber();
        assert.equal(_edith_level, MemberLevel_NULL, "wrong member level " + _edith_level);

        /*
        const _frank = await network.members(frank);
        const _frank_level = _frank.level.toNumber();
        assert.equal(_frank_level, MemberLevel_NULL, "wrong member level " + _frank_level);
        */
    });

    it('XBRNetwork.registerMember() : registering a member with wrong EULA should throw', async () => {

        const eula = "invalid";
        const profile = "foobar";

        try {
            await network.registerMember(eula, profile, {from: alice, gasLimit: gasLimit});
            assert(false, "contract should throw here");
        } catch (error) {
            assert(/INVALID_EULA/.test(error), "wrong error message: " + error);
        }
    });

    it('XBRNetwork.registerMember() : should create new member with the correct attributes stored, and firing correct event', async () => {

        const eula = await network.eula();
        const profile = "QmQMtxYtLQkirCsVmc3YSTFQWXHkwcASMnu5msezGEwHLT";

        const txn = await network.registerMember(eula, profile, {from: alice, gasLimit: gasLimit});

        const _alice = await network.members(alice);
        const _alice_eula = _alice.eula;
        const _alice_profile = _alice.profile;
        const _alice_level = _alice.level.toNumber();

        assert.equal(_alice_level, MemberLevel_ACTIVE, "wrong member level");
        assert.equal(_alice_eula, eula, "wrong member EULA");
        assert.equal(_alice_profile, profile, "wrong member Profile");

        // check event logs
        assert.equal(txn.receipt.logs.length, 1, "event(s) we expected not emitted");
        const result = txn.receipt.logs[0];

        // check events
        assert.equal(result.event, "MemberRegistered", "wrong event was emitted");
        assert.equal(result.args.member, alice, "wrong member address in event");
        assert.equal(result.args.eula, eula, "wrong member EULA in event");
        assert.equal(result.args.profile, profile, "wrong member Profile in event");
        assert.equal(result.args.level, MemberLevel_ACTIVE, "wrong member level in event");
    });

    it('XBRNetwork.registerMember() : registering a member twice should throw', async () => {

        const eula = await network.eula();
        const profile = "";

        try {
            await network.registerMember(eula, profile, {from: alice, gasLimit: gasLimit});
            assert(false, "contract should throw here");
        } catch (error) {
            assert(/MEMBER_ALREADY_REGISTERED/.test(error), "wrong error message: " + JSON.stringify(error));
        }
    });

    it('XBRNetwork.registerMemberFor() : delegated transaction should create new member with the correct attributes stored, and firing correct event', async () => {

        //const member = accounts[5].address;
        //const member_key = accounts[5].privateKey;

        //const member = w3_utils.toChecksumAddress('0x3e5e9111ae8eb78fe1cc3bb8915d5d461f3ef9a9');
        //const member_key = '0xe485d098507f54e7733a205420dfddbe58db035fa577fc294ebd14db90767a52';

        const member = w3_utils.toChecksumAddress('0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC');
        const member_key = '0x395df67f0c2d2d9fe1ad08d1bc8b6627011959b79c53d7dd6a3536a33ab8a4fd';

        const registered = await web3.eth.getBlockNumber();
        const eula = await network.eula();
        const profile = "QmQMtxYtLQkirCsVmc3YSTFQWXHkwcASMnu5msezGEwHLT";

        // console.log('XBRNetwork.registerMemberFor(): member=' + member + ', member_key=' + member_key);

        const msg = {
            'chainId': chainId,
            'verifyingContract': verifyingContract,
            'member': member,
            'registered': registered,
            'eula': eula,
            'profile': profile,
        }
        console.log('MESSAGE', msg);

        const signature = create_sig(member_key, msg);
        console.log('SIGNATURE', signature);

        const txn = await network.registerMemberFor(member, registered, eula, profile, signature, {from: alice, gasLimit: gasLimit});

        const _member = await network.members(member);
        const _member_eula = _member.eula;
        const _member_profile = _member.profile;
        const _member_level = _member.level.toNumber();

        assert.equal(_member_level, MemberLevel_ACTIVE, "wrong member level");
        assert.equal(_member_eula, eula, "wrong member EULA");
        assert.equal(_member_profile, profile, "wrong member Profile");

        // check event logs
        assert.equal(txn.receipt.logs.length, 1, "event(s) we expected not emitted");
        const result = txn.receipt.logs[0];

        // check events
        assert.equal(result.event, "MemberRegistered", "wrong event was emitted");
        assert.equal(result.args.member, member, "wrong member address in event");
        assert.equal(result.args.eula, eula, "wrong member EULA in event");
        assert.equal(result.args.profile, profile, "wrong member Profile in event");
        assert.equal(result.args.level, MemberLevel_ACTIVE, "wrong member level in event");
    });
});
