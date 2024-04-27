pragma solidity >=0.5.0 <0.6.0;

contract eetp {
  address payable agent; // energy agent owns smart contract
  address payable network; // distribution network

  uint penality; // penality for cancelling

  struct offer {
    address payable buyer;
    uint starting;
    uint duration;
    bool confirmed;
  }

  // hash of energy offer (processed by energy agent) mapped to offer
  mapping (bytes32 => offer) public offers;

  event bought(bytes32 trans, address payable buyer);
  event confirmed(bytes32 trans, address payable buyer);

  constructor(address payable _network) public payable {
    agent = msg.sender
    network = _network

    penality = 100;
  }

  modifier valid(uint _starting) {
    require(_starting > now);
    _;
  }

  function buy(bytes32 _trans, uint _starting, uint _duration) public valid(_starting) payable {
    offer memory anOffer;

    // offer must be available (ie hasn't been bought yet)
    if (offers[_trans].buyer == address(0x0)) {
      anOffer.buyer = msg.sender;
      anOffer.starting = _starting;
      anOffer.duration = _duration;

      offers[_trans] = anOffer;
      emit bought(_trans, msg.sender);
    }
  }

  function cancel(bytes32 _trans) public payable {
    if (offers[_trans].buyer == msg.sender) {
      // buyer can cancel is starting time for energy transfer hasn't yet started
      // must pay penality
      if (offers[_trans].starting > now) {
        offers[_trans].buyer = address(0x0);
        // person must pay penality
      }
    }
  }

  modifier identity() {
    require(msg.sender == network);
    _;
  }

  // network confrims energy transfer is possible, if not offer is invalid
  function confirm(bytes32 _trans) public identity payable {
    if (offers[_trans].starting > now) {
      offers[_trans].confirmed = true;
      emit confirmed(_trans, offers[_trans].buyer);
    }
  }

  // buyer pays once offer has been confirmed
  function pay(bytes32 _trans) public payable {
    if (offers[_trans].buyer == msg.sender && offers[_trans].confirmed == true) {
      // payment
    }
  }

}