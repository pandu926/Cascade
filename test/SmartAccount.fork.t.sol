// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Cascade} from "../src/Cascade.sol";
import {CascadeAccount} from "../src/aa/CascadeAccount.sol";
import {AccountFactory} from "../src/aa/AccountFactory.sol";
import {IEntryPoint} from "../src/aa/IEntryPoint.sol";
import {PackedUserOperation} from "../src/aa/PackedUserOperation.sol";

/// @title SmartAccount fork test — the PRIMARY zero-fund proof of AA-02 + AA-03.
/// @notice Forks atlantic-testnet and drives a self-bundled `handleOps` against the
///         REAL EntryPoint v0.7 (0x0000000071727De22E5E9d8BAf0edAc6f37da032) and the
///         REAL deployed Cascade (0xd41C32562D0BE20D354120E1De11A91abC340F50). One
///         UserOperation makes the counterfactual `CascadeAccount` pay two skills in a
///         single batch; two distinct creator balances rise summing to the two prices.
/// @dev Cascade's per-skill `price` is `internal` (no public getter), so this test
///      registers its OWN skills on the real on-chain Cascade (register() is public) —
///      using the real contract bytecode at the canonical address while controlling the
///      exact prices needed for an exact `msg.value`. Zero real funds: `vm.deal` funds
///      the counterfactual account on the fork; the real EntryPoint validates the op.
contract SmartAccountForkTest is Test {
    // Live, VERIFIED on atlantic-testnet (chainId 688689).
    IEntryPoint internal constant EP = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
    Cascade internal constant CASCADE = Cascade(0xd41C32562D0BE20D354120E1De11A91abC340F50);

    // Generous gas limits per RESEARCH Pitfall 4: verificationGasLimit must cover the
    // CREATE2 account deploy that happens inside validation on the first (initCode) op.
    uint128 internal constant VERIFICATION_GAS_LIMIT = 600_000;
    uint128 internal constant CALL_GAS_LIMIT = 400_000;
    uint256 internal constant PRE_VERIFICATION_GAS = 80_000;

    AccountFactory internal factory;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("atlantic_testnet"));
        factory = new AccountFactory(EP);
    }

    // --- skill registration on the REAL Cascade ----------------------------

    function _empty() internal pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    /// @dev Register a fresh leaf skill on the live Cascade with a known price + creator.
    function _registerLeaf(address creator, uint256 price) internal returns (uint256 id) {
        vm.prank(creator);
        id = CASCADE.register(price, _empty(), _empty());
    }

    // --- UserOp builder (shared by every test; no copy-paste of pack/sign) -

    /// @dev Pack two uint128s high|low per the v0.7 layout (RESEARCH Pattern 1).
    function _pack(uint128 high, uint128 low) internal pure returns (bytes32) {
        return bytes32((uint256(high) << 128) | uint256(low));
    }

    /// @dev Build a fully-packed op and sign the eth-signed-prefixed `getUserOpHash`
    ///      (authoritative hash from the real EntryPoint) with `signerPk`. The account
    ///      validates against this exact prefix scheme (CascadeAccount._recover).
    function _buildSignedOp(
        address sender,
        bytes memory initCode,
        bytes memory callData,
        uint256 signerPk
    ) internal returns (PackedUserOperation memory op) {
        // Fees must clear the fork basefee (legacy-safe: maxFee == maxPriority).
        uint128 fee = uint128(block.basefee < 1 gwei ? 2 gwei : block.basefee * 2);

        op = PackedUserOperation({
            sender: sender,
            nonce: EP.getNonce(sender, 0),
            initCode: initCode,
            callData: callData,
            accountGasLimits: _pack(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: PRE_VERIFICATION_GAS,
            gasFees: _pack(fee, fee),
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = EP.getUserOpHash(op);
        bytes32 ethHash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethHash);
        op.signature = abi.encodePacked(r, s, v);
    }

    /// @dev initCode = factory(20 bytes) ++ createAccount(owner, salt) calldata.
    function _initCode(address owner, uint256 salt) internal view returns (bytes memory) {
        return abi.encodePacked(
            address(factory),
            abi.encodeWithSelector(AccountFactory.createAccount.selector, owner, salt)
        );
    }

    /// @dev callData = executeBatch(dest[], value[], func[]).
    function _batchInvoke(uint256[2] memory ids, uint256[2] memory prices)
        internal
        pure
        returns (bytes memory)
    {
        address[] memory dest = new address[](2);
        dest[0] = address(CASCADE);
        dest[1] = address(CASCADE);
        uint256[] memory val = new uint256[](2);
        val[0] = prices[0];
        val[1] = prices[1];
        bytes[] memory fn = new bytes[](2);
        fn[0] = abi.encodeWithSelector(Cascade.invoke.selector, ids[0]);
        fn[1] = abi.encodeWithSelector(Cascade.invoke.selector, ids[1]);
        return abi.encodeWithSelector(CascadeAccount.executeBatch.selector, dest, val, fn);
    }

    /// @dev callData = executeBatch([cascade],[price],[invoke(id)]) — single-element batch.
    function _singleInvoke(uint256 id, uint256 price) internal pure returns (bytes memory) {
        address[] memory dest = new address[](1);
        dest[0] = address(CASCADE);
        uint256[] memory val = new uint256[](1);
        val[0] = price;
        bytes[] memory fn = new bytes[](1);
        fn[0] = abi.encodeWithSelector(Cascade.invoke.selector, id);
        return abi.encodeWithSelector(CascadeAccount.executeBatch.selector, dest, val, fn);
    }

    /// @dev Wrap a single op into the ops[] array `handleOps` expects.
    function _ops(PackedUserOperation memory op)
        internal
        pure
        returns (PackedUserOperation[] memory ops)
    {
        ops = new PackedUserOperation[](1);
        ops[0] = op;
    }

    // --- Task 1: happy path -------------------------------------------------

    /// @notice ONE self-bundled `handleOps` through the REAL EntryPoint v0.7 makes the
    ///         counterfactual smart account pay TWO skills in a single batch; the two
    ///         creators' balances rise summing exactly to the two prices, and the account
    ///         is deployed (initCode) during validation. AA-02 + AA-03, zero funds.
    function test_smartAccount_batches_two_invokes() public {
        (address owner, uint256 ownerPk) = makeAddrAndKey("owner");
        address creator1 = makeAddr("creator1");
        address creator2 = makeAddr("creator2");
        uint256 price1 = 0.001 ether;
        uint256 price2 = 0.002 ether;

        // Fresh skills on the REAL Cascade — exact prices control msg.value.
        uint256 id1 = _registerLeaf(creator1, price1);
        uint256 id2 = _registerLeaf(creator2, price2);

        address sender = factory.getAddress(owner, 0);
        assertEq(sender.code.length, 0, "account must be counterfactual (not yet deployed)");

        // Fund the counterfactual account: covers the two invoke values + EntryPoint prefund.
        vm.deal(sender, 100 ether);

        PackedUserOperation memory op = _buildSignedOp(
            sender,
            _initCode(owner, 0),
            _batchInvoke([id1, id2], [price1, price2]),
            ownerPk
        );

        uint256 before1 = CASCADE.balances(creator1);
        uint256 before2 = CASCADE.balances(creator2);

        // EOA self-bundles: this contract is the beneficiary (collects gas fees).
        EP.handleOps(_ops(op), payable(address(this)));

        uint256 delta1 = CASCADE.balances(creator1) - before1;
        uint256 delta2 = CASCADE.balances(creator2) - before2;

        assertGt(sender.code.length, 0, "account deployed via initCode during validation");
        assertEq(delta1, price1, "creator1 balance rose by price1");
        assertEq(delta2, price2, "creator2 balance rose by price2");
        assertEq(delta1 + delta2, price1 + price2, "sum of deltas == both prices");
    }

    /// @notice Named alias asserting the op settles through the REAL EntryPoint v0.7 —
    ///         the canonical AA-03 settlement proof (artifact contract: this name must
    ///         exist). Single-op handleOps deploys + invokes; the creator balance rises.
    function test_handleOps_settles_via_real_entrypoint() public {
        (address owner, uint256 ownerPk) = makeAddrAndKey("owner-settle");
        address creator = makeAddr("creator-settle");
        uint256 price = 0.0015 ether;
        uint256 id = _registerLeaf(creator, price);

        address sender = factory.getAddress(owner, 0);
        vm.deal(sender, 100 ether);

        PackedUserOperation memory op =
            _buildSignedOp(sender, _initCode(owner, 0), _singleInvoke(id, price), ownerPk);

        uint256 before = CASCADE.balances(creator);
        EP.handleOps(_ops(op), payable(address(this)));

        assertGt(sender.code.length, 0, "settled: account deployed via real EntryPoint");
        assertEq(CASCADE.balances(creator) - before, price, "settled: creator credited via real EntryPoint");
    }

    // --- Task 2: negative AA24 (wrong signer) ------------------------------

    /// @notice A UserOp identical to the happy path but signed by a NON-owner key is
    ///         rejected: validateUserOp returns 1, the EntryPoint reverts FailedOp with
    ///         the "AA24 signature error" reason, nothing settles, and the target
    ///         creator's balance is unchanged (T-03-05: wrong signer cannot settle).
    function test_handleOps_rejects_wrong_signer() public {
        (address owner,) = makeAddrAndKey("owner-neg");
        (, uint256 attackerPk) = makeAddrAndKey("attacker");
        address creator = makeAddr("creator-neg");
        uint256 price = 0.001 ether;
        uint256 id = _registerLeaf(creator, price);

        address sender = factory.getAddress(owner, 0);
        vm.deal(sender, 100 ether);

        // Same op (owner is the account owner), but signed by the ATTACKER key.
        PackedUserOperation memory op =
            _buildSignedOp(sender, _initCode(owner, 0), _singleInvoke(id, price), attackerPk);

        uint256 before = CASCADE.balances(creator);

        // EntryPoint surfaces FailedOp(0, "AA24 signature error"). Match the AA24 reason
        // explicitly so a different revert (e.g. AA21/AA13) fails the test loudly.
        vm.expectRevert(
            abi.encodeWithSignature("FailedOp(uint256,string)", uint256(0), "AA24 signature error")
        );
        EP.handleOps(_ops(op), payable(address(this)));

        assertEq(sender.code.length, 0, "rejected op must NOT deploy the account");
        assertEq(CASCADE.balances(creator), before, "rejected op must NOT credit the creator");
    }

    // --- Task 2: account-agnostic parity (CORE-07) -------------------------

    /// @notice The smart-account invoke path credits creators IDENTICALLY to a direct
    ///         EOA invoke of the same skill — Cascade.sol is unchanged and treats both
    ///         caller types the same. Two equal-priced sibling skills (same shape) are
    ///         used so the only difference is the caller (smart account vs EOA).
    function test_account_agnostic_parity() public {
        uint256 price = 0.001 ether;

        // Two structurally-identical leaf skills, distinct creators.
        address creatorSa = makeAddr("creator-sa");
        address creatorEoa = makeAddr("creator-eoa");
        uint256 idSa = _registerLeaf(creatorSa, price);
        uint256 idEoa = _registerLeaf(creatorEoa, price);

        // (a) Smart-account path: one single-element executeBatch via handleOps.
        (address owner, uint256 ownerPk) = makeAddrAndKey("owner-parity");
        address sender = factory.getAddress(owner, 0);
        vm.deal(sender, 100 ether);

        PackedUserOperation memory op =
            _buildSignedOp(sender, _initCode(owner, 0), _singleInvoke(idSa, price), ownerPk);

        uint256 saBefore = CASCADE.balances(creatorSa);
        EP.handleOps(_ops(op), payable(address(this)));
        uint256 saDelta = CASCADE.balances(creatorSa) - saBefore;

        // (b) Direct EOA path: a plain invoke{value} of the sibling skill.
        address eoa = makeAddr("plain-eoa");
        vm.deal(eoa, price);
        uint256 eoaBefore = CASCADE.balances(creatorEoa);
        vm.prank(eoa);
        CASCADE.invoke{value: price}(idEoa);
        uint256 eoaDelta = CASCADE.balances(creatorEoa) - eoaBefore;

        // Parity: the smart-account-driven invoke credits exactly like the EOA invoke.
        assertEq(saDelta, price, "smart-account invoke credits full price");
        assertEq(saDelta, eoaDelta, "smart-account delta == EOA delta (account-agnostic)");
    }

    receive() external payable {}
}
