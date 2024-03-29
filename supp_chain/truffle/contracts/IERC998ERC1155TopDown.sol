// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/* import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/IERC1155Receiver.sol"; */
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

interface IERC998ERC1155TopDown is IERC721, IERC1155Receiver {
    event ReceivedChild(address indexed from, uint256 indexed toTokenId, address indexed childContract, uint256 childTokenId, uint256 amount);
    event TransferSingleChild(uint256 indexed fromTokenId, address indexed to, address indexed childContract, uint256 childTokenId, uint256 amount);
    event TransferBatchChild(uint256 indexed fromTokenId, address indexed to, address indexed childContract, uint256[] childTokenIds, uint256[] amounts);
    // event Transfer998Child(uint256 indexed fromTokenId, address indexed to, address indexed childContract, uint256 childTokenId);

    function childContractsFor(uint256 tokenId) external view returns (address[] memory childContracts);
    function childIdsOwned(uint256 tokenId, address childContract) external view returns (uint256[] memory childIds);
    function childBalance(uint256 tokrnId, address childContract, uint256 childTokenId) external view returns(uint256);

    function safeTransferChildFrom(uint256 fromTokenId, uint256 root, address to, address childContract, uint256 childTokenId, uint256 amount, bytes calldata data) external;
    function safeBatchTransferChildFrom(uint256 fromTokenId, address to, address childContract, uint256[] calldata childTokenIds, uint256[] calldata amounts, bytes calldata data) external;
}
