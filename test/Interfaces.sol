// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library IVRF {
    struct Proof {
        uint256[2] pk;
        uint256[2] gamma;
        uint256 c;
        uint256 s;
        uint256 seed;
        address uWitness;
        uint256[2] cGammaWitness;
        uint256[2] sHashWitness;
        uint256 zInv;
    }
}

library IVRFTypes {
    struct RequestCommitmentV2Plus {
        uint64 blockNum;
        uint256 subId;
        uint32 callbackGasLimit;
        uint32 numWords;
        address sender;
        bytes extraArgs;
    }
}

library IVRFV2PlusClient {
    struct RandomWordsRequest {
        bytes32 keyHash;
        uint256 subId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        uint32 numWords;
        bytes extraArgs;
    }
}

interface IVRFCoordinatorV2_5 {
    error BalanceInvariantViolated(
        uint256 internalBalance,
        uint256 externalBalance
    );
    error BlockhashNotInStore(uint256 blockNum);
    error CoordinatorAlreadyRegistered(address coordinatorAddress);
    error CoordinatorNotRegistered(address coordinatorAddress);
    error FailedToSendNative();
    error FailedToTransferLink();
    error GasLimitTooBig(uint32 have, uint32 want);
    error GasPriceExceeded(uint256 gasPrice, uint256 maxGas);
    error IncorrectCommitment();
    error IndexOutOfRange();
    error InsufficientBalance();
    error InvalidCalldata();
    error InvalidConsumer(uint256 subId, address consumer);
    error InvalidExtraArgsTag();
    error InvalidLinkWeiPrice(int256 linkWei);
    error InvalidPremiumPercentage(uint8 premiumPercentage, uint8 max);
    error InvalidRequestConfirmations(uint16 have, uint16 min, uint16 max);
    error InvalidSubscription();
    error LinkAlreadySet();
    error LinkDiscountTooHigh(
        uint32 flatFeeLinkDiscountPPM,
        uint32 flatFeeNativePPM
    );
    error LinkNotSet();
    error MsgDataTooBig(uint256 have, uint32 max);
    error MustBeRequestedOwner(address proposedOwner);
    error MustBeSubOwner(address owner);
    error NoCorrespondingRequest();
    error NoSuchProvingKey(bytes32 keyHash);
    error NumWordsTooBig(uint32 have, uint32 want);
    error OnlyCallableFromLink();
    error PaymentTooLarge();
    error PendingRequestExists();
    error ProvingKeyAlreadyRegistered(bytes32 keyHash);
    error Reentrant();
    error TooManyConsumers();

    event ConfigSet(
        uint16 minimumRequestConfirmations,
        uint32 maxGasLimit,
        uint32 stalenessSeconds,
        uint32 gasAfterPaymentCalculation,
        int256 fallbackWeiPerUnitLink,
        uint32 fulfillmentFlatFeeNativePPM,
        uint32 fulfillmentFlatFeeLinkDiscountPPM,
        uint8 nativePremiumPercentage,
        uint8 linkPremiumPercentage
    );
    event CoordinatorDeregistered(address coordinatorAddress);
    event CoordinatorRegistered(address coordinatorAddress);
    event FallbackWeiPerUnitLinkUsed(
        uint256 requestId,
        int256 fallbackWeiPerUnitLink
    );
    event FundsRecovered(address to, uint256 amount);
    event MigrationCompleted(address newCoordinator, uint256 subId);
    event NativeFundsRecovered(address to, uint256 amount);
    event OwnershipTransferRequested(address indexed from, address indexed to);
    event OwnershipTransferred(address indexed from, address indexed to);
    event ProvingKeyDeregistered(bytes32 keyHash, uint64 maxGas);
    event ProvingKeyRegistered(bytes32 keyHash, uint64 maxGas);
    event RandomWordsFulfilled(
        uint256 indexed requestId,
        uint256 outputSeed,
        uint256 indexed subId,
        uint96 payment,
        bool nativePayment,
        bool success,
        bool onlyPremium
    );
    event RandomWordsRequested(
        bytes32 indexed keyHash,
        uint256 requestId,
        uint256 preSeed,
        uint256 indexed subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        bytes extraArgs,
        address indexed sender
    );
    event SubscriptionCanceled(
        uint256 indexed subId,
        address to,
        uint256 amountLink,
        uint256 amountNative
    );
    event SubscriptionConsumerAdded(uint256 indexed subId, address consumer);
    event SubscriptionConsumerRemoved(uint256 indexed subId, address consumer);
    event SubscriptionCreated(uint256 indexed subId, address owner);
    event SubscriptionFunded(
        uint256 indexed subId,
        uint256 oldBalance,
        uint256 newBalance
    );
    event SubscriptionFundedWithNative(
        uint256 indexed subId,
        uint256 oldNativeBalance,
        uint256 newNativeBalance
    );
    event SubscriptionOwnerTransferRequested(
        uint256 indexed subId,
        address from,
        address to
    );
    event SubscriptionOwnerTransferred(
        uint256 indexed subId,
        address from,
        address to
    );

    function BLOCKHASH_STORE() external view returns (address);

    function LINK() external view returns (address);

    function LINK_NATIVE_FEED() external view returns (address);

    function MAX_CONSUMERS() external view returns (uint16);

    function MAX_NUM_WORDS() external view returns (uint32);

    function MAX_REQUEST_CONFIRMATIONS() external view returns (uint16);

    function acceptOwnership() external;

    function acceptSubscriptionOwnerTransfer(uint256 subId) external;

    function addConsumer(uint256 subId, address consumer) external;

    function cancelSubscription(uint256 subId, address to) external;

    function createSubscription() external returns (uint256 subId);

    function deregisterMigratableCoordinator(address target) external;

    function deregisterProvingKey(uint256[2] memory publicProvingKey) external;

    function fulfillRandomWords(
        IVRF.Proof memory proof,
        IVRFTypes.RequestCommitmentV2Plus memory rc,
        bool onlyPremium
    ) external returns (uint96 payment);

    function fundSubscriptionWithNative(uint256 subId) external payable;

    function getActiveSubscriptionIds(
        uint256 startIndex,
        uint256 maxCount
    ) external view returns (uint256[] memory ids);

    function getSubscription(
        uint256 subId
    )
        external
        view
        returns (
            uint96 balance,
            uint96 nativeBalance,
            uint64 reqCount,
            address subOwner,
            address[] memory consumers
        );

    function hashOfKey(
        uint256[2] memory publicKey
    ) external pure returns (bytes32);

    function migrate(uint256 subId, address newCoordinator) external;

    function onTokenTransfer(
        address,
        uint256 amount,
        bytes memory data
    ) external;

    function owner() external view returns (address);

    function ownerCancelSubscription(uint256 subId) external;

    function pendingRequestExists(uint256 subId) external view returns (bool);

    function recoverFunds(address to) external;

    function recoverNativeFunds(address payable to) external;

    function registerMigratableCoordinator(address target) external;

    function registerProvingKey(
        uint256[2] memory publicProvingKey,
        uint64 maxGas
    ) external;

    function removeConsumer(uint256 subId, address consumer) external;

    function requestRandomWords(
        IVRFV2PlusClient.RandomWordsRequest memory req
    ) external returns (uint256 requestId);

    function requestSubscriptionOwnerTransfer(
        uint256 subId,
        address newOwner
    ) external;

    function s_config()
        external
        view
        returns (
            uint16 minimumRequestConfirmations,
            uint32 maxGasLimit,
            bool reentrancyLock,
            uint32 stalenessSeconds,
            uint32 gasAfterPaymentCalculation,
            uint32 fulfillmentFlatFeeNativePPM,
            uint32 fulfillmentFlatFeeLinkDiscountPPM,
            uint8 nativePremiumPercentage,
            uint8 linkPremiumPercentage
        );

    function s_currentSubNonce() external view returns (uint64);

    function s_fallbackWeiPerUnitLink() external view returns (int256);

    function s_provingKeyHashes(uint256) external view returns (bytes32);

    function s_provingKeys(
        bytes32
    ) external view returns (bool exists, uint64 maxGas);

    function s_requestCommitments(uint256) external view returns (bytes32);

    function s_totalBalance() external view returns (uint96);

    function s_totalNativeBalance() external view returns (uint96);

    function setConfig(
        uint16 minimumRequestConfirmations,
        uint32 maxGasLimit,
        uint32 stalenessSeconds,
        uint32 gasAfterPaymentCalculation,
        int256 fallbackWeiPerUnitLink,
        uint32 fulfillmentFlatFeeNativePPM,
        uint32 fulfillmentFlatFeeLinkDiscountPPM,
        uint8 nativePremiumPercentage,
        uint8 linkPremiumPercentage
    ) external;

    function setLINKAndLINKNativeFeed(
        address link,
        address linkNativeFeed
    ) external;

    function transferOwnership(address to) external;

    function withdraw(address recipient) external;

    function withdrawNative(address payable recipient) external;
}
