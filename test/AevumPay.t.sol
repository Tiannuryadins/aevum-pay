// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {AevumPay} from "../src/AevumPay.sol";
import {MockUSD8} from "../src/MockUSD8.sol";

contract AevumPayTest is Test {
    AevumPay public pay;
    MockUSD8 public tusd8;

    address public payer = address(0x1001);
    address public merchant = address(0x2002);
    address public stranger = address(0x3003);

    uint256 public constant AMOUNT = 500_000; // 0.50 tUSD8 (6 decimals)
    uint256 public constant EXPIRY = 1 hours;

    function setUp() public {
        tusd8 = new MockUSD8();
        pay = new AevumPay(address(tusd8));
        tusd8.mint(payer, 1_000_000); // 1.00 tUSD8, like one faucet drip
    }

    function _fundedInvoice() internal returns (uint256 id) {
        vm.prank(payer);
        id = pay.createInvoice(merchant, AMOUNT, EXPIRY, "order-001");
        vm.prank(payer);
        tusd8.approve(address(pay), AMOUNT);
        vm.prank(payer);
        pay.fundInvoice(id);
    }

    // --- happy path ---

    function test_endToEnd() public {
        uint256 merchantBefore = tusd8.balanceOf(merchant);
        uint256 payerBefore = tusd8.balanceOf(payer);

        uint256 id = _fundedInvoice();
        assertEq(uint256(pay.getInvoice(id).status), uint256(AevumPay.Status.Funded));
        assertEq(tusd8.balanceOf(address(pay)), AMOUNT);
        assertEq(tusd8.balanceOf(payer), payerBefore - AMOUNT);

        vm.prank(payer);
        pay.confirmDelivery(id);

        assertEq(uint256(pay.getInvoice(id).status), uint256(AevumPay.Status.Released));
        assertEq(tusd8.balanceOf(merchant), merchantBefore + AMOUNT);
        assertEq(tusd8.balanceOf(address(pay)), 0);
    }

    function test_refundAfterExpiry() public {
        uint256 id = _fundedInvoice();
        uint256 payerBefore = tusd8.balanceOf(payer);

        vm.warp(block.timestamp + EXPIRY + 1);
        vm.prank(payer);
        pay.refundInvoice(id);

        assertEq(uint256(pay.getInvoice(id).status), uint256(AevumPay.Status.Refunded));
        assertEq(tusd8.balanceOf(payer), payerBefore + AMOUNT);
        assertEq(tusd8.balanceOf(address(pay)), 0);
    }

    function test_cancelUnfunded() public {
        vm.prank(payer);
        uint256 id = pay.createInvoice(merchant, AMOUNT, EXPIRY, "order-002");
        vm.prank(payer);
        pay.cancelInvoice(id);
        assertEq(uint256(pay.getInvoice(id).status), uint256(AevumPay.Status.Cancelled));
    }

    function test_invoiceFields() public {
        vm.prank(payer);
        uint256 id = pay.createInvoice(merchant, AMOUNT, EXPIRY, "order-003");
        AevumPay.Invoice memory inv = pay.getInvoice(id);
        assertEq(inv.id, id);
        assertEq(inv.payer, payer);
        assertEq(inv.merchant, merchant);
        assertEq(inv.amount, AMOUNT);
        assertEq(inv.expiresAt, block.timestamp + EXPIRY);
        assertEq(inv.memo, "order-003");
        assertEq(uint256(inv.status), uint256(AevumPay.Status.Created));
    }

    // --- reverts ---

    function test_revert_create_zeroAmount() public {
        vm.prank(payer);
        vm.expectRevert("ZERO_AMOUNT");
        pay.createInvoice(merchant, 0, EXPIRY, "x");
    }

    function test_revert_create_zeroMerchant() public {
        vm.prank(payer);
        vm.expectRevert("ZERO_MERCHANT");
        pay.createInvoice(address(0), AMOUNT, EXPIRY, "x");
    }

    function test_revert_create_selfPay() public {
        vm.prank(payer);
        vm.expectRevert("SELF_PAY");
        pay.createInvoice(payer, AMOUNT, EXPIRY, "x");
    }

    function test_revert_create_zeroExpiry() public {
        vm.prank(payer);
        vm.expectRevert("ZERO_EXPIRY");
        pay.createInvoice(merchant, AMOUNT, 0, "x");
    }

    function test_revert_fund_twice() public {
        uint256 id = _fundedInvoice();
        vm.prank(payer);
        vm.expectRevert("NOT_CREATED");
        pay.fundInvoice(id);
    }

    function test_revert_fund_byNonPayer() public {
        vm.prank(payer);
        uint256 id = pay.createInvoice(merchant, AMOUNT, EXPIRY, "x");
        vm.prank(stranger);
        vm.expectRevert("NOT_PAYER");
        pay.fundInvoice(id);
    }

    function test_revert_fund_withoutApproval() public {
        vm.prank(payer);
        uint256 id = pay.createInvoice(merchant, AMOUNT, EXPIRY, "x");
        vm.prank(payer);
        vm.expectRevert("ALLOWANCE");
        pay.fundInvoice(id);
    }

    function test_revert_fund_afterExpiry() public {
        vm.prank(payer);
        uint256 id = pay.createInvoice(merchant, AMOUNT, EXPIRY, "x");
        vm.warp(block.timestamp + EXPIRY + 1);
        vm.prank(payer);
        tusd8.approve(address(pay), AMOUNT);
        vm.prank(payer);
        vm.expectRevert("EXPIRED");
        pay.fundInvoice(id);
    }

    function test_revert_confirm_unfunded() public {
        vm.prank(payer);
        uint256 id = pay.createInvoice(merchant, AMOUNT, EXPIRY, "x");
        vm.prank(payer);
        vm.expectRevert("NOT_FUNDED");
        pay.confirmDelivery(id);
    }

    function test_revert_confirm_byMerchant() public {
        uint256 id = _fundedInvoice();
        vm.prank(merchant);
        vm.expectRevert("NOT_PAYER");
        pay.confirmDelivery(id);
    }

    function test_revert_confirm_twice() public {
        uint256 id = _fundedInvoice();
        vm.prank(payer);
        pay.confirmDelivery(id);
        vm.prank(payer);
        vm.expectRevert("NOT_FUNDED");
        pay.confirmDelivery(id);
    }

    function test_revert_refund_beforeExpiry() public {
        uint256 id = _fundedInvoice();
        vm.prank(payer);
        vm.expectRevert("NOT_EXPIRED");
        pay.refundInvoice(id);
    }

    function test_revert_refund_byNonPayer() public {
        uint256 id = _fundedInvoice();
        vm.warp(block.timestamp + EXPIRY + 1);
        vm.prank(stranger);
        vm.expectRevert("NOT_PAYER");
        pay.refundInvoice(id);
    }

    function test_revert_cancel_funded() public {
        uint256 id = _fundedInvoice();
        vm.prank(payer);
        vm.expectRevert("NOT_CREATED");
        pay.cancelInvoice(id);
    }

    function test_revert_unknownInvoice() public {
        vm.prank(payer);
        vm.expectRevert("NOT_PAYER");
        pay.fundInvoice(999);
    }
}
