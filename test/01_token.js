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

const BN = web3.utils.BN;
const XBRToken = artifacts.require("./XBRToken.sol");


const eip712ApprovalTypedData = {
    types: {
        EIP712Domain: [
            {name: 'name', type: 'string' },
            {name: 'version', type: 'string' },
        ],
        EIP712Approve: [
            {name: 'chainId', type: 'uint256' },
            {name: 'verifyingContract', type: 'address' },
            {name: 'sender', type: 'address'},
            {name: 'relayer', type: 'address'},
            {name: 'spender', type: 'address'},
            {name: 'amount', type: 'uint256'},
            {name: 'expires', type: 'uint256'},
            {name: 'nonce', type: 'uint256'},
        ]
    },
    primaryType: 'EIP712Approve',
    domain: {
        name: 'XBR',
        version: '1',
    },
    message: null
};


function eip712_sign_approval(key_, data_, verifyingContract) {
    eip712ApprovalTypedData['message'] = data_;
    eip712ApprovalTypedData['domain']['verifyingContract'] = verifyingContract;
    var key = eth_util.toBuffer(key_);
    var sig = eth_sig_utils.signTypedData(key, {data: eip712ApprovalTypedData})
    return sig;
}


contract('XBRToken', function (accounts) {

    //const gasLimit = 6721975;
    const gasLimit = 0xfffffffffff;
    //const gasLimit = 100000000;

    XBR_TOTAL_SUPPLY = 10**9 * 10**18;
    const total_supply = new BN('1000000000000000000000000000');

    // deployed instance of XBRNetwork
    var token;

    beforeEach('setup contract for each test', async function () {
        token = await XBRToken.deployed();
    });

    it("XBRToken() : should have produced the right initial supply of XBRToken", async () => {
        const supply = await token.totalSupply();
        assert.equal(supply.valueOf(), XBR_TOTAL_SUPPLY, "Wrong initial/total supply for token");
    });

    it("XBRToken() : should initially put all XBRToken in the first account", async () => {
        const balance = await token.balanceOf(accounts[0]);
        assert.equal(balance.valueOf(), XBR_TOTAL_SUPPLY, "Initial supply wasn't allocated to the first account");
    });

    it("XBRToken() : should have correct constants set", async () => {
        const verifyingChain = await token.verifyingChain();
        const verifyingContract = await token.verifyingContract();
        const INITIAL_SUPPLY = await token.INITIAL_SUPPLY();

        console.log('verifyingChain', verifyingChain);
        console.log('verifyingContract', verifyingContract);
        console.log('INITIAL_SUPPLY', INITIAL_SUPPLY);

        assert.equal(verifyingChain.valueOf(), 1, "verifyingChain incorrect");
        assert.equal(INITIAL_SUPPLY.valueOf(), XBR_TOTAL_SUPPLY, "INITIAL_SUPPLY incorrect");
    });

    it("XBRToken.transfer() should correctly update token balances", async () => {
        // 1 million XBR
        const amount = new BN('100000000000000');

        const acct0_before = await token.balanceOf(accounts[0]);
        const acct1_before = await token.balanceOf(accounts[1]);

        // transfer the tokens (send tx from account[0]) in one go
        const res = await token.transfer(accounts[1], amount, {from: accounts[0], gasLimit: gasLimit});

        // console.log(res);
        // const res_tx = await utils.mine_tx(res.tx);
        // console.log(res_tx);

        const acct0_after = await token.balanceOf(accounts[0]);
        const acct1_after = await token.balanceOf(accounts[1]);

        assert(amount.eq(acct0_before.sub(acct0_after)), "invalid balance for account[0] after transaction");
        assert(amount.eq(acct1_after.sub(acct1_before)), "invalid balance for account[1] after transaction");
    });

    it("XBRToken.approve()+transferFrom() should correctly update token balances", async () => {
        // 1 million XBR
        const amount = new BN('100000000000000');

        const acct0_before = await token.balanceOf(accounts[0]);
        const acct1_before = await token.balanceOf(accounts[1]);

        // tx 1: approve transfer of tokens (send tx from account[0])
        await token.approve(accounts[1], amount, {from: accounts[0], gasLimit: gasLimit});

        // tx 2: actually transfer the tokens (send tx from account[1])
        await token.transferFrom(accounts[0], accounts[1], amount, {from: accounts[1], gasLimit: gasLimit});

        const acct0_after = await token.balanceOf(accounts[0]);
        const acct1_after = await token.balanceOf(accounts[1]);

        assert(amount.eq(acct0_before.sub(acct0_after)), "invalid balance for account[0] after transaction");
        assert(amount.eq(acct1_after.sub(acct1_before)), "invalid balance for account[1] after transaction");
    });

    it("XBRToken().approveForVerify() : should verify correct signature", async () => {

        const chainId = await token.verifyingChain();
        const verifyingContract = await token.verifyingContract();

        // const sender = accounts[0];
        const sender = w3_utils.toChecksumAddress('0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1');
        const sender_key = '0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d';

        // const spender = accounts[1];
        const spender = w3_utils.toChecksumAddress('0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0');

        // const relayer = accounts[2];
        const relayer = w3_utils.toChecksumAddress('0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b');
        // const relayer = w3_utils.toChecksumAddress('0x0000000000000000000000000000000000000000');

        // 1 million XBR
        const amount = new BN('100000000000000');
        const expires = 0;
        const nonce = 1;

        const approval = {
            'sender': sender,
            'relayer': relayer,
            'spender': spender,
            'amount': amount,
            'expires': expires,
            'nonce': nonce,
        }
        console.log('MESSAGE', sender_key, approval, verifyingContract);

        // prepare: pre-sign metatransaction
        // const signature = '0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';
        const signature = eip712_sign_approval(sender_key, approval, verifyingContract);
        console.log('SIGNATURE', signature);

        try {
            console.log('token.approveForVerify', sender, relayer, spender, amount, expires, nonce, signature);
            const result = await token.approveForVerify(sender, relayer, spender, amount, expires, nonce, signature, {from: relayer, gasLimit: gasLimit});
            console.log('XBRToken.approveForVerify(): 1)', result);
            //assert(result, "valid signature should verify successfully");
        } catch (error) {
            console.log('XBRToken.approveForVerify(): 2)', error);
            //assert(false, "contract should not throw here");
        }
    });

    /*
    it("XBRToken.approveFor() should fail for invalid signature", async () => {

        const chainId = await token.verifyingChain();
        const verifyingContract = await token.verifyingContract();

        // const sender = accounts[0];
        const sender = w3_utils.toChecksumAddress('0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1');
        const sender_bogus = w3_utils.toChecksumAddress('0x6666666666666666666666666666666666666666');
        const sender_key = '0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d';

        // const spender = accounts[1];
        const spender = w3_utils.toChecksumAddress('0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0');

        // const relayer = accounts[2];
        const relayer = w3_utils.toChecksumAddress('0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b');

        // 1 million XBR
        const amount = new BN('100000000000000');
        const expires = 0;
        const nonce = 1;

        const sender_before = await token.balanceOf(sender);
        const spender_before = await token.balanceOf(spender);

        const approval = {
            'sender': sender,
            'relayer': relayer,
            'spender': spender,
            'amount': amount,
            'expires': expires,
            'nonce': nonce,
        }
        console.log('MESSAGE', approval);

        // prepare: pre-sign metatransaction
        // const signature = '0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';
        const signature = eip712_sign_approval(sender_key, approval, verifyingContract);

        console.log('SIGNATURE', signature);

        try {
            // tx 1: submit pre-signed transaction approving transfer of tokens (send tx from relayer)
            await token.approveFor(sender_bogus, relayer, spender, amount, expires, nonce, signature, {from: relayer, gasLimit: gasLimit});
            console.log('XBRToken.approveFor(): 1)');
            assert(false, "contract should throw here");
        } catch (error) {
            console.log('XBRToken.approveFor(): 2)', error);
            assert(/INVALID_SIGNATURE/.test(error), "wrong error message: " + JSON.stringify(error));

            const sender_after = await token.balanceOf(sender);
            const spender_after = await token.balanceOf(spender);

            console.log(sender_before, sender_after);
            console.log(spender_before, spender_after);

            assert(sender_before.eq(sender_after), "invalid balance for sender after transaction");
            assert(spender_before.eq(spender_after), "invalid balance for spender after transaction");
        }
    });
*/
/*
    it("XBRToken.approveFor()+transferFrom() should correctly update token balances", async () => {

        const chainId = await token.verifyingChain();
        const verifyingContract = await token.verifyingContract();

        // const sender = accounts[0];
        const sender = w3_utils.toChecksumAddress('0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1');
        const sender_key = '0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d';

        // const spender = accounts[1];
        const spender = w3_utils.toChecksumAddress('0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0');

        // const relayer = accounts[2];
        const relayer = w3_utils.toChecksumAddress('0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b');
        // const relayer = w3_utils.toChecksumAddress('0x0000000000000000000000000000000000000000');

        // 1 million XBR
        const amount = new BN('100000000000000');
        const expires = 0;
        const nonce = 1;

        const sender_before = await token.balanceOf(sender);
        const spender_before = await token.balanceOf(spender);

        const approval = {
            'sender': sender,
            'relayer': relayer,
            'spender': spender,
            'amount': amount,
            'expires': expires,
            'nonce': nonce,
        }
        console.log('MESSAGE', sender_key, approval, verifyingContract);

        // prepare: pre-sign metatransaction
        // const signature = '0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';
        const signature = eip712_sign_approval(sender_key, approval, verifyingContract);
        console.log('SIGNATURE', signature);

        try {
            console.log('token.approveFor', sender, relayer, spender, amount, expires, nonce, signature);

            // tx 1: submit pre-signed transaction approving transfer of tokens (send tx from relayer)
            await token.approveFor(sender, relayer, spender, amount, expires, nonce, signature, {from: relayer, gasLimit: gasLimit});
            console.log('XBRToken.approveFor()+transferFrom(): 1)');
        } catch (error) {
            console.log('XBRToken.approveFor()+transferFrom(): 2)', error);
            // assert(false, "contract should not throw here");
        }

        // tx 2: actually transfer the tokens (send tx from spender)
        await token.transferFrom(sender, spender, amount, {from: spender, gasLimit: gasLimit});

        const sender_after = await token.balanceOf(sender);
        const spender_after = await token.balanceOf(spender);

        assert(amount.eq(sender_before.sub(sender_after)), "invalid balance for sender after transaction");
        assert(amount.eq(spender_after.sub(spender_before)), "invalid balance for spender after transaction");
    });
*/
/*
    it("XBRToken.approveFor()+burnSignature() should correctly render the signature unusable", async () => {

        const chainId = await token.verifyingChain();
        const verifyingContract = await token.verifyingContract();

        // const sender = accounts[0];
        const sender = w3_utils.toChecksumAddress('0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1');
        const sender_key = '0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d';

        // const spender = accounts[1];
        const spender = w3_utils.toChecksumAddress('0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0');

        // const relayer = accounts[2];
        const relayer = w3_utils.toChecksumAddress('0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b');

        // 1 million XBR
        const amount = new BN('100000000000000');
        const expires = 0;
        const nonce = 2;

        const sender_before = await token.balanceOf(sender);
        const spender_before = await token.balanceOf(spender);

        const approval = {
            'sender': sender,
            'relayer': relayer,
            'spender': spender,
            'amount': amount,
            'expires': expires,
            'nonce': nonce,
        }
        console.log('MESSAGE', approval);

        // prepare: pre-sign metatransaction
        // const signature = '0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';
        const signature = eip712_sign_approval(sender_key, approval, verifyingContract);
        console.log('SIGNATURE', signature);

        // now burn the signature before it is used
        await token.burnSignature(sender, relayer, spender, amount, expires, nonce, signature, {from: sender, gasLimit: gasLimit});

        try {
            // tx 1: submit pre-signed transaction approving transfer of tokens (send tx from relayer)
            await token.approveFor(sender, relayer, spender, amount, expires, nonce, signature, {from: relayer, gasLimit: gasLimit});
            console.log('XBRToken.approveFor()+burnSignature(): 1)');
            assert(false, "contract should throw here");
        } catch (error) {
            console.log('XBRToken.approveFor()+burnSignature(): 2)', error);
            assert(/SIGNATURE_REUSED/.test(error), "wrong error message: " + JSON.stringify(error));

            const sender_after = await token.balanceOf(sender);
            const spender_after = await token.balanceOf(spender);

            assert(sender_before.eq(sender_after), "invalid balance for sender after transaction");
            assert(spender_before.eq(spender_after), "invalid balance for spender after transaction");
        }
    });
*/
});
