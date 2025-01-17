//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "../interfaces/IAdmin.sol";
import "../interfaces/IAllocationStaking.sol";
import "../interfaces/IERC20Metadata.sol";
import "../interfaces/IDexalotPortfolio.sol";
import "../interfaces/ICollateral.sol";
import "../interfaces/IAvalaunchMarketplace.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";

contract AvalaunchSaleV2 is Initializable {

    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using SafeMath for uint256;

    // Pointer allocation staking contract
    IAllocationStaking public allocationStaking;
    // Pointer to sales factory contract
    address public factory;
    // Pointer to admin contract
    IAdmin public admin;
    // Pointer to collateral contract
    ICollateral public collateral;
    // Pointer to marketplace contract
    IAvalaunchMarketplace public marketplace;
    // Pointer to dexalot portfolio contract
    IDexalotPortfolio public dexalotPortfolio;
    // Official sale mod
    address public moderator;

    // Sale Phases
    enum Phases { Idle, Registration, Validator, Staking, Booster }
    // Portion States
    enum PortionStates { Available, Withdrawn, WithdrawnToDexalot, OnMarket, Sold }

    struct Sale {
        IERC20 token;                        // Official sale token
        Phases phase;                        // Current phase of sale
        bool isCreated;                      // Sale creation marker
        bool earningsWithdrawn;              // Earnings withdrawal marker
        bool leftoverWithdrawn;              // Leftover withdrawal marker
        bool tokensDeposited;                // Token deposit marker
        uint256 tokenPriceInAVAX;            // Sale token's price in AVAX
        uint256 amountOfTokensToSell;        // Amount of tokens to sell
        uint256 totalTokensSold;             // Amount of sold tokens
        uint256 totalAVAXRaised;             // Total AVAX amount raised
        uint256 saleEnd;                     // Sale end timestamp
    }

    struct Participation {
        uint256 amountBought;                // Amount of tokens bought
        uint256 amountAVAXPaid;              // Amount of $AVAX paid for tokens
        uint256 timeParticipated;            // Timestamp of participation time
        uint256 phaseId;                     // Phase user is registered for
        uint256[] portionAmounts;            // Amount of tokens for each portion
        PortionStates[] portionStates;       // State of each portion
        uint256 boostedAmountAVAXPaid;       // Amount of $AVAX paid for boost
        uint256 boostedAmountBought;         // Amount of tokens bought with boost
        uint256 amountBoughtOnMarketplace;   // Amount of tokens purchased on marketplace
        uint256 amountSoldOnMarketplace;     // Amount of tokens sold on marketplace
    }

    // Sale state structure
    Sale public sale;
    // Mapping user to his participation
    mapping(address => Participation) public userToParticipation;
    // User to phase for which he registered
    mapping(address => uint256) public addressToPhaseRegisteredFor;
    // Mapping if user is participated or not
    mapping(address => bool) public isParticipated;
    // Number of sale registrants
    uint256 public numberOfRegistrants;
    // Times when portions are getting unlocked
    uint256[] public vestingPortionsUnlockTime;
    // Percent of the participation user can withdraw
    uint256[] public vestingPercentPerPortion;
    // Number of users participated in the sale
    uint256 public numberOfParticipants;
    // Number of vested token portions
    uint256 public numberOfVestedPortions;
    // Precision for percent for portion vesting
    uint256 public portionVestingPrecision;
    // Registration deposit AVAX, deposited during the registration, returned after the participation.
    uint256 public registrationDepositAVAX;
    // Accounting total AVAX collected, after sale end admin can withdraw this
    uint256 public registrationFees;
    // Timestamp of sale.tokenPriceInAvax latest update
    uint256 public lastPriceUpdateTimestamp;
    // First vested portion's Dexalot unlock timestamp
    uint256 public dexalotUnlockTime;
    // Sale setter lock flag
    bool public isLockOn;
    // Multiplier used on token amount calculations
    uint256 public oneTokenInWei;

    // Events
    event SaleCreated(uint256 tokenPriceInAVAX, uint256 amountOfTokensToSell, uint256 saleEnd);
    event TokensSold(address user, uint256 amount);
    event UserRegistered(address user, uint256 phaseId);
    event NewTokenPriceSet(uint256 newPrice);
    event RegistrationAVAXRefunded(address user, uint256 amountRefunded);
    event TokensWithdrawn(address user, uint256 amount);
    event TokensWithdrawnToDexalot(address user, uint256 amount);
    event LockActivated(uint256 time);
    event ParticipationBoosted(address user, uint256 amountAVAX, uint256 amountTokens);
    event PhaseChanged(Phases phase);

    // Restricting calls only to moderator
    modifier onlyModerator() {
        _onlyModerator();
        _;
    }

    // Internal function containing onlyModerator modifier logic
    function _onlyModerator() private view {
        require(msg.sender == moderator, "Only moderator.");
    }

    // Restricting calls only to sale admin
    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    // Internal function containing onlyAdmin modifier logic
    function _onlyAdmin() private view {
        require(admin.isAdmin(msg.sender), "Only admin.");
    }

    // Restricting calls only to collateral contract
    modifier onlyCollateral() {
        _onlyCollateral();
        _;
    }

    // Internal function containing onlyCollateral modifier logic
    function _onlyCollateral() private view {
        require(msg.sender == address(collateral), "Only collateral.");
    }

    // Restricting setter calls after gate closing
    modifier ifUnlocked() {
        _ifUnlocked();
        _;
    }

    // Internal function containing ifUnlocked modifier logic
    function _ifUnlocked() private view {
        require(!isLockOn, "Lock active.");
    }

    constructor() public initializer {}

    function initialize(
        IAdmin _admin,
        IAllocationStaking _allocationStaking,
        ICollateral _collateral,
        IAvalaunchMarketplace _marketplace,
        address _moderator
    ) external initializer {
        require(address(_admin) != address(0));
        require(address(_allocationStaking) != address(0));
        require(address(_collateral) != address(0));
        require(address(_marketplace) != address(0));
        require(_moderator != address(0));

        factory = msg.sender;
        admin = _admin;
        allocationStaking = _allocationStaking;
        collateral = _collateral;
        marketplace = _marketplace;
        moderator = _moderator;
    }

    /**
     * @notice Function to set vesting params
     * @param _unlockingTimes is array of unlock times for each portion
     * @param _percents are percents of purchased tokens that are distributed among portions
     */
    function setVestingParams(
        uint256[] calldata _unlockingTimes,
        uint256[] calldata _percents
    )
    external
    onlyAdmin
    {
        require(_unlockingTimes.length == _percents.length);
        require(vestingPercentPerPortion.length == 0 && vestingPortionsUnlockTime.length == 0, "Already set.");
        require(portionVestingPrecision != 0, "Sale params not set.");

        // Set number of vested portions
        numberOfVestedPortions = _unlockingTimes.length;
        // Gas optimization
        uint256 _numberOfVestedPortions = numberOfVestedPortions;

        // Require that locking times are later than sale end
        require(_unlockingTimes[0] > sale.saleEnd, "Invalid first unlock time.");
        // Use precision to make sure percents of portions align
        uint256 precision = portionVestingPrecision;
        // Set vesting portions percents and unlock times
        for (uint256 i = 0; i < _numberOfVestedPortions; i++) {
            if (i > 0) {
                // Each portion unlock time must be later than previous
                require(_unlockingTimes[i] > _unlockingTimes[i-1], "Invalid unlock time.");
            }
            vestingPortionsUnlockTime.push(_unlockingTimes[i]);
            vestingPercentPerPortion.push(_percents[i]);
            precision = precision.sub(_percents[i]);
        }
        require(precision == 0, "Invalid percentage calculation.");
    }

    /**
     * @notice Function to shift vested portion unlock times by admin
     * @param timeToShift is amount of time to add to all portion unlock times
     * @dev will shift all portions which's unlock time hasn't passed yet
     */
    function shiftVestingUnlockTimes(uint256 timeToShift) external onlyAdmin {
        require(timeToShift > 0, "Invalid shift time.");
        bool movable;
        // Gas optimization
        uint256 _numberOfVestedPortions = numberOfVestedPortions;
        // Shift the unlock time for each portion
        for (uint256 i = 0; i < _numberOfVestedPortions; i++) {
            // Shift only portions that time didn't reach yet
            if (!movable && block.timestamp < vestingPortionsUnlockTime[i]) movable = true;
            // Each portion is after the previous so once movable flag is active all later portions may be shifted
            if (movable) vestingPortionsUnlockTime[i] = vestingPortionsUnlockTime[i].add(timeToShift);
        }
    }

    /**
     * @notice Function to set fundamental sale parameters
     * @param _token is official sale token, may be set asynchronously too
     * @param _tokenPriceInAVAX is token price in $AVAX, dynamically set by admin every 'n' minutes
     * @param _amountOfTokensToSell is amount of tokens that will be deposited to sale contract and available to buy
     * @param _saleEnd is timestamp of sale end
     * @param _portionVestingPrecision is precision rate for vested portion percents
     */
    function setSaleParams(
        IERC20 _token,
        uint256 _tokenPriceInAVAX,
        uint256 _amountOfTokensToSell,
        uint256 _saleEnd,
        uint256 _portionVestingPrecision,
        uint256 _registrationDepositAVAX
    )
    external
    onlyAdmin
    {
        require(!sale.isCreated, "Sale already created.");
        require(_portionVestingPrecision >= 100, "Invalid vesting precision.");
        require(
            _tokenPriceInAVAX != 0 && _amountOfTokensToSell != 0 && _saleEnd > block.timestamp,
            "Invalid input."
        );

        // Set sale params
        sale.isCreated = true;
        sale.token = _token;
        sale.tokenPriceInAVAX = _tokenPriceInAVAX;
        sale.amountOfTokensToSell = _amountOfTokensToSell;
        sale.saleEnd = _saleEnd;

        // Set portion vesting precision
        portionVestingPrecision = _portionVestingPrecision;
        registrationDepositAVAX = _registrationDepositAVAX;
        oneTokenInWei = uint(10) ** IERC20Metadata(address(_token)).decimals();

        // Emit event
        emit SaleCreated(
            _tokenPriceInAVAX,
            _amountOfTokensToSell,
            _saleEnd
        );
    }

    /**
     * @notice Function to shift sale end timestamp
     * @dev sale end timestamp needs to be before any unlock times
     */
    function shiftSaleEnd(uint256 timeToShift) external onlyAdmin {
        require(timeToShift > 0, "Invalid time to shift.");
        require(block.timestamp < sale.saleEnd, "Sale already ended.");
        sale.saleEnd = sale.saleEnd.add(timeToShift);
        if (vestingPortionsUnlockTime.length > 0) {
            require(sale.saleEnd < vestingPortionsUnlockTime[0], "Sale end crossing vesting unlock times.");
        }
        if (dexalotUnlockTime > 0) require(sale.saleEnd < dexalotUnlockTime, "Sale end crossing dexalot unlock time.");
    }

    /**
     * @notice Function to set Dexalot parameters
     * @param _dexalotPortfolio is official Dexalot Portfolio contract address
     * @param _dexalotUnlockTime is unlock time for first portion withdrawal to Dexalot Portfolio
     * @dev Optional feature to enable user portion withdrawals directly to Dexalot Portfolio
     */
    function setDexalotParameters(
        IDexalotPortfolio _dexalotPortfolio,
        uint256 _dexalotUnlockTime
    )
    external
    onlyAdmin
    ifUnlocked
    {
        // Require that dexalot unlock time is inbetween sale end and first vesting unlock..
        // ..and that vesting params are already set
        require(
            address(_dexalotPortfolio) != address(0) &&
            _dexalotUnlockTime > sale.saleEnd &&
            _dexalotUnlockTime <= vestingPortionsUnlockTime[0] &&
            vestingPortionsUnlockTime[0] > 0 &&
            sale.saleEnd > 0,
            "Invalid parameter(s)."
        );
        dexalotPortfolio = _dexalotPortfolio;
        dexalotUnlockTime = _dexalotUnlockTime;
    }

    /**
     * @notice Function to shift dexalot unlocking time
     */
    function shiftDexalotUnlockTime(uint256 timeToShift) external onlyAdmin {
        uint256 shiftedDexalotUnlockTime = dexalotUnlockTime.add(timeToShift);
        require(block.timestamp < dexalotUnlockTime && shiftedDexalotUnlockTime <= vestingPortionsUnlockTime[0]);
        dexalotUnlockTime = shiftedDexalotUnlockTime;
    }

    /**
     * @notice Function to retroactively set sale token address
     * @param saleToken is official token of the project
     * @dev Retroactive calls are option for teams which do not have token at the moment of sale launch
     */
    function setSaleToken(
        IERC20 saleToken
    )
    external
    onlyAdmin
    ifUnlocked
    {
        require(address(saleToken) != address(0));
        require(!sale.tokensDeposited, "Tokens already deposited.");
        sale.token = saleToken;
    }

    /**
     * @notice Function to register for the upcoming sale
     * @param signature is pass for sale registration provided by admins
     * @param sigExpTime is timestamp after which signature is no longer valid
     * @param phaseId is id of phase user is registering for
     */
    function registerForSale(
        bytes calldata signature,
        uint256 sigExpTime,
        uint256 phaseId
    )
    external
    payable
    {
        // Check if sale is created
        require(sale.isCreated, "Sale is not created yet.");
        // Sale registration validity checks
        require(msg.value == registrationDepositAVAX, "Invalid deposit amount.");
        // Register only for validator or staking phase
        require(phaseId > uint8(Phases.Registration) && phaseId < uint8(Phases.Booster), "Invalid phase id.");
        require(sale.phase == Phases.Registration, "Must be called during registration phase.");
        require(block.timestamp <= sigExpTime, "Signature expired.");
        require(addressToPhaseRegisteredFor[msg.sender] == 0, "Already registered.");

        // Make sure signature is signed by admin, with proper parameters
        verifySignature(
            keccak256(abi.encodePacked(sigExpTime, msg.sender, phaseId, address(this), "registerForSale")),
            signature
        );

        // Set user's registration phase
        addressToPhaseRegisteredFor[msg.sender] = phaseId;
        // Increment number of registered users
        numberOfRegistrants++;
        // Increase earnings from registration fees
        registrationFees += msg.value;
        // Locking tokens for participants of staking phase until the sale ends
        if (phaseId == uint8(Phases.Staking)) {
            allocationStaking.setTokensUnlockTime(
                0,
                msg.sender,
                sale.saleEnd
            );
        }
        // Emit event
        emit UserRegistered(msg.sender, phaseId);
    }

    /**
     * @notice Function to update token price in $AVAX to match real time value of token
     * @param price is token price in $AVAX to be set
     * @dev To help us reduce reliance on $AVAX volatility, oracle will update price during sale every 'n' minutes (n>=5)
     */
    function updateTokenPriceInAVAX(uint256 price) external onlyAdmin {
        // Compute 30% of the current token price
        uint256 thirtyPercent = sale.tokenPriceInAVAX.mul(30).div(100);
        // Require that new price is under 30% difference compared to current
        require(
            sale.tokenPriceInAVAX.add(thirtyPercent) > price && sale.tokenPriceInAVAX - thirtyPercent < price,
            "Price out of range."
        );
        require(lastPriceUpdateTimestamp + 5 minutes < block.timestamp);
        // Set new token price via internal call
        _setNewTokenPrice(price);
    }

    /**
     * @notice Function to set new token price by admin
     * @dev Works only until setter lock becomes active
     */
    function overrideTokenPrice(uint256 price) external onlyAdmin ifUnlocked {
        // Set new token price via internal call
        _setNewTokenPrice(price);
    }

    /**
     * @notice Function for internal set of token price in $AVAX
     */
    function _setNewTokenPrice(uint256 price) internal {
        // Update parameters
        sale.tokenPriceInAVAX = price;
        lastPriceUpdateTimestamp = block.timestamp;
        // Emit event
        emit NewTokenPriceSet(price);
    }

    /**
     * @notice Function to deposit sale tokens
     * @dev Only sale moderator may deposit
     */
    function depositTokens() external onlyModerator {
        // Require that setSaleParams was called
        require(
            sale.isCreated && 
            address(sale.token) != address(0) &&
            !sale.tokensDeposited
        );

        // Mark that tokens are deposited
        sale.tokensDeposited = true;

        // Perform safe transfer
        sale.token.safeTransferFrom(
            msg.sender,
            address(this),
            sale.amountOfTokensToSell
        );
    }

    /**
     * @notice Function to auto-participate for user via collateral
     */
    function autoParticipate(
        address user,
        uint256 amount,
        uint256 amountXavaToBurn,
        uint256 phaseId
    ) external payable onlyCollateral {
        _participate(user, amount, amountXavaToBurn, phaseId);
    }

    /**
     * @notice Function to boost user's participation via collateral
     */
    function boostParticipation(
        address user,
        uint256 amountXavaToBurn
    ) external payable onlyCollateral {
        _participate(user, 0, amountXavaToBurn, uint256(Phases.Booster));
    }

    /**
     * @notice Function to participate in sale manually
     */
    function participate(
        uint256 amount,
        uint256 amountXavaToBurn,
        uint256 phaseId,
        bytes calldata signature
    ) external payable {
        require(msg.sender == tx.origin, "Only direct calls.");
        // Make sure admin signature is valid
        verifySignature(
            keccak256(abi.encodePacked(msg.sender, amount, amountXavaToBurn, phaseId, address(this), "participate")),
            signature
        );
        _participate(msg.sender, amount, amountXavaToBurn, phaseId);
    }

    /**
     * @notice Function to participate in sale with multiple variants
     * @param user is user who participates in a sale
     * @param amount is maximal amount of tokens allowed for user to buy
     * @param amountXavaToBurn is amount of xava to be burned from user's stake
     * @param phaseId is round phase id user registered for (Validator, Staking or Booster)
     * @dev Regular participation by direct call is considered usual flow and it is applicable on 2 rounds - Validator and Staking
     * * Main diff is that on Staking round participation user's $XAVA is getting burned in small amount
     * * These rounds can be participated automatically too if user signs up for it and deposits $AVAX to Collateral contract
     * * Collateral contract will be performing automatic participations for users who signed up
     * * Booster round is 3rd one, available only for users who participated in one of first 2 rounds
     * * In booster round, it is possible to participate only through collateral, on user's demand
     * * Function flow changes based on round type
     */
    function _participate(
        address user,
        uint256 amount,
        uint256 amountXavaToBurn,
        uint256 phaseId
    ) internal {
        // Make sure selected phase is ongoing and is round phase (Validator, Staking, Booster)
        require(phaseId > uint8(Phases.Registration) && phaseId == uint8(sale.phase), "Invalid phase.");
        
        bool isBooster = phaseId == uint8(Phases.Booster);

        // Load participation storage pointer
        Participation storage p = userToParticipation[user];

        if (!isBooster) { // Normal flow
            // User must have registered for the phase in advance
            require(addressToPhaseRegisteredFor[user] == phaseId, "Not registered for this phase.");
            // Check user haven't participated before
            require(!isParticipated[user], "Already participated.");
        } else { // Booster flow
            // Check user has participated before
            require(isParticipated[user], "Only participated users.");
            // Check if user participated in staking round
            require(addressToPhaseRegisteredFor[user] == uint8(Phases.Staking), "User is not staker.");
            // Cannot boost participation more than once
            require(p.boostedAmountBought == 0, "Already boosted.");
        }

        // Compute the amount of tokens user is buying
        uint256 amountOfTokensBuying = (msg.value).mul(oneTokenInWei).div(sale.tokenPriceInAVAX);
        // Cannot buy zero tokens
        require(amountOfTokensBuying > 0, "Can't buy 0 tokens.");

        if (!isBooster) {
            // Check in terms of user allo
            require(amountOfTokensBuying <= amount, "Exceeding allowance.");
        }

        // Require that amountOfTokensBuying is less than sale token leftover cap
        require(amountOfTokensBuying <= sale.amountOfTokensToSell.sub(sale.totalTokensSold), "Out of tokens.");
        // Increase amount of sold tokens
        sale.totalTokensSold = sale.totalTokensSold.add(amountOfTokensBuying);
        // Increase amount of AVAX raised
        sale.totalAVAXRaised = sale.totalAVAXRaised.add(msg.value);

        // Gas optimization
        uint256 _numberOfVestedPortions = numberOfVestedPortions;
        if (!isBooster) { // Normal flow
            // Initialize user's participation
            _initParticipationForUser(user, amountOfTokensBuying, msg.value, block.timestamp, phaseId, _numberOfVestedPortions);
        }

        uint256 lastPercent; uint256 lastAmount;
        // Gas optimization
        uint256 _portionVestingPrecision = portionVestingPrecision;
        // Compute portion amounts
        for (uint256 i = 0; i < _numberOfVestedPortions; i++) {
            if (lastPercent != vestingPercentPerPortion[i]) {
                lastPercent = vestingPercentPerPortion[i];
                lastAmount = amountOfTokensBuying.mul(lastPercent).div(_portionVestingPrecision);
            }
            p.portionAmounts[i] += lastAmount;
        }

        if (phaseId == uint8(Phases.Staking) || isBooster) {
            // Burn XAVA from user
            allocationStaking.redistributeXava(
                0,
                user,
                amountXavaToBurn
            );
        }

        if (!isBooster) { // Normal flow
            // Mark user is participated
            isParticipated[user] = true;
            // Increment number of participants in the Sale
            numberOfParticipants++;
            // Decrease of available registration fees
            registrationFees = registrationFees.sub(registrationDepositAVAX);
            // Transfer registration deposit amount in AVAX back to the users.
            safeTransferAVAX(user, registrationDepositAVAX);
            // Trigger events
            emit RegistrationAVAXRefunded(user, registrationDepositAVAX);
            emit TokensSold(user, amountOfTokensBuying);
        } else { // Booster flow
            // Add msg.value to boosted avax paid
            p.boostedAmountAVAXPaid = msg.value;
            // Add amountOfTokensBuying as boostedAmount
            p.boostedAmountBought = amountOfTokensBuying;
            // Emit participation boosted event
            emit ParticipationBoosted(user, msg.value, amountOfTokensBuying);
        }
    }

    /**
     * @notice Function to withdraw unlocked portions to wallet or Dexalot portfolio
     * @dev This function will deal with specific flow differences on withdrawals to wallet or dexalot
     * * First portion has different unlocking time for regular and dexalot withdraw
     */
    function withdrawMultiplePortions(uint256[] calldata portionIds, bool toDexalot) external {

        if (toDexalot) {
            require(address(dexalotPortfolio) != address(0) && dexalotUnlockTime != 0, "Dexalot withdraw not supported.");
            // Means first portion is unlocked for dexalot
            require(block.timestamp >= dexalotUnlockTime, "Dexalot withdraw is locked.");
        }

        uint256 totalToWithdraw;

        // Retrieve participation from storage
        Participation storage p = userToParticipation[msg.sender];

        for (uint256 i = 0; i < portionIds.length; i++) {
            uint256 portionId = portionIds[i];
            require(portionId < numberOfVestedPortions, "Invalid portion id.");

            if (
                p.portionStates[portionId] == PortionStates.Available && p.portionAmounts[portionId] > 0 && (
                    vestingPortionsUnlockTime[portionId] <= block.timestamp || (portionId == 0 && toDexalot)
                )
            ) {
                // Mark portion as withdrawn to dexalot
                if (!toDexalot) p.portionStates[portionId] = PortionStates.Withdrawn;
                else p.portionStates[portionId] = PortionStates.WithdrawnToDexalot;

                // Withdraw percent which is unlocked at that portion
                totalToWithdraw = totalToWithdraw.add(p.portionAmounts[portionId]);
            }
        }

        if (totalToWithdraw > 0) {
            // Transfer tokens to user
            sale.token.safeTransfer(msg.sender, totalToWithdraw);
            // Trigger an event
            emit TokensWithdrawn(msg.sender, totalToWithdraw);
            // For Dexalot withdraw approval must be made through fe
            if (toDexalot) {
                // Deposit tokens to dexalot contract - Withdraw from sale contract
                dexalotPortfolio.depositTokenFromContract(
                    msg.sender, getTokenSymbolBytes32(), totalToWithdraw
                );
                // Trigger an event
                emit TokensWithdrawnToDexalot(msg.sender, totalToWithdraw);
            }
        }
    }

    /**
     * @notice Function to add available portions to market
     * @param portions are an array of portion ids
     * @param signature is admin signed message which acts as an approval for this action
     * @param sigExpTime is signature expiration timestamp
     * @dev prices for portions are being set through be - afterwards be will provide user with signature
     */
    function addPortionsToMarket(
        uint256[] calldata portions,
        bytes calldata signature,
        uint256 sigExpTime
    ) external {
        require(block.timestamp > sale.saleEnd && sale.phase == Phases.Idle, "Sale still in progress.");
        verifySignature(
            keccak256(abi.encodePacked(msg.sender, address(this), portions, sigExpTime, "addPortionsToMarket")),
            signature
        );
        require(block.timestamp <= sigExpTime, "Signature expired.");
        for(uint256 i = 0; i < portions.length; i++) {
            Participation storage p = userToParticipation[msg.sender];
            uint256 portionId = portions[i];
            require(
                p.portionStates[portionId] == PortionStates.Available && p.portionAmounts[portionId] > 0,
                "Portion unavailable."
            );
            p.portionStates[portionId] = PortionStates.OnMarket;
        }
        marketplace.listPortions(msg.sender, portions);
    }

    /**
     * @notice Function to remove portions from market
     * @param portions is array of sale portions user wants to remove from market
     * @dev be must confirm action by giving user necessary signature
     */
    function removePortionsFromMarket(
        uint256[] calldata portions,
        bytes calldata signature,
        uint256 sigExpTime
    ) external {
        verifySignature(
            keccak256(abi.encodePacked(msg.sender, address(this), portions, sigExpTime, "removePortionsFromMarket")),
            signature
        );
        require(block.timestamp <= sigExpTime, "Signature expired.");
        for(uint256 i = 0; i < portions.length; i++) {
            Participation storage p = userToParticipation[msg.sender];
            require(p.portionStates[portions[i]] == PortionStates.OnMarket, "Portion not on market.");
            p.portionStates[portions[i]] = PortionStates.Available;
        }
        marketplace.removePortions(msg.sender, portions);
    }

    /**
     * @notice Function to transfer portions from seller to buyer
     * @dev Called by marketplace only
     */
    function transferPortions(address seller, address buyer, uint256[] calldata portions) external {
        require(msg.sender == address(marketplace), "Marketplace only.");
        Participation storage pSeller = userToParticipation[seller];
        Participation storage pBuyer = userToParticipation[buyer];
        // Initialize portions for user if hasn't participated the sale
        if(!isParticipated[buyer]) {
            _initParticipationForUser(buyer, 0, 0, block.timestamp, uint(sale.phase) /*==Phases.Idle*/, numberOfVestedPortions);
            isParticipated[buyer] = true;
        }
        uint256 totalAmountExchanged;
        for(uint256 i = 0; i < portions.length; i++) {
            uint256 portionId = portions[i];
            require(pSeller.portionStates[portionId] == PortionStates.OnMarket, "Portion unavailable.");
            pSeller.portionStates[portionId] = PortionStates.Sold;
            PortionStates portionState = pBuyer.portionStates[portionId];
            /* case 1: portion with same id is on market
               case 2: portion is available
               case 3: portion is unavailable (withdrawn or sold) */
            uint256 amountToSell = pSeller.portionAmounts[portionId];
            require(portionState != PortionStates.OnMarket, "Can't buy portion with same id you listed on market.");
            if (portionState == PortionStates.Available) {
                pBuyer.portionAmounts[portionId] += amountToSell;
            } else {
                pBuyer.portionAmounts[portionId] = amountToSell;
                pBuyer.portionStates[portionId] = PortionStates.Available;
            }
            totalAmountExchanged += amountToSell;
        }
        // Update personal stats for transfer participants
        pSeller.amountSoldOnMarketplace = pSeller.amountSoldOnMarketplace.add(totalAmountExchanged);
        pBuyer.amountBoughtOnMarketplace = pBuyer.amountBoughtOnMarketplace.add(totalAmountExchanged);
    }

    /**
     * @notice External function to withdraw earnings and/or leftover
     */
    function withdrawEarningsAndLeftover(bool earnings, bool leftover) external onlyModerator {
        // Make sure sale ended
        require(block.timestamp > sale.saleEnd);
        // Perform withdrawals
        if (earnings) withdrawEarningsInternal();
        if (leftover) withdrawLeftoverInternal();
    }

    /**
     * @notice Internal function to withdraw earnings
     */
    function withdrawEarningsInternal() internal {
        // Make sure moderator can't withdraw twice
        require(!sale.earningsWithdrawn);
        sale.earningsWithdrawn = true;
        // Earnings amount of the moderator in AVAX
        uint256 totalProfit = sale.totalAVAXRaised;
        // Perform AVAX safe transfer
        safeTransferAVAX(msg.sender, totalProfit);
    }

    /**
     * @notice Internal function to withdraw leftover
     */
    function withdrawLeftoverInternal() internal {
        // Make sure moderator can't withdraw twice
        require(!sale.leftoverWithdrawn);
        sale.leftoverWithdrawn = true;
        // Amount of tokens which are not sold
        uint256 leftover = sale.amountOfTokensToSell.sub(sale.totalTokensSold);
        if (leftover > 0) {
            sale.token.safeTransfer(msg.sender, leftover);
        }
    }

    /**
     * @notice Function to withdraw registration fees by admin
     * @dev only after sale has ended and there is fund leftover
     */
    function withdrawRegistrationFees() external onlyAdmin {
        // Gas optimization
        uint256 _registrationFees = registrationFees;
        // Require that sale is over
        require(block.timestamp > sale.saleEnd, "Sale isn't over.");
        // Check if there are accumulated fees
        require(_registrationFees > 0, "No fees accumulated.");
        // Set registration fees to zero
        registrationFees = 0;
        // Transfer AVAX to the admin wallet
        safeTransferAVAX(msg.sender, _registrationFees);
    }

    /**
     * @notice Function to withdraw all unused funds by admin
     */
    function withdrawUnusedFunds() external onlyAdmin {
        uint256 balanceAVAX = address(this).balance;
        uint256 totalReservedForRaise = sale.earningsWithdrawn ? 0 : sale.totalAVAXRaised;
        // Transfer funds to admin wallet
        safeTransferAVAX(
            msg.sender,
            balanceAVAX.sub(totalReservedForRaise.add(registrationFees))
        );
    }

    /**
     * @notice Function to get participation for passed user address
     */
    function getParticipationAmountsAndStates(address user)
    external
    view
    returns (uint256[] memory, PortionStates[] memory) {
        Participation memory p = userToParticipation[user];
        return (
            p.portionAmounts,
            p.portionStates
        );
    }

    /**
     * @notice Function to get vesting info
     */
    function getVestingInfo() external view returns (uint256[] memory, uint256[] memory) {
        return (vestingPortionsUnlockTime, vestingPercentPerPortion);
    }

    /**
     * @notice Function to remove stuck tokens from contract
     */
    function removeStuckTokens(IERC20 token, address beneficiary, uint256 amount) external onlyAdmin {
        // Require that token address does not match with sale token
        require(address(token) != address(sale.token));
        // Safe transfer token from sale contract to beneficiary
        token.safeTransfer(beneficiary, amount);
    }

    /**
     * @notice Function to switch between sale phases by admin
     */
    function changePhase(Phases _phase) external onlyAdmin {
        // Require that sale is not over for changing phase state to other than idle
        if(_phase != Phases.Idle) require(block.timestamp < sale.saleEnd);
        // switch the currently active phase
        sale.phase = _phase;
        // Emit relevant event
        emit PhaseChanged(_phase);
    }

    /**
     * @notice Function which locks setters after initial configuration
     * @dev Contract lock can be activated only once and never unlocked
     */
    function activateLock() external onlyAdmin ifUnlocked {
        // Lock the setters
        isLockOn = true;
        // Emit relevant event
        emit LockActivated(block.timestamp);
    }

    /**
     * @notice function to initialize participation structure for user
     */
    function _initParticipationForUser(
        address user,
        uint256 amountBought,
        uint256 amountAVAXPaid,
        uint256 timeParticipated,
        uint256 phaseId,
        uint256 numberOfPortions
    ) internal {
        userToParticipation[user] = Participation({
            amountBought: amountBought,
            amountAVAXPaid: amountAVAXPaid,
            timeParticipated: timeParticipated,
            phaseId: phaseId,
            portionAmounts: getEmptyUint256Array(numberOfPortions),
            portionStates: getEmptyPortionStatesArray(numberOfPortions),
            boostedAmountAVAXPaid: 0,
            boostedAmountBought: 0,
            amountBoughtOnMarketplace: 0,
            amountSoldOnMarketplace: 0
        });
    }

    /**
     * @notice function to retrieve an empty uint256 array
     */
    function getEmptyUint256Array(uint256 size) internal pure returns (uint256[] memory) {
        return new uint256[](size);
    }

    /**
     * @notice function to retrieve an empty PortionStates array
     */
    function getEmptyPortionStatesArray(uint256 size) internal pure returns (PortionStates[] memory) {
        return new PortionStates[](size);
    }

    /**
     * @notice Function to verify admin signed signatures
     */
    function verifySignature(bytes32 hash, bytes calldata signature) internal view {
        require(
            admin.isAdmin(hash.toEthSignedMessageHash().recover(signature)),
            "Invalid signature."
        );
    }

    /**
    * @notice Function to perform AVAX safe transfer
     */
    function safeTransferAVAX(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success);
    }

    /**
     * @notice Function to parse token symbol as bytes32
     */
    function getTokenSymbolBytes32() internal view returns (bytes32 _symbol) {
        // Get token symbol
        string memory symbol = IERC20Metadata(address(sale.token)).symbol();
        // Check if token has a valid symbol
        require(bytes(symbol).length > 0, "Token does not contain a valid symbol.");
        // Parse token symbol to bytes32
        assembly {
            _symbol := mload(add(symbol, 32))
        }
    }

    /**
     * @notice Function to handle receiving AVAX
     */
    receive() external payable {}
}
