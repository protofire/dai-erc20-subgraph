pragma solidity ^0.4.13;

contract DSMath {
  function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x + y) >= x);
  }
  function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x - y) <= x);
  }
  function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(y == 0 || (z = x * y) / y == x);
  }

  function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
    return x <= y ? x : y;
  }
  function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
    return x >= y ? x : y;
  }
  function imin(int256 x, int256 y) internal pure returns (int256 z) {
    return x <= y ? x : y;
  }
  function imax(int256 x, int256 y) internal pure returns (int256 z) {
    return x >= y ? x : y;
  }

  uint256 constant WAD = 10 ** 18;
  uint256 constant RAY = 10 ** 27;

  function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = add(mul(x, y), WAD / 2) / WAD;
  }
  function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = add(mul(x, y), RAY / 2) / RAY;
  }
  function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = add(mul(x, WAD), y / 2) / y;
  }
  function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = add(mul(x, RAY), y / 2) / y;
  }

  // This famous algorithm is called "exponentiation by squaring"
  // and calculates x^n with x as fixed-point and n as regular unsigned.
  //
  // It's O(log n), instead of O(n) for naive repeated multiplication.
  //
  // These facts are why it works:
  //
  //  If n is even, then x^n = (x^2)^(n/2).
  //  If n is odd,  then x^n = x * x^(n-1),
  //   and applying the equation for even x gives
  //    x^n = x * (x^2)^((n-1) / 2).
  //
  //  Also, EVM division is flooring and
  //    floor[(n-1) / 2] = floor[n / 2].
  //
  function rpow(uint256 x, uint256 n) internal pure returns (uint256 z) {
    z = n % 2 != 0 ? x : RAY;

    for (n /= 2; n != 0; n /= 2) {
      x = rmul(x, x);

      if (n % 2 != 0) {
        z = rmul(z, x);
      }
    }
  }
}

contract DSAuthority {
  function canCall(address src, address dst, bytes4 sig)
    public
    view
    returns (bool);
}

contract DSAuthEvents {
  event LogSetAuthority(address indexed authority);
  event LogSetOwner(address indexed owner);
}

contract DSAuth is DSAuthEvents {
  DSAuthority public authority;
  address public owner;

  function DSAuth() public {
    owner = msg.sender;
    LogSetOwner(msg.sender);
  }

  function setOwner(address owner_) public auth {
    owner = owner_;
    LogSetOwner(owner);
  }

  function setAuthority(DSAuthority authority_) public auth {
    authority = authority_;
    LogSetAuthority(authority);
  }

  modifier auth {
    require(isAuthorized(msg.sender, msg.sig));
    _;
  }

  function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
    if (src == address(this)) {
      return true;
    } else if (src == owner) {
      return true;
    } else if (authority == DSAuthority(0)) {
      return false;
    } else {
      return authority.canCall(src, this, sig);
    }
  }
}

contract DSNote {
  event LogNote(
    bytes4 indexed sig,
    address indexed guy,
    bytes32 indexed foo,
    bytes32 indexed bar,
    uint256 wad,
    bytes fax
  );

  modifier note {
    bytes32 foo;
    bytes32 bar;

    assembly {
      foo := calldataload(4)
      bar := calldataload(36)
    }

    LogNote(msg.sig, msg.sender, foo, bar, msg.value, msg.data);

    _;
  }
}

contract DSStop is DSNote, DSAuth {
  bool public stopped;

  modifier stoppable {
    require(!stopped);
    _;
  }
  function stop() public auth note {
    stopped = true;
  }
  function start() public auth note {
    stopped = false;
  }

}

contract ERC20Events {
  event Approval(address indexed src, address indexed guy, uint256 wad);
  event Transfer(address indexed src, address indexed dst, uint256 wad);
}

contract ERC20 is ERC20Events {
  function totalSupply() public view returns (uint256);
  function balanceOf(address guy) public view returns (uint256);
  function allowance(address src, address guy) public view returns (uint256);

  function approve(address guy, uint256 wad) public returns (bool);
  function transfer(address dst, uint256 wad) public returns (bool);
  function transferFrom(address src, address dst, uint256 wad)
    public
    returns (bool);
}

contract DSTokenBase is ERC20, DSMath {
  uint256 _supply;
  mapping(address => uint256) _balances;
  mapping(address => mapping(address => uint256)) _approvals;

  function DSTokenBase(uint256 supply) public {
    _balances[msg.sender] = supply;
    _supply = supply;
  }

  function totalSupply() public view returns (uint256) {
    return _supply;
  }
  function balanceOf(address src) public view returns (uint256) {
    return _balances[src];
  }
  function allowance(address src, address guy) public view returns (uint256) {
    return _approvals[src][guy];
  }

  function transfer(address dst, uint256 wad) public returns (bool) {
    return transferFrom(msg.sender, dst, wad);
  }

  function transferFrom(address src, address dst, uint256 wad)
    public
    returns (bool)
  {
    if (src != msg.sender) {
      _approvals[src][msg.sender] = sub(_approvals[src][msg.sender], wad);
    }

    _balances[src] = sub(_balances[src], wad);
    _balances[dst] = add(_balances[dst], wad);

    Transfer(src, dst, wad);

    return true;
  }

  function approve(address guy, uint256 wad) public returns (bool) {
    _approvals[msg.sender][guy] = wad;

    Approval(msg.sender, guy, wad);

    return true;
  }
}

contract DSToken is DSTokenBase(0), DSStop {
  bytes32 public symbol;
  uint256 public decimals = 18; // standard token precision. override to customize

  function DSToken(bytes32 symbol_) public {
    symbol = symbol_;
  }

  event Mint(address indexed guy, uint256 wad);
  event Burn(address indexed guy, uint256 wad);

  function approve(address guy) public stoppable returns (bool) {
    return super.approve(guy, uint256(-1));
  }

  function approve(address guy, uint256 wad) public stoppable returns (bool) {
    return super.approve(guy, wad);
  }

  function transferFrom(address src, address dst, uint256 wad)
    public
    stoppable
    returns (bool)
  {
    if (src != msg.sender && _approvals[src][msg.sender] != uint256(-1)) {
      _approvals[src][msg.sender] = sub(_approvals[src][msg.sender], wad);
    }

    _balances[src] = sub(_balances[src], wad);
    _balances[dst] = add(_balances[dst], wad);

    Transfer(src, dst, wad);

    return true;
  }

  function push(address dst, uint256 wad) public {
    transferFrom(msg.sender, dst, wad);
  }
  function pull(address src, uint256 wad) public {
    transferFrom(src, msg.sender, wad);
  }
  function move(address src, address dst, uint256 wad) public {
    transferFrom(src, dst, wad);
  }

  function mint(uint256 wad) public {
    mint(msg.sender, wad);
  }
  function burn(uint256 wad) public {
    burn(msg.sender, wad);
  }
  function mint(address guy, uint256 wad) public auth stoppable {
    _balances[guy] = add(_balances[guy], wad);
    _supply = add(_supply, wad);
    Mint(guy, wad);
  }
  function burn(address guy, uint256 wad) public auth stoppable {
    if (guy != msg.sender && _approvals[guy][msg.sender] != uint256(-1)) {
      _approvals[guy][msg.sender] = sub(_approvals[guy][msg.sender], wad);
    }

    _balances[guy] = sub(_balances[guy], wad);
    _supply = sub(_supply, wad);
    Burn(guy, wad);
  }

  // Optional token name
  bytes32 public name = "";

  function setName(bytes32 name_) public auth {
    name = name_;
  }
}
