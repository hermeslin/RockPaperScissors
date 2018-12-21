pragma solidity 0.4.24;

contract RockPaperScissors {

    enum elements { DEFAULT, ROCK, PAPER, SISSIORS }

    struct game {
        uint blockNumber;
        uint timeoutBlockNumber;
        uint bets;
        address playerA;
        elements playerAElement;
        address playerB;
        elements playerBElement;
        bool isExist;
        bool isOver;
        address winner;
    }

    mapping (
        bytes32 => game
    ) public gameRooms;

    modifier checkElement(uint element) {
        require(element >= uint(elements.ROCK), "element should great than 1");
        require(element <= uint(elements.SISSIORS), "element should less than 3");
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

    modifier gameRoomNotStart(bytes32 gameHash) {
        require(gameRooms[gameHash].playerAElement == elements.DEFAULT, "game started, join another room");
        require(gameRooms[gameHash].playerB == address(0), "game started, join another room");
        require(gameRooms[gameHash].playerBElement == elements.DEFAULT, "game started, join another room");
        _;
    }

    modifier gameRoomNotExpired(bytes32 gameHash) {
        require(gameRooms[gameHash].timeoutBlockNumber > block.number, "game expired, join another room");
        _;
    }

    modifier gameRoomIsCreator(bytes32 gameHash) {
        require(gameRooms[gameHash].playerA == msg.sender, "not the game room creator");
        _;
    }

    modifier gameRoomNotOver(bytes32 gameHash, uint playerAElement) {
        require(playerAElement > uint(elements.DEFAULT), "playerA should set game element");
        require(gameRooms[gameHash].playerB != address(0), "playerB Not Joined");
        require(uint(gameRooms[gameHash].playerBElement) > uint(elements.DEFAULT), "playerB should set game element");
        require(!gameRooms[gameHash].isOver, "game over, join another room");
        _;
    }

    // log event
    event LogCreateGameRoom (
        bytes32 gameHash,
        uint blockNumber,
        uint timeoutBlockNumber,
        address playerA,
        uint bets
    );

    event LogJoinGameRoom (
        bytes32 gameHash,
        address playerB,
        uint playerBElement,
        uint bets
    );

    event LogStartGame (
        bytes32 gameHash,
        uint bets,
        uint playerAElement,
        uint playerBElement,
        address winner,
        bool isOver
    );

    function createGameHash (uint8 element, bytes32 randomString) public view checkElement(element) returns (bytes32 gameHash) {
        return keccak256(abi.encodePacked(msg.sender, element, randomString, address(this)));
    }

    function createGameRoom(bytes32 gameHash, uint timeout) public payable
        gameRoomNotExists(gameHash)
        returns (
            bool success
        ) {
        gameRooms[gameHash] = game({
            blockNumber: block.number,
            timeoutBlockNumber: (block.number + timeout),
            bets: msg.value,
            playerA: msg.sender,
            playerAElement: elements.DEFAULT,
            playerB: address(0),
            playerBElement: elements.DEFAULT,
            isExist: true,
            isOver: false,
            winner: address(0)
        });

        game memory p = gameRooms[gameHash];
        emit LogCreateGameRoom({
            gameHash: gameHash,
            blockNumber: p.blockNumber,
            timeoutBlockNumber: p.timeoutBlockNumber,
            playerA: p.playerA,
            bets: p.bets
        });
        return true;
    }

    function joinGameRoom(bytes32 gameHash, uint element) public payable
        checkElement(element)
        gameRoomExists(gameHash)
        gameRoomNotStart(gameHash)
        gameRoomNotExpired(gameHash)
        returns (
            bool success
        ) {

        gameRooms[gameHash].playerB = msg.sender;
        gameRooms[gameHash].playerBElement = elements(element);
        gameRooms[gameHash].bets += msg.value;

        game memory p = gameRooms[gameHash];
        emit LogJoinGameRoom({
            gameHash: gameHash,
            playerB: p.playerB,
            playerBElement: uint(p.playerBElement),
            bets: p.bets
        });
        return true;
    }

    function getGameRoomStatus(bytes32 gameHash) public view gameRoomExists(gameHash)
        returns (
            uint timeoutBlockNumber,
            uint bets,
            address playerA,
            uint playerAElement,
            address playerB,
            uint playerBElement,
            bool isExist,
            bool isOver,
            address winner
        ) {
        game memory p = gameRooms[gameHash];
        return (
            p.timeoutBlockNumber,
            p.bets,
            p.playerA,
            uint(p.playerAElement),
            p.playerB,
            uint(p.playerBElement),
            p.isExist,
            p.isOver,
            p.winner
        );
    }

    function startGame(bytes32 gameHash, uint element) public payable
        gameRoomExists(gameHash)
        gameRoomNotExpired(gameHash)
        gameRoomIsCreator(gameHash)
        gameRoomNotOver(gameHash, element)
        returns (bool success)
        {
        // ROCKER:1 ,PAPER: 2, SISSORS: 3
        uint result;
        result = (3 + uint(element) - uint(gameRooms[gameHash].playerBElement)) % 3;
        if (result == 1) {
            gameRooms[gameHash].winner = msg.sender;
        }
        else if (result == 2) {
            gameRooms[gameHash].winner = gameRooms[gameHash].playerB;
        }
        gameRooms[gameHash].playerAElement = elements(element);
        gameRooms[gameHash].isOver = true;

        game memory p = gameRooms[gameHash];
        emit LogStartGame({
            gameHash: gameHash,
            bets: p.bets,
            playerAElement: uint(p.playerAElement),
            playerBElement: uint(p.playerBElement),
            winner: p.winner,
            isOver: p.isOver
        });
        return true ;
    }

    function say(string word) public pure returns(string wordString ) {
        return word;
    }
}