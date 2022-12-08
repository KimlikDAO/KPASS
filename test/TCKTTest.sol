// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "contracts/TCKT.sol";
import "forge-std/Test.sol";
import "interfaces/Addresses.sol";
import "interfaces/AvalancheTokens.sol";
import "interfaces/IERC20Permit.sol";
import "interfaces/testing/MockTokens.sol";

contract TCKTTest is Test {
    TCKT private tckt;

    function setUp() public {
        vm.prank(TCKT_DEPLOYER);
        tckt = new TCKT();
        assertEq(address(tckt), TCKT_ADDR);
    }

    function testTokenURI0() public {
        assertEq(
            tckt.tokenURI(
                0x3d5bad4604650569f28733f7ad6ec22835e775a0eb20bfd809d78ed2ae8abe47
            ),
            "https://ipfs.kimlikdao.org/ipfs/QmSUAf9gusxTbZZn5nC7d44kHjfrDeu2gfSY31MRVET28n"
        );
        assertEq(
            tckt.tokenURI(
                0xd2abff978646ac494f499e9ecd6873414a0c6105196c8c2580d52769f3fc0523
            ),
            "https://ipfs.kimlikdao.org/ipfs/QmcX2ScFVAVnEHrMk3xuf7HXfiGHzmMqdpAYb37zA5mbFp"
        );
    }

    function testRevoke() public {
        assertEq(tckt.balanceOf(address(this)), 0);
        tckt.create(123123123);
        assertEq(tckt.balanceOf(address(this)), 1);
        tckt.revoke();
        assertEq(tckt.balanceOf(address(this)), 0);
    }

    function testSocialRevoke() public {
        tckt.createWithRevokers(
            123123123,
            [
                (uint256(4) << 192) |
                    (uint256(1) << 160) |
                    uint160(vm.addr(10)),
                (uint256(1) << 160) | uint160(vm.addr(11)),
                (uint256(1) << 160) | uint160(vm.addr(12)),
                (uint256(1) << 160) | uint160(vm.addr(13)),
                (uint256(1) << 160) | uint160(vm.addr(14))
            ]
        );

        assertEq(tckt.balanceOf(address(this)), 1);

        vm.prank(vm.addr(10));
        tckt.revokeFriend(address(this));
        assertEq(tckt.balanceOf(address(this)), 1);
        vm.prank(vm.addr(10));
        vm.expectRevert();
        tckt.revokeFriend(address(this));
        vm.prank(vm.addr(11));
        tckt.revokeFriend(address(this));
        assertEq(tckt.balanceOf(address(this)), 1);
        vm.prank(vm.addr(12));
        tckt.revokeFriend(address(this));
        assertEq(tckt.balanceOf(address(this)), 1);
        vm.prank(vm.addr(13));
        tckt.revokeFriend(address(this));
        assertEq(tckt.balanceOf(address(this)), 0);
    }

    function testRevokeFriendForContributor() public {
        vm.prank(vm.addr(0x1337ACC));
        tckt.createWithRevokers(
            123123123,
            [
                (uint256(4) << 192) |
                    (uint256(3) << 160) |
                    uint160(vm.addr(10)),
                (uint256(1) << 160) | uint160(vm.addr(11)),
                (uint256(1) << 160) | uint160(vm.addr(12)),
                (uint256(1) << 160) | uint160(vm.addr(13)),
                (uint256(1) << 160) | uint160(vm.addr(14))
            ]
        );

        assertEq(tckt.balanceOf(vm.addr(0x1337ACC)), 1);

        bytes32 REVOKE_FRIEND_FOR_TYPEHASH = keccak256(
            "RevokeFriendFor(address friend)"
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(REVOKE_FRIEND_FOR_TYPEHASH, vm.addr(0x1337ACC))
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(10, digest);
        vm.prank(vm.addr(100));
        tckt.revokeFriendFor(
            vm.addr(0x1337ACC),
            r,
            (uint256(v - 27) << 255) | uint256(s)
        );

        assertEq(tckt.balanceOf(vm.addr(0x1337ACC)), 1);

        vm.prank(vm.addr(11));
        tckt.revokeFriend(vm.addr(0x1337ACC));

        assertEq(tckt.balanceOf(address(this)), 0);
    }

    function testRevokeFriendFor() public {
        vm.prank(vm.addr(0x1337ACC));
        tckt.createWithRevokers(
            123123123,
            [
                (uint256(4) << 192) |
                    (uint256(3) << 160) |
                    uint160(vm.addr(10)),
                (uint256(1) << 160) | uint160(vm.addr(11)),
                (uint256(1) << 160) | uint160(vm.addr(12)),
                (uint256(1) << 160) | uint160(vm.addr(13)),
                (uint256(1) << 160) | uint160(vm.addr(14))
            ]
        );

        assertEq(tckt.balanceOf(vm.addr(0x1337ACC)), 1);

        vm.prank(vm.addr(11));
        tckt.revokeFriend(vm.addr(0x1337ACC));

        assertEq(tckt.balanceOf(vm.addr(0x1337ACC)), 1);

        bytes32 REVOKE_FRIEND_FOR_TYPEHASH = keccak256(
            "RevokeFriendFor(address friend)"
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(REVOKE_FRIEND_FOR_TYPEHASH, vm.addr(0x1337ACC))
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(10, digest);
        vm.prank(vm.addr(100));
        tckt.revokeFriendFor(
            vm.addr(0x1337ACC),
            r,
            (uint256(v - 27) << 255) | uint256(s)
        );

        assertEq(tckt.balanceOf(address(this)), 0);
    }

    function testReduceRevokeThreshold() public {
        uint256[5] memory revokers = [
            (uint256(1) << 192) | (uint256(1) << 160) | uint160(vm.addr(10)),
            (uint256(1) << 160) | uint160(vm.addr(11)),
            (uint256(1) << 160) | uint160(vm.addr(12)),
            (uint256(1) << 160) | uint160(vm.addr(13)),
            (uint256(1) << 160) | uint160(vm.addr(14))
        ];
        tckt.createWithRevokers(123123123, revokers);

        assertEq(tckt.balanceOf(address(this)), 1);
        tckt.reduceRevokeThreshold(1);
        assertEq(tckt.balanceOf(address(this)), 1);
        vm.prank(vm.addr(10));
        tckt.revokeFriend(address(this));
        assertEq(tckt.balanceOf(address(this)), 0);
    }

    function testAddRevoker() public {
        uint256[5] memory revokers = [
            (uint256(4) << 192) | (uint256(1) << 160) | uint160(vm.addr(20)),
            (uint256(1) << 160) | uint160(vm.addr(21)),
            (uint256(1) << 160) | uint160(vm.addr(12)),
            0,
            0
        ];
        tckt.createWithRevokers(123123123, revokers);

        assertEq(tckt.balanceOf(address(this)), 1);
        tckt.addRevoker((uint256(3) << 160) | uint160(vm.addr(11)));
        tckt.addRevoker((uint256(1) << 160) | uint160(vm.addr(12)));

        vm.prank(vm.addr(11));
        tckt.revokeFriend(address(this));
        assertEq(tckt.balanceOf(address(this)), 1);

        vm.prank(vm.addr(12));
        tckt.revokeFriend(address(this));
        assertEq(tckt.balanceOf(address(this)), 0);
    }

    function testAuthenticationPriceFeeder() public {
        vm.expectRevert();
        tckt.updatePrice((15 << 160) | uint160(vm.addr(1)));

        vm.prank(OYLAMA);
        tckt.updatePrice((15 << 160) | uint160(vm.addr(1)));
        assertEq(uint128(tckt.priceIn(vm.addr(1))), 15);

        uint256[] memory prices = new uint256[](1);
        prices[0] = (17 << 160) | 1337;

        vm.expectRevert();
        tckt.updatePricesBulk((1 << 128) + 1, prices);

        vm.prank(OYLAMA);
        tckt.updatePricesBulk((1 << 128) + 1, prices);
        assertEq(uint128(tckt.priceIn(address(1337))), 17);
    }

    function testCreate() public {
        vm.prank(OYLAMA);
        tckt.updatePrice(5e16 << 160);

        vm.expectRevert();
        tckt.create(123123123);

        vm.expectRevert();
        tckt.create{value: 0.04 ether}(123123123);

        vm.prank(OYLAMA);
        tckt.updatePrice(4e16 << 160);

        tckt.create{value: 0.06 ether}(1231231233);
        tckt.create{value: 0.07 ether}(123123123);

        vm.prank(OYLAMA);
        tckt.updatePrice(5e16 << 160);

        vm.expectRevert();
        tckt.create{value: 0.074 ether}(123123123);

        tckt.create{value: 0.075 ether}(1231231233);
    }

    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /**
     * Authorizes a payment from `vm.addr(0x1337ACC)` for the spender
     * `TCKT_ADDR`.
     */
    function authorizePayment(
        IERC20Permit token,
        uint256 amount,
        uint256 deadline,
        uint256 nonce
    )
        internal
        view
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        vm.addr(0x1337ACC),
                        TCKT_ADDR,
                        amount,
                        nonce,
                        deadline
                    )
                )
            )
        );
        return vm.sign(0x1337ACC, digest);
    }

    function testUSDTPayment() public {
        DeployMockTokens();

        vm.prank(OYLAMA);
        // Set TCKT price to 2 USDT
        tckt.updatePrice((2e6 << 160) | uint160(address(USDT)));

        vm.prank(USDT_DEPLOYER);
        USDT.transfer(vm.addr(0x1337ACC), 15e6);

        {
            uint256 deadline = block.timestamp + 1200;
            (uint8 v, bytes32 r, bytes32 s) = authorizePayment(
                USDT,
                3e6,
                deadline,
                0
            );

            vm.prank(vm.addr(0x1337ACC));
            uint256 deadlineAndToken = (deadline << 160) |
                uint160(address(USDT));
            uint256 ss = (uint256(v - 27) << 255) | uint256(s);
            tckt.createWithTokenPermit(123123123, deadlineAndToken, r, ss);
            assertEq(tckt.balanceOf(vm.addr(0x1337ACC)), 1);
        }

        vm.prank(vm.addr(0x1337ACC));
        tckt.revoke();
        {
            uint256 deadline = block.timestamp + 1200;
            (uint8 v, bytes32 r, bytes32 s) = authorizePayment(
                USDT,
                3e6,
                deadline,
                1
            );
            uint256 ss = (uint256(v - 27) << 255) | uint256(s);
            uint256 deadlineAndToken = (deadline << 160) |
                uint160(address(USDT));
            vm.prank(vm.addr(0x1337ACC));
            tckt.createWithTokenPermit(123123123, deadlineAndToken, r, ss);
            assertEq(tckt.balanceOf(vm.addr(0x1337ACC)), 1);
        }
        vm.prank(vm.addr(0x1337ACC));
        tckt.revoke();
        {
            uint256 deadline = block.timestamp + 1200;
            (uint8 v, bytes32 r, bytes32 s) = authorizePayment(
                USDT,
                2.999999e6,
                deadline,
                2
            );
            uint256 ss = (uint256(v - 27) << 255) | uint256(s);
            uint256 deadlineAndToken = (deadline << 160) |
                uint160(address(USDT));
            vm.prank(vm.addr(0x1337ACC));
            vm.expectRevert();
            tckt.createWithTokenPermit(123123123, deadlineAndToken, r, ss);
        }
    }

    bytes32 DOMAIN_SEPARATOR =
        0x7f09fc8776645c556371127677a2206a00976e7f49fa8690739ee07c5b3bc805;

    // keccak256("CreateFor(uint256 handle)")
    bytes32 CREATE_FOR_TYPEHASH =
        0xe0b70ef26ac646b5fe42b7831a9d039e8afa04a2698e03b3321e5ca3516efe70;

    function authorizeCreateFor(uint256 handle)
        public
        view
        returns (bytes32, uint256)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(CREATE_FOR_TYPEHASH, handle))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x1337ACC, digest);
        return (r, (uint256(v - 27) << 255) | uint256(s));
    }

    function testCreateFor() public {
        DeployMockTokens();

        vm.prank(OYLAMA);
        // Set TCKT price to 2 USDT
        tckt.updatePrice((2e6 << 160) | uint160(address(USDT)));

        vm.prank(USDT_DEPLOYER);
        USDT.transfer(vm.addr(0x1337ACC), 15e6);

        {
            uint256 deadline = block.timestamp + 1200;
            (uint8 v, bytes32 paymentR, bytes32 s) = authorizePayment(
                USDT,
                3e6, // 2 * 1.5 for revokerless premium.
                deadline,
                0
            );

            uint256 deadlineAndToken = (deadline << 160) |
                uint160(address(USDT));
            uint256 paymentSS = (uint256(v - 27) << 255) | uint256(s);
            (bytes32 createR, uint256 createSS) = authorizeCreateFor(123123123);
            tckt.createFor(
                123123123,
                createR,
                createSS,
                deadlineAndToken,
                paymentR,
                paymentSS
            );
            assertEq(tckt.balanceOf(vm.addr(0x1337ACC)), 1);
        }

        vm.prank(vm.addr(0x1337ACC));
        tckt.revoke();
        {
            uint256 deadline = block.timestamp + 1200;
            (uint8 v, bytes32 paymentR, bytes32 s) = authorizePayment(
                USDT,
                2.99e6,
                deadline,
                0
            );

            uint256 deadlineAndToken = (deadline << 160) |
                uint160(address(USDT));
            uint256 paymentSS = (uint256(v - 27) << 255) | uint256(s);
            (bytes32 createR, uint256 createSS) = authorizeCreateFor(123123123);
            vm.expectRevert();
            tckt.createFor(
                123123123,
                createR,
                createSS,
                deadlineAndToken,
                paymentR,
                paymentSS
            );
        }
    }

    function testAuthenticationValidtorNodes() public {
        vm.prank(OYLAMA);
        tckt.addValidatorNode(vm.addr(10));

        vm.expectRevert();
        tckt.addValidatorNode(vm.addr(11));

        vm.prank(OYLAMA);
        tckt.banValidatorNode(vm.addr(12));

        vm.expectRevert();
        tckt.banValidatorNode(vm.addr(13));
    }

    function testValidatorNodes() public {
        vm.warp(131);
        vm.prank(OYLAMA);
        tckt.addValidatorNode(vm.addr(131150));

        vm.expectRevert();
        tckt.addValidatorNode(vm.addr(131150));

        vm.warp(150);
        vm.prank(OYLAMA);
        tckt.banValidatorNode(vm.addr(131150));

        assertEq(
            tckt.validatorNodes(vm.addr(131150)),
            (uint256(131) << 128) + 150
        );

        vm.warp(160);
        vm.prank(OYLAMA);
        vm.expectRevert();
        tckt.banValidatorNode(vm.addr(131150));
    }
}
