pragma solidity ^0.4.24;

import {ERC721Token} from "openzeppelin-solidity/contracts/token/ERC721/ERC721Token.sol";
import "openzeppelin-solidity/contracts/ECRecovery.sol";

contract FlightSeatsBooker is ERC721Token("Flight Seat Booker", "FLIGHT-SEAT") {

    using ECRecovery for bytes32;

    enum CabinClass {Economy, Business, First}
    enum SeatOccupiedStatus {Vacant, Occupied}


    modifier checkOwner(uint256 _seatId) {
        require(getAirlineAddressForSeat(_seatId) == msg.sender || ownerOf(_seatId) == msg.sender, "Must be airline or buyer who owns the seat");
        _;
    }


    modifier checkAirline(bytes8 _flightNumber, uint _departureDateTime){
        require(getAirlineAddressForFlight(_flightNumber, _departureDateTime) == msg.sender, "Must be airline of the flight");
        _;
    }

    struct Airline {
        bytes2 code;
        string name;
        address airlineAddress;
    }

    struct Flight {
        bytes32 flightId;
        bytes8 flightNumber;
        bytes3 origin;
        bytes3 destination;
        Airline airline;
        uint departureDateTime;
        uint totalNumberSeats;
        uint256[] seatIds;
    }

    struct Seat {
        bytes4 seatNumber;
        uint price;
        SeatOccupiedStatus occupiedStatus;
        CabinClass cabin;
        bytes32 flightId;
        bool checkedIn;
        bool isSeat;
    }

    struct BoardingPass {
        uint256 id;
        uint256 seatId;
        bytes32 barcodeString;
        bytes passportScanIpfsHash;
    }

    struct BookingRefund {
        address recipient;
        uint amount;
        bool paid;
    }


    address[] public activeAirlines; // airlines currently using the system

    mapping(address => bytes32[]) internal flightIds; // airlines to their belonging flightIds

    mapping(bytes32 => Flight) internal flights; // flightIds to flights.

    mapping(uint256 => Seat) internal seats; // seatIds to seats.

    mapping(uint256 => BoardingPass) internal seatBoardingPasses; // seatIds to boarding passes.

    mapping(address => BookingRefund[]) private airlineRefundsToBeProcessed; // airlines to their BookingRefunds to be processed in the future

    mapping(address => uint256) private airlineFlightFeeDeposits; // airlines to their seat booking fees which they can withdraw



    // gets the airlines currently using the system
    function getActiveAirlines() public view returns (address[]) {
        return activeAirlines;
    }

    // gets the flightId for a given flightNumber and _departureDateTime
    function getFlightId(bytes8 _flightNumber, uint _departureDateTime) public pure returns (bytes32){
        return keccak256(abi.encodePacked(_flightNumber, "_", _departureDateTime));
    }

    // gets the seatId for a given flightNumber, _departureDateTime and seatNumber
    function getSeatId(bytes8 _flightNumber, uint _departureDateTime, bytes4 _seatNumber) public pure returns (uint256){
        return uint256(keccak256(abi.encodePacked(_flightNumber, "_", _departureDateTime, "_", _seatNumber)));
    }

    // gets all flightId's belonging to given airline
    function getFlightIdsForAirline(address _airlineAddress) public view returns (bytes32[] memory) {
        return flightIds[_airlineAddress];
    }

    // gets a single Flight based on given flightId
    function getFlight(bytes32 _flightId) public view returns (bytes32,bytes8,bytes3,bytes3,string,uint,bytes2){
        return (flights[_flightId].flightId, flights[_flightId].flightNumber, flights[_flightId].origin, flights[_flightId].destination, flights[_flightId].airline.name, flights[_flightId].departureDateTime, flights[_flightId].airline.code);
    }

    // gets a single Seat based on given seatId
    function getSeat(uint256 _seatId) public view returns(uint, bytes4, uint, SeatOccupiedStatus, CabinClass, bool, bool) {
        return (_seatId, seats[_seatId].seatNumber, seats[_seatId].price, seats[_seatId].occupiedStatus, seats[_seatId].cabin, seats[_seatId].checkedIn, seats[_seatId].isSeat);
    }

    // gets all seatId's belonging to given flight
    function getSeatsForFlight(bytes32 _flightId) public view returns (uint256[]){
        return flights[_flightId].seatIds;
    }

    // get the flight which contains a given seatId
    function getFlightOfSeat(uint256 _seatId) private view returns (Flight){
        return flights[seats[_seatId].flightId];
    }

    // get the airline who owns the flight containing the given seatId
    function getAirlineAddressForSeat(uint _seatId) private view returns (address){
        return flights[seats[_seatId].flightId].airline.airlineAddress;
    }

    // get the airline who owns the flight
    function getAirlineAddressForFlight(bytes8 _flightNumber, uint _departureDateTime) private view returns (address){
        return flights[getFlightId(_flightNumber, _departureDateTime)].airline.airlineAddress;
    }

    // get the boarding pass for a given seat id
    function getBoardingPassForSeat(uint _seatId) public view returns (uint256, uint256, bytes32, bytes) {
        return(seatBoardingPasses[_seatId].id, seatBoardingPasses[_seatId].seatId, seatBoardingPasses[_seatId].barcodeString, seatBoardingPasses[_seatId].passportScanIpfsHash);
    }

    event SeatCreatedEvent (
        bytes32 flightId,
        bytes4 seatNumber,
        uint256 seatId
    );

    event SeatBookedEvent (
        address indexed seatOwner,
        uint256 indexed seatId,
        bytes8 flightNumber,
        uint departureDateTime,
        bytes3 origin,
        bytes3 destination,
        bytes4 seatNumber
    );

    event BoardingPassGeneratedEvent (
        uint256 indexed boardingPassId,
        address indexed boardingPassOwner,
        uint256 indexed seatId,
        bytes passportScanIpfsHash,
        bytes8 flightNumber,
        uint departureDateTime,
        bytes3 origin,
        bytes3 destination,
        bytes4 seatNumber
    );

    event FlightFeeDeposited(address indexed airline, uint256 weiAmount);

    event FlightFeesWithdrawn(address indexed airline, uint256 weiAmount);

    event RefundProcessedEvent(address indexed airline, address indexed recipient, uint256 weiAmount);

    address owner;

    constructor() public {
        // Declare Owner as airline default

        owner = msg.sender;

        createFlight(0x4941313235123456,0x445842,0x434f4b,1575390854,0x4941,"Air India",6,owner,abi.encodePacked(""),555);

        bytes4[] memory _seatNumbersPrepopulated = new bytes4[](2);
        uint256[] memory _seatPricesPrepopulated = new uint256[](2);

        _seatNumbersPrepopulated[0] = 0x31410000;
        _seatNumbersPrepopulated[1] = 0x31420000;

        _seatPricesPrepopulated[0] = 10000000000000000000;
        _seatPricesPrepopulated[1] = 9000000000000000000;

        addSeatsToClass(0x4941313235123456, 1575390854, _seatNumbersPrepopulated, _seatPricesPrepopulated, CabinClass.First);

        _seatNumbersPrepopulated[0] = 0x32410000;
        _seatNumbersPrepopulated[1] = 0x32420000;

        _seatPricesPrepopulated[0] = 6000000000000000000;
        _seatPricesPrepopulated[1] = 5000000000000000000;

        addSeatsToClass(0x4941313235123456, 1575390854, _seatNumbersPrepopulated, _seatPricesPrepopulated, CabinClass.Business);

        _seatNumbersPrepopulated[0] = 0x33410000;
        _seatNumbersPrepopulated[1] = 0x33420000;

        _seatPricesPrepopulated[0] = 3000000000000000000;
        _seatPricesPrepopulated[1] = 2000000000000000000;

        addSeatsToClass(0x4941313235123456, 1575390854, _seatNumbersPrepopulated, _seatPricesPrepopulated, CabinClass.Economy);
    }


    function createFlight(
        bytes8 _flightNumber,
        bytes3 _origin,
        bytes3 _destination,
        uint256 _departureDateTime,
        bytes2 _airlineCode,
        string _airlineName,
        uint256 _totalNumberSeats,
        address _airlineAddress,
        bytes _signature,
        uint256 randnum
    )
        
        public
        returns (bytes32)
    {

        bytes32 _flightId = getFlightId(_flightNumber, _departureDateTime);
        bytes32 _expectedSignature = keccak256(abi.encodePacked(_flightId, _airlineAddress, randnum)).toEthSignedMessageHash();

        if (msg.sender != owner) { // contract owner populates a single flight for demo purposes in the constructor, and gets a pass on the _signature.
            require(_expectedSignature.recover(_signature) == _airlineAddress, "Invalid signature");
        }
        require(_departureDateTime > now, "Flight has departed");

        Airline memory _airline = Airline({
            code: _airlineCode,
            name: _airlineName,
            airlineAddress: _airlineAddress
            });

        flights[_flightId] = Flight({
            flightId: _flightId,
            flightNumber: _flightNumber,
            origin: _origin,
            destination: _destination,
            airline: _airline,
            departureDateTime: _departureDateTime,
            totalNumberSeats: _totalNumberSeats,
            seatIds: new uint[](0)
            });

        activeAirlines.push(_airlineAddress);
        flightIds[_airlineAddress].push(_flightId);

        return _flightId;
    }


    function addSeatsToClass(
        bytes8 _flightNumber,
        uint256 _departureDateTime,
        bytes4[] _seatNumbers,
        uint256[] _seatPrices,
        CabinClass _cabin
    )
        checkAirline(_flightNumber, _departureDateTime)
        
        public
    {
        bytes32 _flightId = getFlightId(_flightNumber, _departureDateTime);
        require((_seatNumbers.length + flights[_flightId].seatIds.length) <= flights[_flightId].totalNumberSeats, "you cannot add more seats than the total number of seats for flight");
        require(_seatNumbers.length == _seatPrices.length, "you must supply a corresponding seat price for each seat number");

        for(uint i=0; i<_seatNumbers.length; i++){
            flights[_flightId].seatIds.push(createSeat(_flightNumber, _departureDateTime, _seatNumbers[i], _seatPrices[i], _cabin));
        }
    }


    function  createSeat(
        bytes8 _flightNumber,
        uint _departureDateTime,
        bytes4 _seatNumber,
        uint256 _price,
        CabinClass _cabin
    )
        private returns (uint256)
    {
        uint256 _seatId = getSeatId(_flightNumber, _departureDateTime, _seatNumber);
        Seat memory _seat = Seat({
            seatNumber: _seatNumber,
            price: _price,
            occupiedStatus: SeatOccupiedStatus.Vacant,
            cabin: _cabin,
            flightId: getFlightId(_flightNumber, _departureDateTime),
            checkedIn: false,
            isSeat: true
            });

        seats[_seatId] = _seat;

        emit SeatCreatedEvent(getFlightId(_flightNumber, _departureDateTime), _seatNumber, _seatId);
        return _seatId;
    }

    function bookSeat(uint256 _seatId)
        
        public
        payable
        returns (uint256)
    {
        require(flights[seats[_seatId].flightId].departureDateTime > now, "Seat no longer available, flight has departed");
        require(seats[_seatId].occupiedStatus == SeatOccupiedStatus.Vacant, "Seat must not be already occupied");

        address _airlineAddress = getAirlineAddressForSeat(_seatId);
        require(msg.value == seats[_seatId].price && _airlineAddress.balance + msg.value >= _airlineAddress.balance, "Buyer must pay amount equal to price of seat");

        seats[_seatId].occupiedStatus = SeatOccupiedStatus.Occupied;

        if(exists(_seatId)){ // seat will already exist if was previously booked/minted and subsequently cancelled. In this case the seat should have been returned to the airline.
            require(ownerOf(_seatId) == _airlineAddress, "Error, cannot book seat, seat already exists but does not belong to airline");
            safeTransferFrom(_airlineAddress, msg.sender, _seatId);
        }
        else{
            _mint(msg.sender, _seatId);
            _setTokenURI(_seatId, uint256ToString(_seatId));
        }

        approve(_airlineAddress, _seatId);
        depositFlightFeeToAirline(_airlineAddress, msg.value);

        emit SeatBookedEvent(msg.sender, _seatId, getFlightOfSeat(_seatId).flightNumber, getFlightOfSeat(_seatId).departureDateTime, getFlightOfSeat(_seatId).origin, getFlightOfSeat(_seatId).destination, seats[_seatId].seatNumber);

        return _seatId;
    }


    function depositFlightFeeToAirline(address _airline, uint256 _amount) internal {
        airlineFlightFeeDeposits[_airline] = airlineFlightFeeDeposits[_airline] + _amount;

        emit FlightFeeDeposited(_airline, _amount);
    }


    function withdrawFlightFees(address _airline) public {
        require(msg.sender == _airline, "Only the airline can withdraw their own fees");

        uint256 payment = airlineFlightFeeDeposits[_airline];
        assert(address(this).balance >= payment);

        airlineFlightFeeDeposits[_airline] = 0;
        _airline.transfer(payment);

        emit FlightFeesWithdrawn(_airline, payment);
    }


    function checkinBuyer(uint256 _seatId, bytes32 _barcodeString, bytes memory _passportScanIpfsHash)
        
        public
        returns (uint256)
    {
        require(exists(_seatId), "Seat must exist in order to check in");
        require(ownerOf(_seatId) == msg.sender, "Must be buyer who owns the seat");

        Flight memory _flight = getFlightOfSeat(_seatId);

        require(seats[_seatId].checkedIn == false, "Seat is already checked in");
        require(_flight.departureDateTime > now, "Too late to check in, flight has departed");
        require(seats[_seatId].occupiedStatus == SeatOccupiedStatus.Occupied, "Seat must be occupied");

        seats[_seatId].checkedIn = true;

        uint256 _boardingPassId = uint256(keccak256(abi.encodePacked(_barcodeString, "_", _passportScanIpfsHash)));

        _burn(msg.sender, _seatId);
        _mint(msg.sender, _boardingPassId);
        _setTokenURI(_boardingPassId, bytes32ToString(_barcodeString));
        approve(_flight.airline.airlineAddress, _boardingPassId);

        BoardingPass memory _boardingPass = BoardingPass({
            id: _boardingPassId,
            seatId: _seatId,
            barcodeString: _barcodeString,
            passportScanIpfsHash: _passportScanIpfsHash
        });

        seatBoardingPasses[_seatId] = _boardingPass;
        emitBoardingPassGeneratedEvent(_boardingPass, _flight);

        return _boardingPassId;
    }


    function emitBoardingPassGeneratedEvent(BoardingPass memory _boardingPass, Flight memory _flight) private view {
        emit BoardingPassGeneratedEvent(_boardingPass.id, msg.sender, _boardingPass.seatId, _boardingPass.passportScanIpfsHash, _flight.flightNumber, _flight.departureDateTime, _flight.origin, _flight.destination, seats[_boardingPass.seatId].seatNumber);
    }


    // builds a barcode-string to be encoded in a Boarding Pass QRcode containing the salient flight and seat information for a given seatId
    function getBarcodeStringParametersForBoardingPass(uint256 _seatId) public view returns (bytes8, bytes3, bytes3, uint256, bytes4){
        Flight memory _flight = getFlightOfSeat(_seatId);
        return (_flight.flightNumber, _flight.origin, _flight.destination, _flight.departureDateTime, seats[_seatId].seatNumber);
    }


    function cancelSeatBooking(uint256 _seatId)
    checkOwner(_seatId)
    public
    returns (uint)
    {
        require(exists(_seatId), "Seat must exist in order to cancel seat booking");
        require(seats[_seatId].occupiedStatus == SeatOccupiedStatus.Occupied, "Seat must be occupied");
        require(seats[_seatId].checkedIn == false, "You cannot cancel a booking after checkin is completed");

        seats[_seatId].occupiedStatus = SeatOccupiedStatus.Vacant;

        address _airline = getAirlineAddressForSeat(_seatId);
        address _buyer = ownerOf(_seatId);
        require(_buyer != _airline, "this seat has already been cancelled and returned to the airline");

        BookingRefund memory _refund = BookingRefund({
            recipient: _buyer,
            amount: seats[_seatId].price,
            paid: false
            });

        safeTransferFrom(_buyer, _airline, _seatId);
        airlineRefundsToBeProcessed[_airline].push(_refund);

        return _seatId;
    }


    function processAirlineRefunds(uint256 _amountToRefund, uint256 randnum, bytes _airlineSig)
        
        public
        payable
    {
        require(airlineRefundsToBeProcessed[msg.sender].length > 0, "this airline does not have any refunds to process");
        require(_amountToRefund == msg.value, "amountToRefund does not equal amount sent");

        // Check the signer of the transaction is the correct airline address to prevent replay attacks
        bytes32 airlineSigned = keccak256(abi.encodePacked(msg.sender, _amountToRefund, randnum)).toEthSignedMessageHash();
        require(airlineSigned.recover(_airlineSig) == msg.sender, "Invalid airline signature, nice try");

        BookingRefund[] storage _refunds = airlineRefundsToBeProcessed[msg.sender];

        for(uint i=0; i<_refunds.length && _refunds[i].amount <= _amountToRefund; i++){
            _refunds[i].recipient.transfer(_refunds[i].amount);
            _amountToRefund -= _refunds[i].amount;
            _refunds[i].paid = true;
            emit RefundProcessedEvent(msg.sender, _refunds[i].recipient, _refunds[i].amount);
        }

        // return excess refund funds to the airline.
        if(_amountToRefund > 0){
            depositFlightFeeToAirline(msg.sender, _amountToRefund);
        }

        //  shift left on the _refunds array and delete to remove all paid
        uint deleted = 0;
        while (_refunds[0].paid == true){
            for(uint j=0 ;j<_refunds.length-1; j++) {
                _refunds[j] =  _refunds[j+1];
            }
            delete _refunds[_refunds.length-1];
            deleted++;
        }
        _refunds.length -= deleted;
    }


    // utility to convert bytes32 to string
    function bytes32ToString (bytes32 data) private pure returns (string) {
        bytes memory bytesString = new bytes(32);
        for (uint j=0; j<32; j++) {
            byte char = byte(bytes32(uint(data) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[j] = char;
            }
        }
        return string(bytesString);
    }


    // utility to convert uint256 to string
    function uint256ToString (uint256 data) private pure returns (string) {
        bytes memory bytesString = new bytes(32);
        for (uint256 j=0; j<32; j++) {
            byte char = byte(bytes32(data * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[j] = char;
            }
        }
        return string(bytesString);
    }

    // kill contract and return funds to owner
    function kill() public {
        if (msg.sender == owner) selfdestruct(owner);
    }


}
