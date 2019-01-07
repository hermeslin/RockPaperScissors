pragma solidity 0.4.24;

contract RockPaperScissors {
    address owner;

    enum Elements { DEFAULT, ROCK, PAPER, SISSIORS }

    struct Game {
        uint blockNumber;
        uint timeoutBlockNumber;
        uint bets;
        address playerA;
        Elements playerAElement;
        address playerB;
        Elements playerBElement;
        bool isExist;
        bool isOver;
        bool isReward;
        address winner;
    }

    mapping (
        bytes32 => Game
    ) public gameRooms;

    mapping (
        address => uint
    ) public balances;

    // log event
    event LogCreateGameRoom (
        bytes32 indexed gameHash,
        uint blockNumber,
        uint timeoutBlockNumber,
        address playerA,
        uint bets
    );

    event LogJoinGameRoom (
        bytes32 indexed gameHash,
        address playerB,
        uint playerBElement,
        uint bets
    );

    event LogRevealGame (
        bytes32 indexed gameHash,
        uint bets,
        uint playerAElement,
        uint playerBElement,
        address winner,
        bool isOver
    );

    event LogRewardGame (
        bytes32 indexed gameHash,
        uint bets,
        address winner,
        uint playerABalance,
        uint playerBBalance,
        bool isReward
    );

    event LogWithdraw (
        address indexed player,
        uint balance
    );

    // modifier
    modifier checkElement(uint8 element) {
        require(element >= uint8(Elements.ROCK), "element should great than 1");
        require(element <= uint8(Elements.SISSIORS), "element should less than 3");
        _;
    }

    modifier gameRoomNotExists(bytes32 gameHash) {
        require(!gameRooms[gameHash].isExist, "game room exist");
        _;
    }

    modifier gameRoomExists(bytes32 gameHash) {
        require(gameRooms[gameHash].isExist, "game room not exist");
        _;
    }

    modifier playerBCanJoinGameRoom(bytes32 gameHash) {
        require(gameRooms[gameHash].isExist, "game room not exist");
        require(gameRooms[gameHash].playerAElement == Elements.DEFAULT, "game started, join another room");
        require(gameRooms[gameHash].playerB == address(0), "game started, join another room");
        require(gameRooms[gameHash].playerBElement == Elements.DEFAULT, "game started, join another room");
        require(gameRooms[gameHash].timeoutBlockNumber > block.number, "game expired, join another room");
        require(gameRooms[gameHash].bets == msg.value, "should set the same bet");
        _;
    }

    modifier palyerACanRevealGame(bytes32 gameHash, uint8 element, bytes32 randomString) {
        require(gameHash == createGameHash(element, randomString), "game hash not correct");
        require(!gameRooms[gameHash].isOver, "game over, reveal another game");
        require(gameRooms[gameHash].playerA == msg.sender, "not the game room creator");
        require(element > uint8(Elements.DEFAULT), "playerA should set game element");
        require(gameRooms[gameHash].playerB != address(0), "playerB Not Joined");
        require(uint8(gameRooms[gameHash].playerBElement) > uint8(Elements.DEFAULT), "playerB should set game element");
        _;
    }

    modifier playerBCanForceRevealGame(bytes32 gameHash) {
        require(gameRooms[gameHash].timeoutBlockNumber <= block.number, "game not expired, can not reveal this game");
        require(uint8(gameRooms[gameHash].playerAElement) == uint8(Elements.DEFAULT), "playerA set game element before");
        require(!gameRooms[gameHash].isOver, "game over, reveal another game");
        require(gameRooms[gameHash].playerB == msg.sender, "playerB Not Joined");
        require(uint8(gameRooms[gameHash].playerBElement) > uint8(Elements.DEFAULT), "playerB should set game element");
        _;
    }

    modifier playersCanReward(bytes32 gameHash) {
        require(gameRooms[gameHash].timeoutBlockNumber <= block.number, "game not expired, can not get reward from this game");
        require(gameRooms[gameHash].isOver, "game not over, get reward from another game");
        require(!gameRooms[gameHash].isReward, "game rewarded before, choose another game");
        _;
    }

    modifier playersCanWithdraw() {
        require(balances[msg.sender] > 0, "player has no balance to withdraw");
        _;
    }

    constructor () public {
        owner = msg.sender;
    }

    function createGameHash (uint8 element, bytes32 randomString) public view
        checkElement(element)
        returns (
            bytes32 gameHash
        ) {
        return keccak256(abi.encodePacked(msg.sender, element, randomString, address(this)));
    }

    function createGameRoom(bytes32 gameHash, uint timeout) public payable
        gameRoomNotExists(gameHash)
        returns (
            bool success
        ) {

        gameRooms[gameHash] = Game({
            blockNumber: block.number,
            timeoutBlockNumber: (block.number + timeout),
            bets: msg.value,
            playerA: msg.sender,
            playerAElement: Elements.DEFAULT,
            playerB: address(0),
            playerBElement: Elements.DEFAULT,
            isExist: true,
            isOver: false,
            isReward: false,
            winner: address(0)
        });

        emit LogCreateGameRoom({
            gameHash: gameHash,
            blockNumber: gameRooms[gameHash].blockNumber,
            timeoutBlockNumber: gameRooms[gameHash].timeoutBlockNumber,
            playerA: gameRooms[gameHash].playerA,
            bets: gameRooms[gameHash].bets
        });
        return true;
    }

    function joinGameRoom(bytes32 gameHash, uint8 element) public payable
        checkElement(element)
        playerBCanJoinGameRoom(gameHash)
        returns (
            bool success
        ) {

        Game storage g = gameRooms[gameHash];

        g.playerB = msg.sender;
        g.playerBElement = Elements(element);
        g.bets += msg.value;

        emit LogJoinGameRoom({
            gameHash: gameHash,
            playerB: g.playerB,
            playerBElement: uint8(g.playerBElement),
            bets: g.bets
        });
        return true;
    }

    function revealGame(bytes32 gameHash, uint8 element, bytes32 randomString) public
        checkElement(element)
        gameRoomExists(gameHash)
        palyerACanRevealGame(gameHash, element, randomString)
        returns (
            bool success
        ) {

        Game storage g = gameRooms[gameHash];

        g.winner = getWinner(msg.sender, element, g.playerB, uint8(g.playerBElement));
        g.playerAElement = Elements(element);
        g.isOver = true;

        emit LogRevealGame({
            gameHash: gameHash,
            bets: g.bets,
            playerAElement: uint8(g.playerAElement),
            playerBElement: uint8(g.playerBElement),
            winner: g.winner,
            isOver: g.isOver
        });
        return true;
    }

    function revealGameForce(bytes32 gameHash) public
        gameRoomExists(gameHash)
        playerBCanForceRevealGame(gameHash)
        returns (bool success)
        {
        // playerB joined this game, but playerA not reveal the game in the time
        Game storage g = gameRooms[gameHash];

        g.winner = msg.sender;
        g.isOver = true;

        emit LogRevealGame({
            gameHash: gameHash,
            bets: g.bets,
            playerAElement: uint8(g.playerAElement),
            playerBElement: uint8(g.playerBElement),
            winner: g.winner,
            isOver: g.isOver
        });
        return true;
    }

    function rewardGame(bytes32 gameHash) public
        gameRoomExists(gameHash)
        playersCanReward(gameHash)
        returns (
            bool success
        ) {

        Game storage g = gameRooms[gameHash];

        // in a draw
        if (g.winner == address(0)) {
            balances[g.playerA] += (g.bets / 2);
            balances[g.playerB] += (g.bets / 2);
        }
        else {
            balances[g.winner] += g.bets;
        }
        g.isReward = true;

        emit LogRewardGame({
            gameHash: gameHash,
            bets: g.bets,
            winner: g.winner,
            playerABalance: balances[g.playerA],
            playerBBalance: balances[g.playerB],
            isReward: g.isReward
        });
        return true;
    }

    function withdraw() public
        playersCanWithdraw()
        returns (
            bool success
        ) {

        uint balance = balances[msg.sender];
        balances[msg.sender] = 0;
        msg.sender.transfer(balance);

        emit LogWithdraw({
            player: msg.sender,
            balance: balance
        });
        return true;
    }

    function getGameRoomState(bytes32 gameHash) public view
        returns (
            uint timeoutBlockNumber,
            uint bets,
            address playerA,
            uint playerAElement,
            address playerB,
            uint playerBElement,
            bool isExist,
            bool isOver,
            bool isReward,
            address winner
        ) {

        Game memory p = gameRooms[gameHash];
        return (
            p.timeoutBlockNumber,
            p.bets,
            p.playerA,
            uint8(p.playerAElement),
            p.playerB,
            uint8(p.playerBElement),
            p.isExist,
            p.isOver,
            p.isReward,
            p.winner
        );
    }

    function getWinner(address playerA, uint8 playerAElement, address playerB, uint8 playerBElement) private pure
        returns (
            address winner
        ) {

        uint8 result;
        result = (3 + playerAElement - playerBElement) % 3;

        if (result == 1) {
            return playerA;
        }
        else if (result == 2) {
            return playerB;
        }

        // in a draw
        return address(0);
    }

    function say(string word) public pure returns(string wordString ) {
        return word;
    }
}