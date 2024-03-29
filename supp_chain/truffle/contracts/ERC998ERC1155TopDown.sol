// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/*
// for remix
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155Receiver.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/EnumerableSet.sol";
*/

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./IERC998ERC1155TopDown.sol";

contract ERC998ERC1155TopDown is ERC721, IERC1155Receiver, IERC998ERC1155TopDown, IERC721Receiver {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public _balances;
    mapping(address => mapping(uint256 => EnumerableSet.UintSet)) private _holdersOf;

    mapping(uint256 => EnumerableSet.AddressSet) private _childContract;
    mapping(uint256 => mapping(address => EnumerableSet.UintSet)) private _childsForChildContract;

    mapping(uint256 => bool) public isERC721;
    mapping(uint256 => bool) public isERC1155;
    
    // mapping from tokenID to IPFS hash
    mapping(uint256 => string) public token_URI;

    uint256[] public rootOwners;

    constructor(string memory name, string memory symbol, string memory baseURI) ERC721(name, symbol) public {
        _baseURI();
    }

    // set tokenURI
    function setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        token_URI[tokenId] = _tokenURI;
    }

    // get tokenURI
    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        return token_URI[tokenId];
    }


    /**
     * @dev Gives child balance for a specific child contract and child id .
     */
    function childBalance(uint256 tokenId, address childContract, uint256 childTokenId) external view override returns(uint256) {
        return _balances[tokenId][childContract][childTokenId];
    }

    /**
     * @dev Gives list of child contract where token ID has childs.
     */
    function childContractsFor(uint256 tokenId) override external view returns (address[] memory) {
        address[] memory childContracts = new address[](_childContract[tokenId].length());

        for(uint256 i = 0; i < _childContract[tokenId].length(); i++) {
            childContracts[i] = _childContract[tokenId].at(i);
        }

        return childContracts;
    }

    /**
     * @dev Gives list of owned child ID on a child contract by parent token ID and child contract.
     */
    function childIdsOwned(uint256 tokenId, address childContract) override external view returns (uint256[] memory) {
        uint256[] memory childTokenIds = new uint256[](_childsForChildContract[tokenId][childContract].length());

        for(uint256 i = 0; i < _childsForChildContract[tokenId][childContract].length(); i++) {
            childTokenIds[i] = _childsForChildContract[tokenId][childContract].at(i);
        }

        return childTokenIds;
    }

    /**
     * @dev set root owner
     */
    function setRootOwner(uint256 id) public {
        rootOwners.push(id);
    }

    /**
     * @dev gets root owners
     */
    function getRootOwners() external view returns(uint256 [] memory){
        return rootOwners;
    }

    // /**
    //  * @dev gets root owner for child
    //  */
    // function getRootOwnerID(uint256 childID, address childContract) external view returns(uint256){
    //     uint256 ro = 0;
    //     for(uint256 i = 0; i < rootOwners.length; i++){
    //         uint256[] memory childTokenIds = childIdsOwned(i, childContract);
    //         for(uint256 j = 0; j < childTokenIds.length; j++){
    //             if(j == childID){
    //                 ro = i;
    //             }
    //         }
    //     }

    //     return ro;
    // }

    /**
     * @dev Transfers child token from a token ID.
     */
    function safeTransferChildFrom(uint256 fromTokenId, uint256 root, address to, address childContract, uint256 childTokenId, uint256 amount, bytes memory data) public override {
        require(to != address(0), "ERC998: transfer to the zero address");

        address operator = _msgSender();
        // uint256 o = _holdersOf[childContract][childTokenId];
        require(
            ownerOf(root) == operator,
            "ERC998: caller is not owner nor approved"
        );

        _beforeChildTransfer(operator, fromTokenId, to, childContract, _asSingletonArray(childTokenId), _asSingletonArray(amount), data);

        _removeChild(fromTokenId, childContract, childTokenId, amount);

        // TODO: maybe check if to == this
        if(isERC1155[childTokenId]){
            ERC1155(childContract).safeTransferFrom(address(this), to, childTokenId, amount, data);
            emit TransferSingleChild(fromTokenId, to, childContract, childTokenId, amount);
        } else {
            ERC721(childContract).safeTransferFrom(address(this), to, childTokenId, data);
            emit TransferSingleChild(fromTokenId, to, childContract, childTokenId, amount);
        }
        
       
        
        
    }




    /**
     * @dev Returns the owner of the token specified by tokenId. Wrapper function for ERC721 function ownerOf(). 
    */
    function getOwner(uint256 tokenID) external view returns(address){
        return ownerOf(tokenID);
    }


    /**
     * @dev Sets isERC1155 array 
    */
    function setIsERC1155(uint256 tokenID) public {
        isERC1155[tokenID] = true;
    }

    // /**
    //  * @dev gets true if tokenID is ERC721
    // */
    // function getIsERC721(uint256 tokenID) external view returns(bool) {
    //     return isERC721[tokenID];
    // }

    // /**
    //  * @dev Sets isERC721 array 
    // */
    // function setIsERC721(uint256 tokenID) public {
    //     isERC721[tokenID] = true;
    // }

    /**
     * @dev gets true if tokenID is ERC1155
    */
    function getIsERC1155(uint256 tokenID) external view returns(bool) {
        return isERC1155[tokenID];
    }
    

    /**
     * @dev Returns the contract address of the child token ID, given a parent and child token ID.
     */
    function getChildContract(uint256 tokenID, uint256 childTokenID) external view returns(address){

        for(uint256 i = 0; i < _childContract[tokenID].length(); i++) {
            if (_childsForChildContract[tokenID][_childContract[tokenID].at(i)].contains(childTokenID)){
                return _childContract[tokenID].at(i);
            }
        }

        return address(0);
    }

    /**
     * @dev Wrapper function to get message sender.
     */
    function getMsgSender() external view returns(address){
        return _msgSender();
    }



    /**
     * @dev Transfers batch of child tokens from a token ID.
     */
    function safeBatchTransferChildFrom(uint256 fromTokenId, address to, address childContract, uint256[] memory childTokenIds, uint256[] memory amounts, bytes memory data) public override {
        require(childTokenIds.length == amounts.length, "ERC998: ids and amounts length mismatch");
        require(to != address(0), "ERC998: transfer to the zero address");

        address operator = _msgSender();
        require(
            ownerOf(fromTokenId) == operator ||
            isApprovedForAll(ownerOf(fromTokenId), operator),
            "ERC998: caller is not owner nor approved"
        );

        _beforeChildTransfer(operator, fromTokenId, to, childContract, childTokenIds, amounts, data);

        for (uint256 i = 0; i < childTokenIds.length; ++i) {
            uint256 childTokenId = childTokenIds[i];
            uint256 amount = amounts[i];

            _removeChild(fromTokenId, childContract, childTokenId, amount);
        }
        ERC1155(childContract).safeBatchTransferFrom(address(this), to, childTokenIds, amounts, data);
        emit TransferBatchChild(fromTokenId, to, childContract, childTokenIds, amounts);
    }

    /**
     * @dev Receives a child token, the receiver token ID must be encoded in the
     * field data.
     */
    function onERC1155Received(address operator, address from, uint256 id, uint256 amount, bytes memory data) virtual public override returns(bytes4) {
        require(data.length == 32, "ERC998: data must contain the unique uint256 tokenId to transfer the child token to");
        _beforeChildTransfer(operator, 0, address(this), from, _asSingletonArray(id), _asSingletonArray(amount), data);

        uint256 _receiverTokenId;
        uint256 _index = msg.data.length - 32;
        assembly {_receiverTokenId := calldataload(_index)}

        _receiveChild(_receiverTokenId, msg.sender, id, amount);
        emit ReceivedChild(from, _receiverTokenId, msg.sender, id, amount);

        return this.onERC1155Received.selector;
    }

    /**
     * @dev Receives a child 998 token, the receiver token ID must be encoded in the
     * field data.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data) virtual public override returns(bytes4) {
        require(data.length == 32, "ERC998: data must contain the unique uint256 tokenId to transfer the child token to");

        uint256 _receiverTokenId;
        uint256 _index = msg.data.length - 32;
        assembly {_receiverTokenId := calldataload(_index)}

        _receiveChild(_receiverTokenId, msg.sender, tokenId, 1);
        emit ReceivedChild(from, _receiverTokenId, msg.sender, tokenId, 1);

        return this.onERC721Received.selector;
    }

    /**
     * @dev Receives a batch of child tokens, the receiver token ID must be
     * encoded in the field data.
     */
    function onERC1155BatchReceived(address operator, address from, uint256[] memory ids, uint256[] memory values, bytes memory data) virtual public override returns(bytes4) {
        require(data.length == 32, "ERC998: data must contain the unique uint256 tokenId to transfer the child token to");
        require(ids.length == values.length, "ERC1155: ids and values length mismatch");
        _beforeChildTransfer(operator, 0, address(this), from, ids, values, data);

        uint256 _receiverTokenId;
        uint256 _index = msg.data.length - 32;
        assembly {_receiverTokenId := calldataload(_index)}
        for(uint256 i = 0; i < ids.length; i++) {
            _receiveChild(_receiverTokenId, msg.sender, ids[i], values[i]);
            emit ReceivedChild(from, _receiverTokenId, msg.sender, ids[i], values[i]);
        }
        return this.onERC1155BatchReceived.selector;
    }

    function _receiveChild(uint256 tokenId, address childContract, uint256 childTokenId, uint256 amount) internal virtual {
        if(!_childContract[tokenId].contains(childContract)) {
            _childContract[tokenId].add(childContract);
        }
        if(_balances[tokenId][childContract][childTokenId] == 0) {
            _childsForChildContract[tokenId][childContract].add(childTokenId);
        }
        _balances[tokenId][childContract][childTokenId] += amount;
    }

    function _removeChild(uint256 tokenId, address childContract, uint256 childTokenId, uint256 amount) internal virtual {
        require(_balances[tokenId][childContract][childTokenId] >= amount, "ERC998: insufficient child balance for transfer");
        _balances[tokenId][childContract][childTokenId] -= amount;
        if(_balances[tokenId][childContract][childTokenId] == 0) {
            _holdersOf[childContract][childTokenId].remove(tokenId);
            _childsForChildContract[tokenId][childContract].remove(childTokenId);
            if(_childsForChildContract[tokenId][childContract].length() == 0) {
                _childContract[tokenId].remove(childContract);
            }
        }
    }

    function _beforeChildTransfer(
        address operator,
        uint256 fromTokenId,
        address to,
        address childContract,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal virtual
    { }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}
