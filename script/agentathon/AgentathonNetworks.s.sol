// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract AgentathonNetworks {
    string[] public networks = ["optimism", "arbitrum", "celo", "linea", "avalanche"];
    address[][] public tokens = [
        [0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85, /* USDC */ 0x4200000000000000000000000000000000000006 /* WETH */ ],
        [0xaf88d065e77c8cC2239327C5EDb3A432268e5831, /* USDC */ 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 /* WETH */ ],
        [0x765DE816845861e75A25fCA122bb6898B8B1282a, /* CUSD */ 0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73 /* CEUR */ ],
        [0x176211869cA2b568f2A7D4EE941E073a821EE1ff, /* USDCe */ 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f /* WETH */ ],
        [0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E, /* USDC */ 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7 /* WAVAX */ ]
    ];
    address[] public swapRouters = [
        address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45),
        address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45),
        address(0x5615CDAb10dc425a742d643d949a7F474C01abc4),
        address(0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a),
        address(0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE)
    ];
}
