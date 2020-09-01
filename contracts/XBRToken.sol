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

// normally, we would import "@openzeppelin/contracts", but we want to use
// upgradeable contracts, and hence must use upgradeable flavor for imports
// from "@openzeppelin/contracts-ethereum-package"
// https://docs.openzeppelin.com/learn/developing-smart-contracts#importing_openzeppelin_contracts
// https://docs.openzeppelin.com/cli/2.8/dependencies#linking-the-contracts-ethereum-package
// import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
// import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";

//import "./XBRTypes.sol";


interface IXBRTokenRelayInterface {
    function getRelayAuthority() external view returns (address);
}


/**
 * The `XBR Token <https://github.com/crossbario/xbr-protocol/blob/master/contracts/XBRToken.sol>`__
 * is a `ERC20 standard token <https://eips.ethereum.org/EIPS/eip-20>`__ defined by:
 *
 * * "XBR" as symbol
 * * fixed total supply of 10**9 ("one billion") XBR
 * * 18 decimals
 * * address (mainnet): tbd
 *
 * The XBR Token is using the (unmodified) `OpenZeppelin <https://openzeppelin.org/>`__
 * `reference implementation <https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol>`__
 * of the ERC20 token standard.
 *
 * For API documentation, please see `here <https://docs.openzeppelin.com/contracts/2.x/api/token/erc20>`__.
 */
contract XBRToken is Initializable, ERC20UpgradeSafe {

    /// EIP712 type for XBR as a type domain.
    struct EIP712Domain {
        /// The type domain name, makes signatures from different domains incompatible.
        string  name;

        /// The type domain version.
        string  version;
    }

    /// EIP712 Approve type data.
    struct EIP712ApproveTransfer {
        uint256 chainId;
        address verifyingContract;
        address sender;
        address relayer;
        address spender;
        uint256 amount;
        uint256 expires;
        uint256 nonce;
    }

    /// EIP712 type data.
    bytes32 public EIP712_DOMAIN_TYPEHASH;

    /// EIP712 type data.
    bytes32 public EIP712_APPROVE_TRANSFER_TYPEHASH;

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
    function splitSignature (bytes memory signature_rsv) public view returns (uint8 v, bytes32 r, bytes32 s) {
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

    function hash(EIP712Domain memory domain_) public view returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256(bytes(domain_.name)),
            keccak256(bytes(domain_.version))
        ));
    }

    function domainSeparator () public view returns (bytes32) {
        // makes signatures from different domains incompatible.
        // see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md#arbitrary-messages
        return hash(EIP712Domain({
            name: "XBR",
            version: "1"
        }));
    }

    function hash (EIP712ApproveTransfer memory obj) public view returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_APPROVE_TRANSFER_TYPEHASH,
            obj.chainId,
            obj.verifyingContract,
            obj.sender,
            obj.relayer,
            obj.spender,
            obj.amount,
            obj.expires,
            obj.nonce
        ));
    }

    /// Verifying chain ID for EIP712 signatures.
    uint256 public verifyingChain;

    /// Verifying contract address for EIP712 signatures.
    address public verifyingContract;

    /// The XBR Token has a fixed supply of 1 billion and uses 18 decimal digits.
    uint256 public INITIAL_SUPPLY;

    /// For pre-signed transactions ("approveFor"), track signatures already used.
    mapping(bytes32 => uint256) private burnedSignatures;

    /**
     * Constructor that gives ``msg.sender`` all of existing tokens.
     * The XBR Token uses the symbol "XBR" and 18 decimal digits.
     */
    function initialize () public initializer {
        // https://github.com/OpenZeppelin/openzeppelin-contracts-ethereum-package/blob/32e1c6f564a14e5404012ceb59d605cdb82112c6/contracts/token/ERC20/ERC20.sol#L57
        __Context_init_unchained();
        __ERC20_init_unchained("XBRToken", "XBR");

        // FIXME: read chain_id at run-time
        verifyingChain = 1;
        verifyingContract = address(this);

        EIP712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version)");
        EIP712_APPROVE_TRANSFER_TYPEHASH = keccak256("EIP712Approve(uint256 chainId,address verifyingContract,address sender,address relayer,address spender,uint256 amount,uint256 expires,uint256 nonce)");

        INITIAL_SUPPLY = 10**9 * 10**18;

        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /// Verify signature on typed data for transfering XBRToken.
    function verify (address signer, EIP712ApproveTransfer memory obj,
        bytes memory signature) public view returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator(),
            hash(obj)
        ));

        return ecrecover(digest, v, r, s) == signer;
        //return true;
    }

    function approveForVerify (address sender, address relayer, address spender, uint256 amount, uint256 expires,
        uint256 nonce, bytes memory signature) public view returns (bool) {

        EIP712ApproveTransfer memory approve = EIP712ApproveTransfer(verifyingChain, verifyingContract, sender, relayer, spender, amount, expires, nonce);

        // DOES work:
        //bool result = verify(sender, approve, signature);

        // does NOT work:
        bool result = verify(sender, approve, signature);

        return result;
    }

    /**
     * This method provides an extension to the standard ERC20 interface that allows to approve tokens
     * to be spent by another party or contract, similar to the standard `IERC20.approve` method.
     *
     * The difference is, that by using this method, the sender can pre-sign the approval off-chain, and
     * then let another party (the relayer) submit the transaction to the blockchain. Only the relayer
     * needs to have ETH to pay for gas, the off-chain sender does _not_ need any ETH.
     *
     * @param sender    The (off-chain) sender of tokens.
     * @param relayer   If given, the metatransaction can only be relayed from this address.
     * @param spender   The spender that will spend the tokens approved.
     * @param amount    Token amount to approve for the spender to spend.
     * @param expires   If given, the signature will expire at this block number.
     * @param nonce     Random nonce for metatransaction.
     * @param signature Signature over EIP712 data, signed by sender.
     */
/*
    function approveFor (address sender, address relayer, address spender, uint256 amount, uint256 expires,
        uint256 nonce, bytes memory signature) public returns (bool) {

        XBRTypes.EIP712ApproveTransfer memory approve = XBRTypes.EIP712ApproveTransfer(verifyingChain, verifyingContract, sender, relayer, spender, amount, expires, nonce);

        // signature must be valid (signed by address in parameter "sender" - not the necessarily
        // the "msg.sender", the submitted of the transaction!)
        // require(verify(sender, approve, signature), "INVALID_SIGNATURE");

        // relayer rules:
        //  1. always allow relaying if the specified "relayer" is 0
        //  2. if the authority address is not a contract, allow it to relay
        //  3. if the authority address is a contract, allow its defined 'getAuthority()' delegate to relay
        // require(
        //     (relayer == address(0x0)) ||
        //     (!XBRTypes.isContract(relayer) && msg.sender == relayer) ||
        //     (XBRTypes.isContract(relayer) && msg.sender == IXBRTokenRelayInterface(relayer).getRelayAuthority()),
        //     "INVALID_RELAYER"
        // );

        // signature must not have been expired
        require(block.number < expires || expires == 0, "SIGNATURE_EXPIRED");

        // signature must not have been used
        bytes32 digest = XBRTypes.hash(approve);
        require(burnedSignatures[digest] == 0x0, "SIGNATURE_REUSED");

        // mark signature as "consumed"
        burnedSignatures[digest] = 0x1;

        // now to the actual approval. also see "contracts/token/ERC20/ERC20.sol#L136"
        // here https://github.com/OpenZeppelin/openzeppelin-contracts
        _approve(sender, spender, amount);

        return true;
    }
*/
    /**
     * This method allows a sender that approved tokens via `approveFor` to burn the metatransaction
     * that was sent to the relayer - but only if the transaction has not yet been submitted by the relay.
     */
/*
    function burnSignature (address sender, address relayer, address spender, uint256 amount, uint256 expires,
        uint256 nonce, bytes memory signature) public returns (bool success) {

        XBRTypes.EIP712ApproveTransfer memory approve = XBRTypes.EIP712ApproveTransfer(verifyingChain, verifyingContract, sender, relayer, spender, amount, expires, nonce);

        // signature must be valid (signed by address in parameter "sender" - not the necessarily
        // the "msg.sender", the submitted of the transaction!)
        // require(verify(sender, approve, signature), "INVALID_SIGNATURE");

        // only the original signature creator can burn signature, not a relay
        require(sender == msg.sender);

        // signature must not have been used
        bytes32 digest = XBRTypes.hash(approve);
        require(burnedSignatures[digest] == 0x0, "SIGNATURE_REUSED");

        // mark signature as "burned"
        burnedSignatures[digest] = 0x2;

        return true;
    }
*/
}
