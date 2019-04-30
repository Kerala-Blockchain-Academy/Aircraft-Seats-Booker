var FlightSeatsBooker = artifacts.require("./FlightSeatsBooker.sol")

module.exports= function(deployer){
    deployer.deploy(FlightSeatsBooker);
}
