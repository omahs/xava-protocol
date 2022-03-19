const hre = require("hardhat");
const { getSavedContractAddresses } = require('../utils')
const { ethers, web3 } = hre



async function main() {

    const contracts = getSavedContractAddresses()[hre.network.name];

    const wallets = [
        "0xfAc9a12C61Fd8784F115c53bF9d6dbd502F07e34","0xf89676d1443B2867d9221066Ed853F1ff281f9F2","0xbEb78f0B3f39e3f3Fc59838a860B2C5b45561d4F","0x464cCB46f2D12950667DdA4025a420DCa7066C3d","0xf7d3168f0cb6F64C284dEA2eEFE72b3D497a525D","0x9E092Bfdf8854179562B3d8F63e00B4C9feDF10a","0x166A0E0DF66Ca33cCc3B97bD83f692Cf83fBd420","0x4ebEE2a376E2dBD0BEb49128aE00D66c98a14f55","0xEfcE847D41Ebe1Ced1b7C7212Ce2ea239855a6E1","0x36eAb166cb30E30cBC7dF6071C224fdc9dC4d34F","0x7e9B1AB31a5f7FF1c89DCcB39Bc6760946e2c618","0x93d9b6C68330eE19356052562fAf3781b055CE12","0x3c5843a32920dA42934b0d52aA0f5980da2f3B54","0x4Da07a1ac19abc476B47369b10f0992a53313C15","0x680BCf08c59B70FB3Ac6225C0dc768c0DB8248dA","0x66D26242f67e25966dB209e998fcAC0dEbA48899","0x46F8779cBD8e3Ef132fFa3AA1cfc3CAC17437D20","0xBa0149Bfb19C4B0809AE263B564F2E289331c36B","0x6B2A68888E3EE39F61ec7774503C9585405B5740","0xbBd4a5F1D40C437C6015079d3e4063c04666486e","0x99a5Dc7b00F58419285Eb0cD3D447f5dA552d2d9","0xBcaef30dF7f6c103E1E54eA6df77A2DD62c3D33E","0x2abAE08416bcF2B61D9D15285F043e28de7F3E38","0x9231546A0e1F2773Ea6B0f30c691EA56E5fE2D24","0x48DfF8dF421c208343804579a90a2cB360f145dd","0x8F09D3f2F551C8c7b4C1A04aE1E46F01D2afC99c","0x1C2bae45d79c8FF7F499E2d67796E4d34a786B12","0x58A4E7dC8a13d18d3Bb59bE365982b7641B64A28","0x05E9d3b044bf812C6845f33FabfFF0509C3290c7","0xCA4477d2E813eDb32119A444D468B3FFAa97434b","0xFC7520d435d3296791571A60fa6125C58678091B","0xc6c2bD6B76Bf5F1Fb63DF95c42F36745F83c6702","0x519D5fBA523cf4Fa844d28524AC93d80c9c493D2","0xea99552aF03140457Ec1a989C8A7e9C5854093E9","0xbDB0785E7fC8aF47Be498646226cb8efdE53fB1a","0x0a7bf04d5bfB336daf7a1F44e89DBa17Fd9b3DcA","0x91CA96f95e3f352036E5cC0199A9df410CA3F10a","0xB20807E62E6fEa9EccE55bd30D42CaE6747BEe58","0x71308b70B56841F48C0Ef9C8b29d1E2e5C2b3157","0xe9256C5cDdb8a4B1B1cE49AeBE8af8c3e531543A","0x6B90ABcD35BB0E3977bCb2D6f992d6303fa4f927","0x6B2362c1ba180C22C2558529924013ae3C7dfCA7","0xf5aF2c1E38Efb3106D3895EbD6200AaE8F65832e","0xceC651634796E6f4783b6C216854ffD9c0CAbA7F","0x8E02fe775433a704216f5cbb0e0835F3dbeF8e82","0x08A6058776D0a0c6ADb2610e16eE199453E707D5","0xfEC0180f81850b376B5210F0Ee0BE529a26E22cE","0x74B3e9a2B66c64C3F8f1e2Ca2009A7CD334139B5","0x78a8447e3aB52BdeC9af409c0ad3d5BB4c27C4Cb","0xeace2AB1c530a4e427df283cAB959FD486997Fcd","0x8a7d89142023Db7c71221BABEA45081AB697F3dA","0x34569008B34DEdBF41BC9dbCC5d7AAbe6eB7E596","0xe3756018b41F19777BEa4e04C894acB5eD352D77","0x5990496F386ae8E75384933bC3E0229B62203311","0x7fa55C921C8Cf5def22243f8BB4B37D8DF7d7883","0x74C76cfA6f0ee807880b5C18A07F81A8761F856a","0x6BcCaCFbCaAc44bd84E52A844E9B30eAb40Ad4BB","0x9da5C4C283c2Fe334E2a1081A7fdae45475CeB41","0xe61E92dd9a7f7C0Af544606ac10D52F8fcE30f78","0x15870AF7A292aD698827182Fdd11b083298A9990","0x21A8652b81adb2420477Ccd3D156002E43D1BbD3","0xEECb16afB8bDde10bC540436188c4b441d75968b","0xF931CC9Cc114949b81245261C04BcC6DDb12ed8A","0xd80Ef49A7c64F8217343582b417031A5B359e1d0","0xFcCA7C390767b347549e3D2242dd8d30be925c28","0x1b1813F8993a5a21d6914c7b9375eb908a689080","0xdb0131A53EC1687c002950Ad9D66a9B983864276","0x4195B59E5De08CF9Fbf81aD9FC14E8812393135B","0xCD7ebeC46A35fd1e0CaDC367202343e67Ac7C562","0x21f22F1f7E1051C0C73CBBD0f72DB0842897C92F","0x9939197Ab41daaD7D9Be323CFC60059044C16630","0x1c19B1e9f19000aE615f762fF801C076F1DEa527","0xf25a82A7089b47c278EFB94D78CaC13aAc99867b","0x80b192e32Fa95EEfd3b076fB50519De41bFD0e5C","0xDA5Dd209717Ef264908C1181CaDc9bcE9CB19a46","0xe72EEb49B4805ba2910c57982F9353377Fa6F466","0xC1B0e8983B8cD4A5f120D5F14f38Ee8Da5312112","0x48e472D6978b8707C6C81e4Ff976B24F4Df33907","0x41Daf06CB0cB9290E698000E15820f75139b5b36","0x24Ca1771Fe1E7a0e047f22644113c6E8aD21f991","0xb00126BFa30B08014CCc63589b0E8eF0F54799Ee","0xFB999EF7d317fedc4c0F824a8Ba6BA25922E6d72","0xa4589d0E777A18E3148859bFb031465aF135df34","0xD40f0D07B9068F32843c8AE1Da38f71e380bCc74","0x75590093A908d2D413d3caE8c670C13f380668d6","0xe8241Ad35D8285965D401E23fA9dC1F6737C1CCc","0xB726Ae8dB84774f926Bf5Fbb399CfbE3f102F0D0","0x054A51a7DD8ECf12a83640fd7e25f16c777Cd8Fc","0x5b1c38BFeBC1D71a991D0Cc4f0772DB25F6365e7","0x18C6c577f3363a414aF7e2518fb9cf070EBaC76A","0x7EC31DFa3e0318D4B71344A34Dd9D51bbEc79724","0xF6aD92aF1E2Cd832dF3eEbCea2e201b00b9D71Ce","0xFF0c80920f69A5D1d8F913065642Af45E8CBadA7","0x82CfCB40c62803e27779BF1c6c83b86B2f29019A","0x7E71818e890C1B35De95A0a854D882CcD2E7E996","0x01c702bEb4270EA0be63a52610C85E63e91d2F4C","0x7e2a3b38Dc783F852360d73962C604B4b875eD07","0xF8e88100c8Dc5d6229e147561384a1289b33Edef","0xB400Dc972b08FB728CFc7373386E9d5f1125957A","0x699fB49a635306249777a66E9eD5CdD357a4607c","0x85a139E8932e0C5CD5314bBDa0E26e07B708fd8E","0x7df7b4dd91a5Ae73C95c9c96511dadb127e9bbe2","0x13Db4917a17905e4ee65C1452aE85b36d4d7C8Dd","0x6b84036e7E4ac6d11da923DF00B95897D1593deb","0x00131601ac5e26219038056144e0b055deA37075","0xd9be17980F1206B4F88240234429Ecc86EE620a6","0x77FE310e8b9e0709D93742bb76Df6a28dab5a333","0x1555e776C4BfA56581B71A58d92D7969720E27EC","0x9c868F3299E212B46E6E96B951B5A7a17Bff3940","0xf2406dFcb1b48D8772E748A62aC7528aCcE81A42","0xA7753aE84E23b6720F1A4bf104f3E7B93d730ACC","0xd6A8766D1A947FaBCB028Cb65486Bbc676A499Bc","0x9dd6D33dcC532D1278e655c4001E064ac257B2c2","0x25a4aE48B07bDB20dBf806F2acb9571A5a5C5598","0xe60996DDb83aC3cE81Cf5DA92740461a9F3A65f6","0x8511506c03b36BA1A70cF96Fc2Ebe8E52F3c9Bd7","0x2eec1678f7eEb2f0bd41446aea83689D756e5087"
    ];
    const amountETH = "0.1";

    console.log('Number of wallets to receive AVAX = ', wallets.length);

    for (let i=0; i < wallets.length; i++) {

        const signer = await ethers.provider.getSigner();
        const address = await signer.getAddress();

        const tx = await signer.sendTransaction({
            to: ethers.provider._getAddress(wallets[i]),
            value: ethers.utils.parseEther(amountETH)
        });

        console.log(`${i+1}. TxHash: ${tx.hash}`);
        console.log(`${i+1}. Receiver: ${wallets[i]}`);
        console.log('--------------------------------------------------------------------------------');
    }

}


main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });