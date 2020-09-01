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

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";


contract XBRTest is Initializable {
    // Adapted from: https://github.com/ethereum/EIPs/blob/master/assets/eip-712/Example.sol

    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }

    struct Person {
        string name;
        address wallet;
    }

    struct Mail {
        Person from;
        Person to;
        string contents;
    }

    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 constant PERSON_TYPEHASH = keccak256(
        "Person(string name,address wallet)"
    );

    bytes32 constant MAIL_TYPEHASH = keccak256(
        "Mail(Person from,Person to,string contents)Person(string name,address wallet)"
    );

    bytes32 DOMAIN_SEPARATOR;

    function initialize () public initializer {
        DOMAIN_SEPARATOR = hash(EIP712Domain({
            name: "Ether Mail",
            version: "1",
            chainId: 1,
            // verifyingContract: this
            verifyingContract: 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC
        }));
    }

    function hash(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712DOMAIN_TYPEHASH,
            keccak256(bytes(eip712Domain.name)),
            keccak256(bytes(eip712Domain.version)),
            eip712Domain.chainId,
            eip712Domain.verifyingContract
        ));
    }

    function hash(Person memory person) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PERSON_TYPEHASH,
            keccak256(bytes(person.name)),
            person.wallet
        ));
    }

    function hash(Mail memory mail) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAIL_TYPEHASH,
            hash(mail.from),
            hash(mail.to),
            keccak256(bytes(mail.contents))
        ));
    }

    function verify(Mail memory mail, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        // Note: we need to use `encodePacked` here instead of `encode`.
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            hash(mail)
        ));
        return ecrecover(digest, v, r, s) == mail.from.wallet;
    }

    function splitSignature (bytes memory signature_rsv) private pure returns (uint8 v, bytes32 r, bytes32 s) {

        assembly {
            r := mload(add(signature_rsv, 32))
            s := mload(add(signature_rsv, 64))
            v := and(mload(add(signature_rsv, 65)), 255)
        }
        if (v < 27) {
            v += 27;
        }
        return (v, r, s);
    }

    function test_verify1(address signer, string memory from_name, address from_wallet, string memory to_name,
        address to_wallet, string memory contents, bytes memory sig_rsv) public view returns (bool) {

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig_rsv);

        Mail memory mail = Mail({
            from: Person({
                name: from_name,
                wallet: from_wallet
            }),
            to: Person({
                name: to_name,
                wallet: to_wallet
            }),
            contents: contents
        });

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            hash(mail)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    function test_verify2(address signer, string memory from_name, address from_wallet, string memory to_name,
        address to_wallet, string memory contents, uint8 v, bytes32 r, bytes32 s) public view returns (bool) {

        Mail memory mail = Mail({
            from: Person({
                name: from_name,
                wallet: from_wallet
            }),
            to: Person({
                name: to_name,
                wallet: to_wallet
            }),
            contents: contents
        });

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            hash(mail)
        ));

        return ecrecover(digest, v, r, s) == signer;
    }

    function test() public view returns (bool) {
        // Example signed message
        Mail memory mail = Mail({
            from: Person({
                name: "Cow",
                wallet: 0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826
            }),
            to: Person({
                name: "Bob",
                wallet: 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB
            }),
            contents: "Hello, Bob!"
        });
        uint8 v = 28;
        bytes32 r = 0x4355c47d63924e8a72e509b65029052eb6c299d53a04e167c5775fd466751c9d;
        bytes32 s = 0x07299936d304c153f6443dfa05f40ff007d72911b6f72307f996231605b91562;

        assert(DOMAIN_SEPARATOR == 0xf2cee375fa42b42143804025fc449deafd50cc031ca257e0b194a650a912090f);
        assert(hash(mail) == 0xc52c0ee5d84264471806290a3f2c4cecfc5490626bf912d01f240d7a274b371e);
        assert(verify(mail, v, r, s));
        return true;
    }

    function test2() public pure returns (bool) {
        return true;
    }
}
