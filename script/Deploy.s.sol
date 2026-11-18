// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {AevumPay} from "../src/AevumPay.sol";

/// @notice Deploy AevumPay to QDay Aevum testnet (chain ID 44005).
/// @dev Uses the official tUSD8 token. Testnet only — never mainnet.
///      Run: forge script script/Deploy.s.sol --rpc-url aevum --broadcast
contract Deploy is Script {
    /// Official tUSD8 on Aevum testnet (QDay wiki, Token list; verified
    /// on-chain: name/symbol "tUSD8", 6 decimals).
    address public constant TUSD8 = 0x456569838f1d43009A91ebA4263147Afd7233483;

    function run() external returns (AevumPay pay) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(key);
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        require(block.chainid == 44005, "NOT_AEVUM_TESTNET");

        vm.startBroadcast(key);
        pay = new AevumPay(TUSD8);
        vm.stopBroadcast();

        console.log("AevumPay deployed:", address(pay));
        console.log("tUSD8:", TUSD8);
    }
}
