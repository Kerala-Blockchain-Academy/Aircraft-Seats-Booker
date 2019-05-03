# Flight Seats Booker

The aim of my project is to revamp the flight booking, check-in and boarding pass processes, distributing flight-seats and boarding passes to passengers as ERC721 Non-Fungible Tokens.

## Software Packages Used ##

1. `NodeJS`             -   v9.0.0 (install latest)
   
2. `NPM`                -   v5.5.1 (install latest)
   
3. `Truffle`            -   v4.1.13 (install exact version)
   
4. `Solidity (solc-js)` -   v0.4.24 (install exact version)
   
5. `IPFS`               -   v0.4.18 (install latest)
```
sudo ./install.sh
ipfs init
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["PUT", "GET", "POST", "OPTIONS"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
```

6. `Ganache-CLI`        -   v6.2.5 (install latest)

## Airline Use-Cases

1. Create Flight. Provide details such as flight number, origin, destination, departure time, Airline details, and number of seats.

2. Create and Add Seats to Seating Class. Airlines supply seat numbers and corresponding seat prices for each cabin in the flight.

3. Withdraw Fees. Airlines can withdraw their fees from passengers' seat bookings, similar to a payment-approval system.

4. Cancel Seat. Airline can cancel a passenger's seat booking which repossesses their ERC721 seat and triggers a refund to be queued for the passenger.

Hardcoded for demonstration.

## Passenger Use-Cases

1. Book Seat. Passengers can book available flight seats and receive ERC721 seats for their booking.

2. Check-In. Passengers can check-in for flights which returns their ERC721 seat to the airline. The passenger supplies a IPFS hash for their passport-scan image in this check-in operation.

3. Cancel Seat Bookings. Passengers can also cancel their seat booking, which returns their ERC721 Seat to the airline and triggers a refund to be queued for the passenger.


## Demo Installation and Setup

A local running IPFS instance is required, along with node version 9, npm, ganache-cli, truffle v4.1.13, solc v0.4.24, and metamask.

Steps to execute:

Open 3 terminals in the project folder and then -

1. Terminal 1  (leave it running)
        
```
ganache-cli
```
2. Terminal 2  (leave it running)
```
ipfs daemon
```
3. Terminal 3 
```
npm install
npm run build
truffle migrate --network development --reset --compile-all
npm run dev
```

The final command ``npm run dev`` will start a locally running lite-server instance which will serve the flight booking, checkin and boarding pass UI flows to interact with the contract deployed on local ganache network. 

### Steps to demo

First log into metamask using the same seed phrase from your local running ganache-cli instance. Then switch to another one of the ganache accounts in metamask instead of the default account. The default account is used by the contract owner to create a single flight and airline belonging to this account, and thus you cannot proceed through the flight booking using that same default account.

  - First screen shows a list of flights to be selected. Select book flight for any one.
  - Select a seat (confirm transaction in metamask for cost of seat)
  - View Seat booking with ERC721 Token ID
  - Immediately proceed to checkin. Select Check In For Flight
  - Choose an image file on your local machine to submit to IPFS as your passport-scan. Choose file and then select Upload Passport to IPFS
  - Select Complete Checkin.
  - View your boarding pass, complete with 2D QRCode, ERC721 Boarding Pass ID and link to passport-scan image in IPFS.
