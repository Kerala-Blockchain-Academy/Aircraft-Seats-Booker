# Design Decisions

The main design decision is to use the ERC721 token standard for Non-Fungible Tokens NFT to model flight seats and boarding passes, which are distributed to passengers upon successful completion of booking and checkin web-flows. ERC721 NFTs enable us to token assets with distinctive characteristics. This token standard is perfectly suited to value-assets like flight seats and boarding passes where each seat has a unique seat number and each boarding pass should be associated with a unique passenger. The benefit of allowing the passenger to hold an ERC721 seat after booking is that it allows the passenger to sell, trade, swap, or give away their seat before checkin, if they wish to.

To implement ERC721 NFTs, the contract FlightSeatsBooker.sol inherits from the OpenZeppelin contract ERC721Token.sol, which is OpenZeppelin's implementation of the ERC721 standard.


### Modifier Requirements
``require()`` conditions make validity assertions at the beginning of each public function. For example, when a passenger tries to checkin:

```javascript
require(exists(_seatId), "Seat must exist in order to check in");
require(_flight.departureDateTime > now, "Too late to check in, flight has departed");
require(seats[_seatId].occupiedStatus == SeatOccupiedStatus.Occupied, "Seat must be occupied");
require(seats[_seatId].checkedIn == false, "Seat is already checked in");
```

### Restricted Access
Access is restricted to the contract's state with data structures set to be internal or private. 

Access modifiers are used on public functions to ensure that only the appropriate actor is allowed to call this public function which modifies the contract's state. Access modifiers employed are as follows:
```javascript
/**
 * Ensure the given message sender is the passenger who owns the seat or the airline of the flight
 */
 modifier checkOwner(uint256 _seatId) {
    require(getAirlineAddressForSeat(_seatId) == msg.sender || ownerOf(_seatId) == msg.sender, "Must be airline or buyer who owns the seat");
    _;
 }


/**
 * Ensure the given message sender is the airline of the flight
 */
modifier checkAirline(bytes8 _flightNumber, uint _departureDateTime){
    require(getAirlineAddressForFlight(_flightNumber, _departureDateTime) == msg.sender, "Must be airline of the flight");
    _;
}
```

### Self-destruct
Self-destruct is used to allow the contract owner to terminate the contract with remaining funds sent to contract owner.

### Pull Withdrawals
Fund-approval system is used for airline fees and passenger refunds to reduce vulnerabilities.

### Enums
Enums are used to track state-transitions, and these are considered in fail-early ``require()`` conditions when relevant, such as ``seat.occupiedStatus``. 

### Events
Events are emitted for important actions, seat bookings, checkins, refunds etc.

# Libraries:

The contract uses the OpenZepellin library ECRecovery to validate digital signatures, for example in processAirlineRefunds:
```javascript		
using ECRecovery for bytes32;
.....
.....
bytes32 airlineSigned = keccak256(abi.encodePacked(msg.sender, _amountToRefund, _nonce)).toEthSignedMessageHash();
require(airlineSigned.recover(_airlineSig) == msg.sender, "Invalid airline signature, nice try");
```

Additional OpenZepellin contracts are imported for inheritance to facilitate ``ERC721Token``.

# Intregration with IPFS.

During the checkin flow the passenger uploads their passport-scan to IPFS and submits the IPFS hash to the ``checkinBuyer()`` function to construct their ERC721 Boarding Pass NFT which includes this IPFS hash.


# Unimplemented functions

Some functions in the smart contract have not been translated to the front-end UI, as they have been created for future development and learbibg purposes only. These functions are:

1. Cancel A Booking - ``cancelSeatBooking()``
2. Process Refunds - ``processAirlineRefunds()``

Some functions, though easily implementable, have been hard-coded into the contract constructor so as to focus on the Passenger-side functionality of the dApp. The functions are:

1. Create a Flight - ``createFlight()``
2. Add a Seating Section to the Flight - ``addSeatsToClass()``