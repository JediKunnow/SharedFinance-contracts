const SharedFinance = artifacts.require("SharedFinance");

module.exports = function (deployer) {
  deployer.deploy( SharedFinance );
};
