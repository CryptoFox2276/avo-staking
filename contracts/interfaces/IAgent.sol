// SPDX-License-Identifier: MIT 
pragma solidity 0.8.17;

interface IAgent {
    function getLevelOfAgent(address agent) external returns(uint256);
    function slashTokenOfAgent(address agent, uint256 slashAmount) external;
    function prizeTokenOfAgent(address agent, uint256 slashAmount) external;
}