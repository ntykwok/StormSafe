// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
import '@chainlink/contracts/src/v0.8/ConfirmedOwner.sol';
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DynamicNFT is ERC721, ChainlinkClient, Ownable {
    using Chainlink for Chainlink.Request;
    using Counters for Counters.Counter;

    uint256 public temperature;
    bytes32 private jobId;
    uint256 private fee;
    Counters.Counter private _tokenIdCounter;
    bool public paused = false;

    uint256[4] private nft_prices = [1, 3, 5];
    uint256[4] private nft_claims = [2, 6, 10];

    mapping(uint256 => Attr) public attributes;

    struct Attr{
        string city;
        uint256 bday;
        uint256 expiry;
        uint256 price;
        uint256 claim;
        uint256 city_temp;
        bool valid;
    }

    uint interval;
    uint lastTimeStamp;
    uint counter;

    uint public city_counter;
    uint[5] public city_temps;
    string[5] public cities;

    mapping(address => uint) eth_equity;
    
    event RequestTemperature(bytes32 indexed requestId, uint256 temperature);

    constructor() ERC721("Dynamic NFT", "DNFT") {
        setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10;
        temperature= 0 ;
        interval = 60;
        lastTimeStamp = block.timestamp; 
        counter = 0;
        city_counter = 0;
        cities = ["hongkong", "shanghai", "tokyo", "berlin", "london"];
    }

    function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory){
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(bytes calldata) external {
        lastTimeStamp = block.timestamp;
        update_nfts();
        requestTempData();
    }

    function buildMetadata(uint256 _tokenId) private view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name": "', attributes[_tokenId].city, '",',
                                '"attributes": [{"trait_type": "Creation Date", "value": ', Strings.toString(attributes[_tokenId].bday), '},',
                                '{"trait_type": "Expiry Date", "value": ', Strings.toString(attributes[_tokenId].expiry), '},',
                                '{"trait_type": "Initial Price", "value": ', Strings.toString(attributes[_tokenId].price), '},',
                                '{"trait_type": "Claim Amount", "value": ', Strings.toString(attributes[_tokenId].claim), '},',
                                '{"trait_type": "Temperature", "value": ', Strings.toString(attributes[_tokenId].city_temp), '}',
                                ']}'
                            )
                        )
                    )
                )
            );
        }

    function update_nfts() public {
        city_temps[city_counter] = temperature;
        for (uint i = 0; i < _tokenIdCounter.current(); i++) {
            string memory a = attributes[i].city;
            string memory b = cities[city_counter];
            if (keccak256(abi. encodePacked(a)) == keccak256(abi. encodePacked(b))) {
                attributes[i].city_temp = city_temps[city_counter];
            }
        }

        city_counter += 1;
        city_counter = city_counter % 5;
    }

    function requestTempData() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        string memory s1 = "http://api.weatherapi.com/v1/current.json?q=";
        string memory s2 = cities[city_counter];
        string memory s3 = "&Key=30e737e440484fd18a5134039221006";
        string memory api1 = string(abi.encodePacked(s1,s2));
        string memory api2 = string(abi.encodePacked(api1, s3));
        req.add('get', api2);
        req.add('path', 'current,temp_c');
        int256 timesAmount = 10 ** 18;
        req.addInt('times', timesAmount);

        return sendChainlinkRequest(req, fee);
    }

    function fulfill(bytes32 _requestId, uint256 _temperature) public recordChainlinkFulfillment(_requestId) {
        emit RequestTemperature(_requestId, _temperature);
        temperature = _temperature / (10 ** 18);
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), 'Unable to transfer');
    }

    function mint4me(string memory _city, uint8 _tier) external payable {
        require(!paused);

        bool goodstring = false;
        uint256 city_id = 0;

        for (uint i = 0; i < 5; i++) {
            string memory _check = cities[i];
            if (keccak256(abi. encodePacked(_city)) == keccak256(abi. encodePacked(_check))) {
                goodstring = true;
                city_id = i;
            }
        }
        require(goodstring, "Insurance contract does not cover this city.");
        require(eth_equity[msg.sender] >= getPrice(_tier), "Insufficient balance.");

        eth_equity[msg.sender] -= getPrice(_tier);
        
        // initialize minting of NFT and assignment of variables 
        _safeMint(msg.sender, _tokenIdCounter.current());
        uint256 time = block.timestamp;
        uint256 bday = time;
        uint256 expiry = time + 86400;
        uint256 price = getPrice(_tier);
        uint256 claim = getClaim(_tier);
        uint256 temp = city_temps[city_id];
        bool validity = true;

        // assign and alter metadata of NFT
        attributes[_tokenIdCounter.current()] = Attr(_city, bday, expiry, price, claim, temp, validity);
        buildMetadata(_tokenIdCounter.current());

        // increment token counter to prevent minting of same tokenId
        _tokenIdCounter.increment();
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721) returns (string memory) {
        require(_exists(tokenId), "ERC721 Metadata: URI query for nonexistent token");
        return buildMetadata(tokenId);
    }

    function getPrice(uint8 _type) view private returns (uint256) {
        return nft_prices[_type];
    }

    function getClaim(uint8 _type) view private returns (uint256) {
        return nft_claims[_type];
    }

    // give address fake money
    function giveEquity() public {
        eth_equity[msg.sender] += 10;
    }

    function verifyContractDuration(uint _tokenId) view private returns (bool) {
        return block.timestamp - attributes[_tokenId].bday < 1000;
    }

    function verifyThreshold(uint _tokenId) view private returns (bool) {
        uint256 temp_now = attributes[_tokenId].city_temp;
        uint256 threshold_temp = 5;
        return temp_now > threshold_temp;
    }

    function giveClaim(uint _tokenId) public {
        require(verifyContractDuration(_tokenId), "Contract expired.");
        require(verifyThreshold(_tokenId), "Cannot claim now.");
        require(attributes[_tokenId].valid, "Invalid contract.");
        eth_equity[msg.sender] += attributes[_tokenId].claim;
        attributes[_tokenId].valid = false;
    }

    function show_equity() view public returns (uint256) {
        return eth_equity[msg.sender];
    }


}

// https://www.atatus.com/tools/base64-to-json
// https://faucets.chain.link/
