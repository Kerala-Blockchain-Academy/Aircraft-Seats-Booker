const FlightSeatsBooker = artifacts.require("FlightSeatsBooker.sol");
const Web3Utils = require("web3-utils");

contract("FlightSeatsBooker", ([contractOwner, passenger, airline, hacker]) => {

  const departureDate = Math.floor(Date.now() / 1000) + 8640000;
  const seatOccupiedStatus = {'Vacant':0, 'Occupied':1};

  /**
   * tests that the contract constructor initialises a single flight
   */
  it("One test flight created at initiation by the constructor", async () => {

    const seatsDistributor = await FlightSeatsBooker.deployed();

    const expectedAirlineAddresses = await seatsDistributor.getActiveAirlines();
    assert.equal(expectedAirlineAddresses[0], contractOwner);  // expectedAirlineAddresses[0] will be the contractOwner who prepopulates a flight in the contract constructor

    const flightIds = await seatsDistributor.getFlightIdsForAirline(contractOwner)
    assert.equal(flightIds.length === 1, true);

  });

  /**
   * test that an airline can create a flight
   */
  it("Airlines can create flights", async () => {

    const seatsDistributor = await FlightSeatsBooker.deployed();
    const flightNumber = Web3Utils.hexToBytes(Web3Utils.toHex('EK531'));
    const flightId = await seatsDistributor.getFlightId(flightNumber, departureDate);
    const origin = 'DXB';
    const destination = 'COK';
    const airlineCode = 'EK';
    const airlineName = "Emirates Airlines";

    const pseudoRandomNumber = Math.floor(Date.now() / 1000);
    const hash = Web3Utils.soliditySha3(
        { type: 'bytes32', value: flightId },
        { type: 'address', value: airline },
        { type: 'uint256', value: pseudoRandomNumber },
    );
    const signature = web3.eth.sign(airline, hash);

    await seatsDistributor.createFlight(
        flightNumber,
        Web3Utils.hexToBytes(Web3Utils.toHex(origin)),
        Web3Utils.hexToBytes(Web3Utils.toHex(destination)),
        departureDate,
        Web3Utils.hexToBytes(Web3Utils.toHex(airlineCode)),
        airlineName,
        3,
        airline,
        signature,
        pseudoRandomNumber,
        {
          from: airline
        }
    );

    const expectedAirlineAddresses = await seatsDistributor.getActiveAirlines();
    assert.equal(expectedAirlineAddresses[1], airline);

    const flightIdsForAirline = await seatsDistributor.getFlightIdsForAirline(airline);
    assert.equal(flightIdsForAirline.length, 1);
  });

  /**
   * negative test case for create flight, an airline should not be able to create a flight when the departure date is in the past
   */
  it("should not create a flight when departure date is in the past", async () => {

    const seatsDistributor = await FlightSeatsBooker.deployed();
    const flightNumber = 'EK531';
    const departureDateInPast = Math.floor(Date.now() / 1000) - 86400;
    const flightId = await seatsDistributor.getFlightId(flightNumber, departureDateInPast);
    const origin = 'DXB';
    const destination = 'COK';
    const airlineCode = 'EK';
    const airlineName = "Emirates Airlines";

    const pseudoRandomNumber = Math.floor(Date.now() / 1000);
    const hash = Web3Utils.soliditySha3(
        { type: 'bytes32', value: flightId },
        { type: 'address', value: airline },
        { type: 'uint256', value: pseudoRandomNumber },
    );
    const signature = web3.eth.sign(airline, hash);

    let complete = false;

    try {
      await seatsDistributor.createFlight(
          Web3Utils.hexToBytes(Web3Utils.toHex(flightNumber)),
          Web3Utils.hexToBytes(Web3Utils.toHex(origin)),
          Web3Utils.hexToBytes(Web3Utils.toHex(destination)),
          departureDateInPast,
          Web3Utils.hexToBytes(Web3Utils.toHex(airlineCode)),
          airlineName,
          6,
          airline,
          signature,
          pseudoRandomNumber,
          {
            from: airline
          }
      );
      complete = true;
    }
    catch (err) {
    }

    assert.equal(complete, false);
  });

  /**
   * tests that an airline can add seat inventory to their flight
   */
  it("airline can add seat inventory to their flight cabins", async () => {

    const seatsDistributor = await FlightSeatsBooker.deployed();
    const flightNumber = 'EK531';
    const seatNumbers = ['0x31410000', '0x31420000', '0x31430000']; //bytes4 hex values for 1A, 1B, 1C, 1D
    const seatPrices = [1000000000000000000, 2000000000000000000, 3000000000000000000];
    const cabinClass = {'Economy':0, 'Business':1, 'First':2};

    await seatsDistributor.addSeatsToClass(
        Web3Utils.hexToBytes(Web3Utils.toHex(flightNumber)),
        departureDate,
        seatNumbers,
        seatPrices,
        cabinClass.Economy,
        {
          from: airline
        }
    );

    const flightIdsForAirline = await seatsDistributor.getFlightIdsForAirline(airline);
    const flightId = flightIdsForAirline[0];
    const seatIdsForFlight = await seatsDistributor.getSeatsForFlight(flightId);
    let seatId;
    for (let i = 0; i < seatIdsForFlight.length; i++) {
      seatId = seatIdsForFlight[i];
      const seat = await seatsDistributor.getSeat(seatId);
      assert.equal(seatNumbers.includes(seat[1]), true);
      assert.equal(seatPrices.includes(seat[2].toNumber()), true);
      assert.equal(seat[3], seatOccupiedStatus.Vacant);
      assert.equal(seat[4], cabinClass.Economy);
      assert.equal(seat[5], false);
    }
  });


  /**
   *  tests that an airline cannot exceed the total number of seats allowed for a given flight
   */
  it("airline cannot add more seat inventory than the total number of seats for this flight", async () => {

    // the maximum allowed 3 seats for this flight were added in the preceding unit test, adding more here should cause failure.
    const seatsDistributor = await FlightSeatsBooker.deployed();
    const flightNumber = 'EK531';
    const seatNumbers = ['0x31440000', '0x31450000', '0x31460000']; //bytes4 hex values for 1A, 1B, 1C.
    const seatPrices = [1000000000000000000, 2000000000000000000, 3000000000000000000];
    const cabinClass = {'Economy':0, 'Business':1, 'First':2};

    let complete = false;

    try {
      await seatsDistributor.addSeatsToClass(
          Web3Utils.hexToBytes(Web3Utils.toHex(flightNumber)),
          departureDate,
          seatNumbers,
          seatPrices,
          cabinClass.Economy,
          {
            from: airline
          }
      );
      complete = true;
    }
    catch (err) {
    }

    assert.equal(complete, false);

  });

  /**
   * tests that only the airline who owns the flight can add seat inventory
   */
  it("ensures only the airline who owns the flight can add seat inventory to this flight", async () => {

    const seatsDistributor = await FlightSeatsBooker.deployed();
    const flightNumber = 'EK531';
    const seatNumbers = ['0x31410000', '0x31420000', '0x31430000']; //bytes4 hex values for 1A, 1B, 1C.
    const seatPrices = [1000000000000000000, 2000000000000000000, 3000000000000000000];
    const cabinClass = {'Economy':0, 'Business':1, 'First':2};

    let complete = false;

    try {
    await seatsDistributor.addSeatsToClass(
        Web3Utils.hexToBytes(Web3Utils.toHex(flightNumber)),
        departureDate,
        seatNumbers,
        seatPrices,
        cabinClass.Economy,
        {
          from: hacker
        }
    );
      complete = true;
    }
    catch (err) {
    }

    assert.equal(complete, false);
  });

  /**
   * tests that a passenger can book a seat and that they then own the newly minted ERC721 seat token
   * also tests that the airline can withdraw the seat fees which were deposited from the passenger
   */
  it("passenger can book a seat on a flight and receive a unique ER721 Seat token", async () => {

    const seatsDistributor = await FlightSeatsBooker.deployed();
    const flightIdsForAirline = await seatsDistributor.getFlightIdsForAirline(airline);
    const flightId = flightIdsForAirline[0];
    const seatIdsForFlight = await seatsDistributor.getSeatsForFlight(flightId);
    const seatId = seatIdsForFlight[0];

    const seatPriceEth = 1;
    const seatPriceWei = Web3Utils.toWei(seatPriceEth.toString(), "ether");

    await seatsDistributor.bookSeat(
        seatId,
        {
          from: passenger,
          value: seatPriceWei
        }
    );

    const erc721TokenOwner = await seatsDistributor.ownerOf(seatId);
    assert.equal(passenger, erc721TokenOwner);

    const erc721TokenApproved = await seatsDistributor.getApproved(seatId);
    assert.equal(airline, erc721TokenApproved);

    const seat = await seatsDistributor.getSeat(seatId);
    assert.equal(seat[3], seatOccupiedStatus.Occupied);

    // Now airline calls withdrawFlightFees to pull the flight fee from the contract.

    const airlineOriginalWeiBalance = await web3.eth.getBalance(airline);
    const receipt = await seatsDistributor.withdrawFlightFees(
        airline,
        {
          from: airline
        }
    );

    const tx = await web3.eth.getTransaction(receipt.tx);
    const gasCost = tx.gasPrice.mul(receipt.receipt.gasUsed);

    const airlineFinalWeiBalance = await web3.eth.getBalance(airline);
    const expectedEth = parseFloat(Web3Utils.fromWei(airlineOriginalWeiBalance.toString(), "ether")) + seatPriceEth -  parseFloat(Web3Utils.fromWei(gasCost.toString(), "ether"));
    const expectedWeiBalance = Web3Utils.toWei(expectedEth.toString(), "ether");

    assert.equal(airlineFinalWeiBalance.toNumber(), expectedWeiBalance);


  });

  /**
   * tests that correct amount is sent for the seat fee
   */
  it("ensures amount sent by passenger covers the cost of seat", async () => {

    const seatsDistributor = await FlightSeatsBooker.deployed();
    const flightIdsForAirline = await seatsDistributor.getFlightIdsForAirline(airline);
    const flightId = flightIdsForAirline[0];
    const seatIdsForFlight = await seatsDistributor.getSeatsForFlight(flightId);
    const seatId = seatIdsForFlight[2]; //costs 3 ETH

    let complete = false;

    try {
      await seatsDistributor.bookSeat(
          seatId,
          {
            from: passenger,
            value: Web3Utils.toWei("1")
          }
      );
      complete = true;
    }
    catch (err) {
    }

    assert.equal(complete, false);
  });

  /**
   *  tests that the passenger can checkin for their flight, which burns their ERC721 seat token and sends back a new ERC721 Boarding Pass token
   *  tests that the passenger is no longer the owner of the ERC721 seat after checkin
   *  tests that the passenger is the owner of the newly minted ERC721 Boarding Pass
   */
  it("passenger can checkin for their flight, which burns their ERC721 seat token and sends back a new ERC721 Boarding Pass token. ", async () => {

    const seatsDistributor = await FlightSeatsBooker.deployed();
    const flightIdsForAirline = await seatsDistributor.getFlightIdsForAirline(airline);
    const flightId = flightIdsForAirline[0];
    const seatIdsForFlight = await seatsDistributor.getSeatsForFlight(flightId);
    const seatId = seatIdsForFlight[0];

    const barcodeStringParams = await seatsDistributor.getBarcodeStringParametersForBoardingPass(seatId);
    const barcodeStringForBoardingPass = web3.toUtf8(barcodeStringParams[0]) +
        web3.toUtf8(barcodeStringParams[1]).trim() +
        web3.toUtf8(barcodeStringParams[2]).trim() +
        barcodeStringParams[3] +
        web3.toUtf8(barcodeStringParams[4]).trim();

    const ipfsUrlForPassportScan = Web3Utils.hexToBytes(Web3Utils.toHex('https://ipfs.io/ipfs/Qmaj7LUwb7T5sMFyznMGS1cAGPyVJL6Vhjwemq4zb1Nbex'));

    await seatsDistributor.checkinBuyer(
        seatId,
        barcodeStringForBoardingPass,
        ipfsUrlForPassportScan,
        {
          from: passenger,
          value: 0
        }
    );

    const erc721SeatExists = await seatsDistributor.exists(seatId);
    assert.equal(erc721SeatExists, false);

    const boardingPass = await seatsDistributor.getBoardingPassForSeat(seatId);
    const boardPassId = boardingPass[0];
    const erc721TokenOwner = await seatsDistributor.ownerOf(boardPassId);
    assert.equal(passenger, erc721TokenOwner);

    const seat = await seatsDistributor.getSeat(seatId);
    assert.equal(seat[5], true); //checked in flag on seat

  });

  /**
   * tests that only the passenger who owns the ERC721 Seat can checkin this seat for their flight
   * books a new seat for a passenger and then invokes checkin function called by a hacker for this same seat
   */
  it("ensures only the passenger who owns the ERC721 Seat can checkin this seat for their flight ", async () => {

    const seatsDistributor = await FlightSeatsBooker.deployed();
    const flightIdsForAirline = await seatsDistributor.getFlightIdsForAirline(airline);
    const flightId = flightIdsForAirline[0];
    const seatIdsForFlight = await seatsDistributor.getSeatsForFlight(flightId);
    const seatId = seatIdsForFlight[1];

    const seatPriceEth = 2;
    const seatPriceWei = Web3Utils.toWei(seatPriceEth.toString(), "ether");

    await seatsDistributor.bookSeat(
        seatId,
        {
          from: passenger,
          value: seatPriceWei
        }
    );

    const erc721TokenOwner = await seatsDistributor.ownerOf(seatId);
    assert.equal(passenger, erc721TokenOwner);

    const barcodeStringParams = await seatsDistributor.getBarcodeStringParametersForBoardingPass(seatId);
    const barcodeStringForBoardingPass = web3.toUtf8(barcodeStringParams[0]) +
        web3.toUtf8(barcodeStringParams[1]).trim() +
        web3.toUtf8(barcodeStringParams[2]).trim() +
        barcodeStringParams[3] +
        web3.toUtf8(barcodeStringParams[4]).trim();

    const ipfsUrlForPassportScan = Web3Utils.hexToBytes(Web3Utils.toHex('https://ipfs.io/ipfs/Qmaj7LUwb7T5sMFyznMGS1cAGPyVJL6Vhjwemq4zb1Nbex'));

    let complete = false;

    try {
      await seatsDistributor.checkinBuyer(
          seatId,
          barcodeStringForBoardingPass,
          ipfsUrlForPassportScan,
          {
            from: hacker,
            value: 0
          }
      );
      complete = true;
    }
    catch (err) {
    }

    assert.equal(complete, false);
  });




});
