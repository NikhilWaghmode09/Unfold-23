//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IERC721 { //interface declaration for transferring NFT from one address to another
    function transferFrom( 
        address _from, //Sender
        address _to, //Receiver
        uint256 _id //token id
    ) external;
}

contract Escrow {
    address public nftAddress; //realestate contract address. used for interacting with the escrow contract.
    address payable public seller; //payable makes the sellers address available to receive ethers.
    address public inspector; // address of the inspector.
    address public lender; //lender address.

    modifier onlyBuyer(uint256 _nftID) {
        require(msg.sender == buyer[_nftID], "Only buyer can call this method");
        _; //placeholder
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this method");
        _; //placeholder
    }

    modifier onlyInspector() {
        require(msg.sender == inspector, "Only inspector can call this method");
        _; //placeholder
    }

    mapping(uint256 => bool) public isListed; //true or false
    mapping(uint256 => uint256) public purchasePrice; //
    mapping(uint256 => uint256) public escrowAmount;//certain amount of funds in escrow to show commitment to the transaction
    mapping(uint256 => address) public buyer; //
    mapping(uint256 => bool) public inspectionPassed; //
    mapping(uint256 => mapping(address => bool)) public approval; //

    constructor(
        address _nftAddress, 
        address payable _seller,
        address _inspector,
        address _lender
    ) {
        nftAddress = _nftAddress; //realestate contract address.
        seller = _seller; //seller initiating the transaction.
        inspector = _inspector; //address of the inspector responsible for updating the inspection status.
        lender = _lender; //address of the lender, who may be involved in the transaction in a financial capacity.
    }

    function list(
        uint256 _nftID,
        address _buyer,
        uint256 _purchasePrice,
        uint256 _escrowAmount
    ) public payable onlySeller { 
        //onlySeller modifier makes sure only the seller can call this 'list' funct.
        // Transfer NFT from seller to this contract
        IERC721(nftAddress).transferFrom(msg.sender, address(this), _nftID);

        isListed[_nftID] = true;
        purchasePrice[_nftID] = _purchasePrice;
        escrowAmount[_nftID] = _escrowAmount;
        buyer[_nftID] = _buyer;
    }

    // Put Under Contract (only buyer - payable escrow)
    // function requires the buyer to send at least the specified escrowAmount when depositing earnest money
    function depositEarnest(uint256 _nftID) public payable onlyBuyer(_nftID) {
        require(msg.value >= escrowAmount[_nftID],"Insufficient escrow amount");
    }

    // Update Inspection Status (only inspector)
    function updateInspectionStatus(uint256 _nftID, bool _passed)
        public
        onlyInspector
    {
        inspectionPassed[_nftID] = _passed;
    }

    // Approve Sale
    function approveSale(uint256 _nftID) public {
        approval[_nftID][msg.sender] = true;
    }

    // Finalize Sale
    // -> Require inspection status (add more items here, like appraisal)
    // -> Require sale to be authorized
    // -> Require funds to be correct amount
    // -> Transfer NFT to buyer
    // -> Transfer Funds to Seller
    function finalizeSale(uint256 _nftID) public {
        require(inspectionPassed[_nftID],"Inspection failed");
        // require(approval[_nftID][buyer[_nftID]],"Buyer not approved");
        require(approval[_nftID][seller],"Seller not approved");
        require(approval[_nftID][lender],"Lender not approved");
        require(address(this).balance >= purchasePrice[_nftID]); 
        //'this' keyword used for referencing current contract.
        //address(this) refers to current contract address.

        isListed[_nftID] = false;
        //transfers the funds from the contract's balance to the seller's address and verifies that the transfer was successful.
        (bool success, ) = payable(seller).call{value: address(this).balance}( //low-level method to send ether to seller's addr.
            ""
        );
        require(success,"ether not sent.");

        IERC721(nftAddress).transferFrom(address(this), buyer[_nftID], _nftID);
    }

    // Cancel Sale (handle earnest deposit)
    // -> if inspection status is not approved, then refund, otherwise send to seller
    function cancelSale(uint256 _nftID) public {
        if (inspectionPassed[_nftID] == false) {
            payable(buyer[_nftID]).transfer(address(this).balance);
        } else {
            payable(seller).transfer(address(this).balance); //transfer is used so that direct transfer ether doesn't interact with ERC-20 AND 721.
        }
    }

    receive() external payable {}

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
