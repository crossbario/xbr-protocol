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

pragma solidity ^0.5.12;
pragma experimental ABIEncoderV2;

// https://openzeppelin.org/api/docs/math_SafeMath.html
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

// https://openzeppelin.org/api/docs/cryptography_ECDSA.html
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";

import "./XBRMaintained.sol";
import "./XBRTypes.sol";
import "./XBRToken.sol";
import "./XBRNetwork.sol";
import "./XBRMarket.sol";


/**
 * XBR Payment/Paying Channel between a XBR data consumer and the XBR market maker,
 * or the XBR Market Maker and a XBR data provider.
 */
contract XBRChannel is XBRMaintained {

    // Add safe math functions to uint256 using SafeMath lib from OpenZeppelin
    using SafeMath for uint256;

    // Add recover method for bytes32 using ECDSA lib from OpenZeppelin
    using ECDSA for bytes32;

    event Opened(ChannelType ctype, bytes16 indexed marketId, bytes16 indexed channelId,
        address indexed marketmaker, address actor, address delegate, address recepient,
        uint256 amount, uint32 timeout);

    /**
     * Event emitted when payment channel is closing (that is, one of the two state channel
     * participants has called "close()", initiating start of the channel timeout).
     */
    event Closing(ChannelType ctype, bytes16 indexed marketId, address signer, uint256 payout, uint256 fee,
        uint256 refund, uint256 timeoutAt);

    /**
     * Event emitted when payment channel has finally closed, which happens after both state
     * channel participants have called close(), agreeing on last state, or after the timeout
     * at latest - in case the second participant doesn't react within timeout)
     */
    event Closed(bytes16 indexed marketId, address signer, uint256 payout, uint256 fee,
        uint256 refund, uint256 closedAt);

    /// Instance of XBRMarket contract this contract is linked to.
    XBRMarket public market;

    /// Created channels are sequence numbered using this counter (to allow deterministic collision-free IDs for channels)
    uint32 private channelSeq = 1;

    /// Table of all XBR Channels.
    mapping(bytes16 => XBRTypes.Channel) public channels;

    /**
     * Constructor for this contract, only called once (when deploying the network).
     *
     * @param market_ The XBR markets contract this instance is associated with.
     */
    constructor (address market_) public {
        market = XBRMarket(market_);
    }

    /**
     * Create a new XBR payment/paying channel for processing off-chain micro-transactions.
     *
     * @param marketId The ID of the XBR market this channel is associated with.
     * @param actor The actor (buyer/seller in the market) that opened this channel.
     * @param delegate The delegate (off-chain) allowed to spend/earn-on this channel (off-chain)
        in the name of the actor (buyer/seller in the market).
     * @param recipient The receiver (on-chain) of the channel payout.
     * @param amount The amount initially transfered to and held in the channel until closed.
     * @param timeout The channel timeout period that begins with the first call to `close()`
     */
    function openChannel (ChannelType ctype,
                          bytes16 marketId,
                          bytes16 channelId,
                          address marketmaker,
                          address actor,
                          address delegate,
                          address recipient,
                          uint256 amount,
                          uint32 timeout,
                          bytes memory signature) public {

        // the data used to open the new channel must have a valid signature, signed by the
        // actor (buyer/seller in the market)
        require(XBRTypes.verify(actor, XBRTypes.EIP712ChannelOpen(network.verifyingChain(),
            network.verifyingContract(), marketId, marketmaker, actor, delegate, recipient,
            amount, timeout, ctype), signature), "INVALID_CHANNEL_SIGNATURE");

        // market must exist
        require(markets[marketId].owner != address(0), "NO_SUCH_MARKET");

        // channel must not yet exist
        require(channels[channelId].actor == address(0), "INVALID_CHANNEL_ALREADY_EXISTS");

        // must provide a valid market maker address
        require(marketmaker != address(0), "INVALID_CHANNEL_MAKER");

        // must provide the sam market maker address as set in the market
        require(marketmaker != markets[marketId].maker, "INVALID_CHANNEL_MAKER");

        // the actor (buyer/seller in the market) must be a registered member
        (, , , XBRTypes.MemberLevel actor_member_level, ) = network.members(actor);
        require(actor_member_level == XBRTypes.MemberLevel.ACTIVE ||
                actor_member_level == XBRTypes.MemberLevel.VERIFIED, "INVALID_CHANNEL_ACTOR");

        // must provide a valid delegate address
        require(delegate != address(0), "INVALID_CHANNEL_DELEGATE");

        // the recepient must be a registered member
        (, , , XBRTypes.MemberLevel recipient_member_level, ) = network.members(recipient);
        require(recipient_member_level == XBRTypes.MemberLevel.ACTIVE ||
                recipient_member_level == XBRTypes.MemberLevel.VERIFIED, "INVALID_CHANNEL_RECIPIENT");

        if (ctype == XBRTypes.ChannelType.PAYMENT) {
            // actor must be consumer in the market
            require(uint8(markets[marketId].consumerActors[msg.sender].joined) != 0, "ACTOR_NOT_CONSUMER");

            // technical recipient of the unidirectional, half-legged channel must be the
            // owner (operator) of the market
            require(recipient == markets[marketId].owner, "RECIPIENT_NOT_MARKET");

        } else if (ctype == XBRTypes.ChannelType.PAYING) {
            // actor must be market maker for market
            require(markets[marketId].maker == msg.sender, "ACTOR_NOT_MAKER");

            // recipient must be provider in the market
            require(uint8(markets[marketId].providerActors[recipient].joined) != 0, "RECIPIENT_NOT_PROVIDER");

        } else {
            require(false, "INVALID_CHANNEL_TYPE");
        }

        // payment channel amount must be positive
        require(amount > 0 && amount <= market.network().token().totalSupply(), "INVALID_CHANNEL_AMOUNT");

        // payment channel timeout can be [0 seconds - 10 days[
        require(timeout >= 0 && timeout < 864000, "INVALID_CHANNEL_TIMEOUT");

        // channel creation time
        uint256 openedAt = block.timestamp;
        channels[channelId] = XBRTypes.Channel(channelSeq, openedAt, ctype, ChannelState.OPEN,
            marketId, marketmaker, actor, delegate, recipient, amount, timeout, signature);

        // increment channel sequence for next channel
        channelSeq = channelSeq + 1;

        // notify observers (eg a dormant market maker waiting to be associated)
        emit Opened(ctype, marketId, channelId, marketmaker, actor, delegate, recepient,
            amount, timeout, signature);
    }

    /**
     * Trigger closing this payment channel. When the first participant has called `close()`
     * submitting its latest transaction/state, a timeout period begins during which the
     * other party of the payment channel has to submit its latest transaction/state too.
     * When both transaction have been submitted, and the submitted transactions/states agree,
     * the channel immediately closes, and the consumed amount of token in the channel is
     * transferred to the channel recipient, and the remaining amount of token is transferred
     * back to the original sender.
     */
    function closeChannel (bytes16 marketId_, uint32 channel_seq_, uint256 balance_, bool is_final_,
        bytes memory delegate_sig, bytes memory marketmaker_sig) public {

        require(verifyClose(delegate, address(this), channel_seq_, balance_, is_final_, delegate_sig),
            "INVALID_DELEGATE_SIGNATURE");

        require(verifyClose(marketmaker, address(this), channel_seq_, balance_, is_final_, marketmaker_sig),
            "INVALID_MARKETMAKER_SIGNATURE");

        // closing (off-chain) balance must be valid
        require(0 <= balance_ && balance_ <= amount, "INVALID_CLOSING_BALANCE");

        // closing (off-chain) sequence must be valid
        require(channel_seq_ >= 1, "INVALID_CLOSING_SEQ");

        // channel must be in correct state (OPEN or CLOSING)
        require(state == ChannelState.OPEN || state == ChannelState.CLOSING, "CHANNEL_NOT_OPEN");

        // if the channel is already closing ..
        if (state == ChannelState.CLOSING) {
            // the channel must not yet be timed out
            require(closedAt == 0, "INTERNAL_ERROR_CLOSED_AT_NONZERO");
            require(block.timestamp < closingAt, "CHANNEL_TIMEOUT"); // solhint-disable-line

            // the submitted transaction must be more recent
            require(channel_seq_ < _closing_channel_seq, "OUTDATED_TRANSACTION");
        }

        // the amount earned (by the recipient) is initial channel amount minus last off-chain balance
        uint256 earned = (amount - balance_);

        // the remaining amount (send back to the buyer) ia the last off-chain balance
        uint256 refund = balance_;

        // the fee to the xbr network is 1% of the earned amount
        uint256 fee = earned / 100;

        // the amount paid out to the recipient
        uint256 payout = earned - fee;

        // if we got a newer closing transaction, process it ..
        if (channel_seq_ > _closing_channel_seq) {

            // the closing balance of a newer transaction must be not greater than anyone we already know
            if (_closing_channel_seq > 0) {
                require(balance_ <= _closing_balance, "TRANSACTION_BALANCE_OUTDATED");
            }

            // note the closing transaction sequence number and closing off-chain balance
            state = ChannelState.CLOSING;
            _closing_channel_seq = channel_seq_;
            _closing_balance = balance_;

            // note the new channel closing date
            closingAt = block.timestamp + timeout; // solhint-disable-line

            // notify channel observers
            emit Closing(marketId, sender, payout, fee, refund, closingAt);
        }

        // finally close the channel ..
        if (is_final_ || balance_ == 0 || (state == ChannelState.CLOSING && block.timestamp >= closingAt)) { // solhint-disable-line

            // now send tokens locked in this channel (which escrows the tokens) to the recipient,
            // the xbr network (for the network fee), and refund remaining tokens to the original sender
            if (payout > 0) {
                require(_token.transfer(recipient, payout), "CHANNEL_CLOSE_PAYOUT_TRANSFER_FAILED");
            }

            if (fee > 0) {
                require(_token.transfer(organization, fee), "CHANNEL_CLOSE_FEE_TRANSFER_FAILED");
            }

            if (refund > 0) {
                require(_token.transfer(sender, refund), "CHANNEL_CLOSE_REFUND_TRANSFER_FAILED");
            }

            // mark channel as closed (but do not selfdestruct)
            closedAt = block.timestamp; // solhint-disable-line
            state = ChannelState.CLOSED;

            // notify channel observers
            emit Closed(marketId, sender, payout, fee, refund, closedAt);
        }
    }
}

/*
function openPaymentChannel (bytes16 marketId, address recipient, address delegate,
    uint256 amount, uint32 timeout) public returns (address paymentChannel) {

    // create new payment channel contract
    XBRChannel channel = new XBRChannel(network.organization(), address(network.token()), address(this), marketId,
        markets[marketId].maker, msg.sender, delegate, recipient, amount, timeout,
        XBRChannel.ChannelType.PAYMENT);

    // transfer tokens (initial balance) into payment channel contract
    bool success = network.token().transferFrom(msg.sender, address(channel), amount);
    require(success, "OPEN_CHANNEL_TRANSFER_FROM_FAILED");

    // remember the new payment channel associated with the market
    //markets[marketId].channels.push(address(channel));
    markets[marketId].consumerActors[msg.sender].channels.push(address(channel));

    // emit event ChannelCreated(bytes16 marketId, address sender, address delegate,
    //      address recipient, address channel)
    emit ChannelCreated(marketId, channel.sender(), channel.delegate(), channel.recipient(),
        address(channel), XBRChannel.ChannelType.PAYMENT);

    // return address of new channel contract
    return address(channel);
}

function openPayingChannel (bytes16 marketId, address recipient, address delegate,
    uint256 amount, uint32 timeout) public returns (address paymentChannel) {

    // create new paying channel contract
    XBRChannel channel = new XBRChannel(network.organization(), address(network.token), address(this),
        marketId, markets[marketId].maker, msg.sender, delegate, recipient, amount, timeout,
        XBRChannel.ChannelType.PAYING);

    // transfer tokens (initial balance) into payment channel contract
    bool success = network.token().transferFrom(msg.sender, address(channel), amount);
    require(success, "OPEN_CHANNEL_TRANSFER_FROM_FAILED");

    // remember the new payment channel associated with the market
    //markets[marketId].channels.push(address(channel));
    markets[marketId].providerActors[recipient].channels.push(address(channel));

    // emit event ChannelCreated(bytes16 marketId, address sender, address delegate,
    //  address recipient, address channel)
    emit ChannelCreated(marketId, channel.sender(), channel.delegate(), channel.recipient(),
        address(channel), XBRChannel.ChannelType.PAYING);

    return address(channel);
}
*/