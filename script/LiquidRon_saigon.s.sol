// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/LiquidRon.sol";

contract CounterScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
		
		address ronStaking = 0x9C245671791834daf3885533D24dce516B763B28;
		address wrappedRon = 0xA959726154953bAe111746E265E6d754F48570E6;
		address feeRecipient = 0x00000000000CbA43Ae9379E73c0ccB4E08D7eD30;
        address profile = 0x3b67c8D22a91572a6AB18acC9F70787Af04A4043;

        address[] memory consensusAddrs = new address[](5);
        consensusAddrs[0] =  0xD086D2e3Fac052A3f695a4e8905Ce1722531163C;
        consensusAddrs[1] =  0x726F02987863F4aeEACC94a81ef6755A58Ed676B;
        consensusAddrs[2] =  0x79e662A58bfBE044A4d92D202DD32BB635053035;
        consensusAddrs[3] =  0xE9bf2A788C27dADc6B169d52408b710d267b9bff;
        consensusAddrs[4] =  0x847c2b1F0138e82C0e12c23D9B1f58bFFBe8e43b;

        LiquidRon liquidRon = new LiquidRon(address(ronStaking), profile, address(wrappedRon), 250, feeRecipient, "Liquid RON", "lRON");
        console.log("liquidRon contract address:", address(liquidRon));
        liquidRon.deployStakingProxy();
        liquidRon.deployStakingProxy();
        console.log("proxies deployed");
        liquidRon.deposit{value:10000 ether}();
        console.log("RON deposited");
        uint256 delegateAmount = 10000 ether / 10;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
        liquidRon.delegateAmount(1, amounts, consensusAddrs);
        console.log("RON delegated");
        vm.stopBroadcast();
    }
}