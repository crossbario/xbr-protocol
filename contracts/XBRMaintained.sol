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

// normally, we would import "@openzeppelin/contracts", but we want to use
// upgradeable contracts, and hence must use upgradeable flavor for imports
// from "@openzeppelin/contracts-ethereum-package"
// https://docs.openzeppelin.com/learn/developing-smart-contracts#importing_openzeppelin_contracts
// https://docs.openzeppelin.com/cli/2.8/dependencies#linking-the-contracts-ethereum-package
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
// import "openzeppelin-solidity/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";


/**
 * XBR Network (and XBR Network Proxies) SCs inherit from this base contract
 * to manage network administration and maintenance via Role-based Access
 * Control (RBAC).
 * The implementation for management comes from the OpenZeppelin RBAC library.
 */
contract XBRMaintained is Initializable, AccessControlUpgradeSafe {

    // Create a new role identifier for the minter role
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    /**
     * Event fired when a maintainer was added.
     *
     * @param account The account that was added as a maintainer.
     */
    event MaintainerAdded(address indexed account);

    /**
     * Event fired when a maintainer was removed.
     *
     * @param account The account that was removed as a maintainer.
     */
    event MaintainerRemoved(address indexed account);

    /// The constructor is internal (roles are managed by the OpenZeppelin base class).
    // function initialize () internal initializer {
    function initialize () public initializer {
        // https://forum.openzeppelin.com/t/how-to-use-ownable-with-upgradeable-contract/3336/4
        // https://github.com/OpenZeppelin/openzeppelin-contracts-ethereum-package/blob/32e1c6f564a14e5404012ceb59d605cdb82112c6/contracts/access/AccessControl.sol#L40
        __Context_init_unchained();
        __AccessControl_init_unchained();

        _setupRole(MAINTAINER_ROLE, msg.sender);
    }

    /**
     * Modifier to require maintainer-role for the sender when calling a SC.
     */
    modifier onlyMaintainer () {
        require(isMaintainer(msg.sender));
        _;
    }

    /**
     * Check if the given address is currently a maintainer.
     *
     * @param account The account to check.
     * @return `true` if the account is maintainer, otherwise `false`.
     */
    function isMaintainer (address account) public view returns (bool) {
        return hasRole(MAINTAINER_ROLE, account);
    }

    /**
     * Add a new maintainer to the list of maintainers.
     *
     * @param account The account to grant maintainer rights to.
     */
    function addMaintainer (address account) public onlyMaintainer {
        _addMaintainer(account);
    }

    /**
     * Give away maintainer rights.
     */
    function renounceMaintainer () public {
        _removeMaintainer(msg.sender);
    }

    function _addMaintainer (address account) internal {
        grantRole(MAINTAINER_ROLE, account);
        emit MaintainerAdded(account);
    }

    function _removeMaintainer (address account) internal {
        revokeRole(MAINTAINER_ROLE, account);
        emit MaintainerRemoved(account);
    }
}
