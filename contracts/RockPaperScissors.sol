pragma solidity 0.4.24;

contract RockPaperScissors {
    enum Elements { DEFAULT, ROCK, PAPER, SISSIORS }
    enum GameState { DEFAULT, CREATE, PLAYER_JOIN, REVEAL, REWARD }

    struct Game {
        uint blockNumber;
        uint timeoutBlockNumber;
        uint bets;
        address playerA;
        Elements playerAElement;
        address playerB;
        Elements playerBElement;
        GameState gameState;
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
        uint bets,
        GameState gameState
    );

    event LogJoinGameRoom (
        bytes32 indexed gameHash,
        address playerB,
        Elements playerBElement,
        uint bets,
        GameState gameState
    );

    event LogRevealGame (
        bytes32 indexed gameHash,
        uint bets,
        Elements playerAElement,
        Elements playerBElement,
        address winner,
        GameState gameState
    );

    event LogRewardGame (
        bytes32 indexed gameHash,
        uint bets,
        address winner,
        uint playerABalance,
        uint playerBBalance,
        GameState gameState
    );

    event LogWithdraw (
        address indexed player,
        uint balance
    );

    // modifier
    modifier checkElement(uint8 element) {
        require(Elements(element) != Elements.DEFAULT, "element not exists");
        _;
    }

    modifier gameRoomNotExists(bytes32 gameHash) {
        require(gameRooms[gameHash].gameState == GameState.DEFAULT, "game room exist");
        _;
    }

    modifier gameRoomExists(bytes32 gameHash) {
        require(GameState(gameRooms[gameHash].gameState) != GameState.DEFAULT, "game room not exist");
        _;
    }

    modifier playerBCanJoinGameRoom(bytes32 gameHash) {
        require(GameState(gameRooms[gameHash].gameState) == GameState.CREATE, "game not in CREATE state");
        require(gameRooms[gameHash].timeoutBlockNumber > block.number, "game expired, join another room");
        require(gameRooms[gameHash].bets == msg.value, "should set the same bet");
        _;
    }

    modifier palyerACanRevealGame(bytes32 gameHash, uint8 element, bytes32 randomString) {
        require(GameState(gameRooms[gameHash].gameState) == GameState.PLAYER_JOIN, "game not in PLAYER_JOIN state");
        require(gameRooms[gameHash].playerA == msg.sender, "not the game room creator");
        _;
    }

    modifier playerBCanForceRevealGame(bytes32 gameHash) {
        require(gameRooms[gameHash].timeoutBlockNumber <= block.number, "game not expired, can not reveal this game");
        require(GameState(gameRooms[gameHash].gameState) == GameState.PLAYER_JOIN, "game not in PLAYER_JOIN state");
        require(gameRooms[gameHash].playerB == msg.sender, "playerB Not Joined");
        _;
    }

    modifier playersCanReward(bytes32 gameHash) {
        require(gameRooms[gameHash].timeoutBlockNumber <= block.number, "game not expired, can not get reward from this game");
        require(GameState(gameRooms[gameHash].gameState) == GameState.REVEAL, "game not in REVEAL state");
        _;
    }

    modifier playersCanWithdraw() {
        require(balances[msg.sender] > 0, "player has no balance to withdraw");
        _;
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
            gameState: GameState.CREATE,
            winner: address(0)
        });

        emit LogCreateGameRoom({
            gameHash: gameHash,
            blockNumber: gameRooms[gameHash].blockNumber,
            timeoutBlockNumber: gameRooms[gameHash].timeoutBlockNumber,
            playerA: gameRooms[gameHash].playerA,
            bets: gameRooms[gameHash].bets,
            gameState: gameRooms[gameHash].gameState
        });
        return true;
    }

    function joinGameRoom(bytes32 gameHash, uint8 element) public payable
        checkElement(element)
        gameRoomExists(gameHash)
        playerBCanJoinGameRoom(gameHash)
        returns (
            bool success
        ) {

        Game storage g = gameRooms[gameHash];

        g.gameState = GameState.PLAYER_JOIN;
        g.playerB = msg.sender;
        g.playerBElement = Elements(element);
        g.bets += msg.value;

        emit LogJoinGameRoom({
            gameHash: gameHash,
            playerB: g.playerB,
            playerBElement: g.playerBElement,
            bets: g.bets,
            gameState: g.gameState
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

        g.gameState = GameState.REVEAL;
        g.winner = getWinner(msg.sender, element, g.playerB, uint8(g.playerBElement));
        g.playerAElement = Elements(element);

        emit LogRevealGame({
            gameHash: gameHash,
            bets: g.bets,
            playerAElement: g.playerAElement,
            playerBElement: Elements(g.playerBElement),
            winner: g.winner,
            gameState: g.gameState
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
        g.gameState = GameState.REVEAL;

        emit LogRevealGame({
            gameHash: gameHash,
            bets: g.bets,
            playerAElement: g.playerAElement,
            playerBElement: g.playerBElement,
            winner: g.winner,
            gameState: g.gameState
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
        g.gameState = GameState.REWARD;

        emit LogRewardGame({
            gameHash: gameHash,
            bets: g.bets,
            winner: g.winner,
            playerABalance: balances[g.playerA],
            playerBBalance: balances[g.playerB],
            gameState: g.gameState
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
            Elements playerAElement,
            address playerB,
            Elements playerBElement,
            GameState gameState,
            address winner
        ) {

        Game memory p = gameRooms[gameHash];
        return (
            p.timeoutBlockNumber,
            p.bets,
            p.playerA,
            p.playerAElement,
            p.playerB,
            p.playerBElement,
            p.gameState,
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
}