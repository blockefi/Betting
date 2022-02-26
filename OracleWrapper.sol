// SPDX-License-Identifier: UNLICENCED


pragma solidity ^0.8.0;

import "./upgradeability/CustomOwnable.sol";
import "./interfaces/Oracleinterface.sol";
import "./interfaces/TellorInterface.sol";
import "./interfaces/UniswapInterface.sol";
import "./interfaces/TokenDecimalsInterface.sol";


contract OracleWrapper is CustomOwnable {
    
    bool isInitialized;
    address public UniswapV2Router02;

    struct coinDetails {
        address oracleAddress;
        uint96   oracleType;
    }

    mapping(address => coinDetails) public coin;

   
   function initializeOracle(address _owner, address _UniswapV2Router02) public {
        require(!isInitialized,"OracleWrapperV0 : Already initialized");
        UniswapV2Router02 = _UniswapV2Router02;
        _setOwner(_owner);
        isInitialized = true;
    }
    
    function setOracleAddresses (address _coinAddress, address _oracleAddress, uint96 _oracleType) public onlyOwner {
        require((_oracleType == 1) || (_oracleType == 2), "OracleWrapperV0: Invalid oracleType");
        require(_coinAddress != address(0), "OracleWrapperV0 : Zero address");
        require(_oracleAddress != address(0), "OracleWrapperV0: Zero address");
        
        coin[_coinAddress].oracleAddress = _oracleAddress;
        coin[_coinAddress].oracleType = _oracleType;
    }
  
    function getPrice(address _coinAddress, address pair) external view returns (uint256) {
        require((coin[_coinAddress].oracleType != uint8(0)), "OracleWrapperV0 : Coin not exists");
        
        uint256 price;

        if (coin[_coinAddress].oracleType  == 1) {
            OracleInterface oObj = OracleInterface(coin[_coinAddress].oracleAddress);
            return price = uint256(oObj.latestAnswer());
        } else if (coin[_coinAddress].oracleType == 2 && pair != address(0)) {
            uniswapInterface uObj = uniswapInterface(UniswapV2Router02);
            
            address[] memory path = new address[](2);
            path[0] = _coinAddress;
            path[1] = pair;
            uint[] memory values = uObj.getAmountsOut(10**(Token(_coinAddress).decimals()), path);

            return price = (values[1] / (10 ** 10));
        }
        
        require(price != 0, "OracleWrapperV0: Price can't be zero");
        
        return 0;
        
    }
    
    function updateUniswapV2Router02(address _UniswapV2Router02) external onlyOwner {
        require(_UniswapV2Router02 != address(0), "OracleWrapperV0: Invalid address");
        UniswapV2Router02 = _UniswapV2Router02;
    }
    
    //check if this works
    function removeCoin(address _coinAddress) public onlyOwner {
        require(coin[_coinAddress].oracleType != 0, "OracleWrapperV0: Coin not exists");
        
        delete coin[_coinAddress];
    }

}