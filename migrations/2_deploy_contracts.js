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

// https://gist.github.com/oberstet/0cde635cd1067d3a84d426e4e18e61aa

// https://github.com/OpenZeppelin/openzeppelin-upgrades/blob/master/packages/plugin-truffle/README.md
const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const XBRTest = artifacts.require("./XBRTest.sol");
const XBRToken = artifacts.require("./XBRToken.sol");
const XBRNetwork = artifacts.require("./XBRNetwork.sol");
const XBRTypes = artifacts.require("./XBRTypes.sol");
const XBRDomain = artifacts.require("./XBRDomain.sol");
const XBRMarket = artifacts.require("./XBRMarket.sol");
const XBRCatalog = artifacts.require("./XBRCatalog.sol");
const XBRChannel = artifacts.require("./XBRChannel.sol");
// const XBRNetworkProxy = artifacts.require("./XBRNetworkProxy.sol");

// https://truffleframework.com/docs/truffle/getting-started/running-migrations#deployer
module.exports = function (deployer, network, accounts) {

    // https://etherscan.io/chart/gaslimit
    // https://www.rinkeby.io/#stats
    // https://ropsten.etherscan.io/blocks

    var gas;
    if (network === "soliditycoverage") {
        gas = 0xfffffffffff;
    } else {
        // the block gas limit on Rinkeby and Mainnet hovers _around_ 10m (!)
        // eg on Mainnet: Min. 9,955,619 - gas Max. 9,999,175 gas
        // so we use (10m - sth) as limit (not outright 10m)
        gas = 9950000;
        // gas = 10000000 - 100;
        // gas = 10000000;
    }

    const organization = accounts[0];
    console.log("Deploying contracts from " + organization + " with gas " + gas + " ..");

    deployer.then(async () => {
        //const existing1 = await XBRTypes.deployed();
        //const instance1 = await deployProxy(existing1.address, XBRTypes, { deployer });

        // https://github.com/OpenZeppelin/openzeppelin-upgrades#why-cant-i-use-custom-types-like-structs-and-enums
        // https://github.com/OpenZeppelin/openzeppelin-upgrades/blob/master/packages/plugin-truffle/README.md#deployproxy
        const types_instance = await deployProxy(XBRTypes, [], { deployer, unsafeAllowCustomTypes: true });
        console.log('>>>> XBRTypes deployed at ' + types_instance.address);

        //await deployer.deploy(XBRTypes);
        //console.log('>>>> XBRTypes deployed at ' + XBRTypes.address);

        await deployer.link(XBRTypes, XBRToken);
        const token_instance = await deployProxy(XBRToken, [], { deployer, unsafeAllowCustomTypes: true });
        console.log('>>>> XBRToken deployed at ' + token_instance.address);

        //await deployer.link(XBRTypes, XBRToken);
        //await deployer.deploy(XBRToken, {gas: gas, from: organization});

        await deployer.link(XBRTypes, XBRNetwork);
        const network_instance = await deployProxy(XBRNetwork, [token_instance.address, organization], { deployer, unsafeAllowCustomTypes: true });
        console.log('>>>> XBRNetwork deployed at ' + network_instance.address);

        // await deployer.link(XBRTypes, XBRNetwork);
        // await deployer.deploy(XBRNetwork, XBRToken.address, organization, {gas: gas, from: organization});
        // console.log('>>>> XBRNetwork deployed at ' + XBRNetwork.address);

        await deployer.link(XBRTypes, XBRDomain);
        await deployer.link(XBRNetwork, XBRDomain);
        const domain_instance = await deployProxy(XBRDomain, [network_instance.address], { deployer, unsafeAllowCustomTypes: true });
        console.log('>>>> XBRDomain deployed at ' + domain_instance.address);

        // await deployer.link(XBRTypes, XBRDomain);
        // await deployer.link(XBRNetwork, XBRDomain);
        // await deployer.deploy(XBRDomain, XBRNetwork.address, {gas: gas, from: organization});
        // console.log('>>>> XBRDomain deployed at ' + XBRDomain.address);

        await deployer.link(XBRTypes, XBRCatalog);
        await deployer.link(XBRNetwork, XBRCatalog);
        const catalog_instance = await deployProxy(XBRCatalog, [network_instance.address], { deployer, unsafeAllowCustomTypes: true });
        console.log('>>>> XBRCatalog deployed at ' + catalog_instance.address);

        // await deployer.link(XBRTypes, XBRCatalog);
        // await deployer.link(XBRNetwork, XBRCatalog);
        // await deployer.deploy(XBRCatalog, XBRNetwork.address, {gas: gas, from: organization});
        // console.log('>>>> XBRCatalog deployed at ' + XBRCatalog.address);

        await deployer.link(XBRTypes, XBRMarket);
        await deployer.link(XBRNetwork, XBRMarket);
        await deployer.link(XBRCatalog, XBRMarket);
        const market_instance = await deployProxy(XBRMarket, [network_instance.address, catalog_instance.address], { deployer, unsafeAllowCustomTypes: true });
        console.log('>>>> XBRMarket deployed at ' + market_instance.address);

        // await deployer.link(XBRTypes, XBRMarket);
        // await deployer.link(XBRNetwork, XBRMarket);
        // await deployer.link(XBRCatalog, XBRMarket);
        // await deployer.deploy(XBRMarket, XBRNetwork.address, XBRCatalog.address, {gas: gas, from: organization});
        // console.log('>>>> XBRMarket deployed at ' + XBRMarket.address);

        await deployer.link(XBRTypes, XBRChannel);
        await deployer.link(XBRNetwork, XBRChannel);
        await deployer.link(XBRMarket, XBRChannel);
        const channel_instance = await deployProxy(XBRChannel, [market_instance.address], { deployer, unsafeAllowCustomTypes: true });
        console.log('>>>> XBRChannel deployed at ' + channel_instance.address);

        // await deployer.link(XBRTypes, XBRChannel);
        // await deployer.link(XBRNetwork, XBRChannel);
        // await deployer.link(XBRMarket, XBRChannel);
        // await deployer.deploy(XBRChannel, XBRMarket.address, {gas: gas, from: organization});
        // console.log('>>>> XBRChannel deployed at ' + XBRChannel.address);

        if (network === "ganache" || network === "soliditycoverage") {
            const instance8 = await deployProxy(XBRTest, [], { deployer, unsafeAllowCustomTypes: true });
            // await deployer.deploy(XBRTest, {gas: gas, from: organization});
        }

        // // keep this at the end of deployment, so that the addresses of the XBR
        // // contracts "stay constant" for CI
        // if (network === "ganache" || network === "soliditycoverage") {
        //     await deployer.deploy(XBRTest, {gas: gas, from: organization});
        // }

        console.log('\nDeployed XBR contract addresses:\n');
        console.log('export XBR_DEBUG_TYPES_ADDR=' + types_instance.address);
        console.log('export XBR_DEBUG_TOKEN_ADDR=' + token_instance.address);
        console.log('export XBR_DEBUG_NETWORK_ADDR=' + network_instance.address);
        console.log('export XBR_DEBUG_DOMAIN_ADDR=' + domain_instance.address);
        console.log('export XBR_DEBUG_CATALOG_ADDR=' + catalog_instance.address);
        console.log('export XBR_DEBUG_MARKET_ADDR=' + market_instance.address);
        console.log('export XBR_DEBUG_CHANNEL_ADDR=' + channel_instance.address);
        // console.log('export XBR_DEBUG_TOKEN_ADDR=' + XBRToken.address);
        // console.log('export XBR_DEBUG_NETWORK_ADDR=' + XBRNetwork.address);
        // console.log('export XBR_DEBUG_DOMAIN_ADDR=' + XBRDomain.address);
        // console.log('export XBR_DEBUG_CATALOG_ADDR=' + XBRCatalog.address);
        // console.log('export XBR_DEBUG_MARKET_ADDR=' + XBRMarket.address);
        // console.log('export XBR_DEBUG_CHANNEL_ADDR=' + XBRChannel.address);
        console.log('\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n');

    });
};
