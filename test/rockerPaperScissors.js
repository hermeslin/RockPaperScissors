import { default as Promise } from 'bluebird';
import expectedExceptionPromise from '../util/expectedExceptionPromise'

const RockPaperScissors = artifacts.require("RockPaperScissors");

Promise.promisifyAll(web3.eth, { suffix: 'Promise' });

contract('RockPaperScissors', async (accounts) => {

  const [contractOwner, alice, bob, somebody] = accounts;

  const gameElements = {
    default: 0,
    rock: 1,
    paper: 2,
    scissor: 3
  }

  let rockPaperScissors;
  let gameHash;

  beforeEach('Deploy new contract instance', async function () {
    rockPaperScissors = await RockPaperScissors.new({ from: contractOwner });

    let randomString = web3.fromUtf8("this_is_player_defined_secret_string");
    gameHash = await rockPaperScissors.createGameHash(gameElements.rock, randomString, {from: alice});
  });


  describe('createGameRoom function', function () {
    it('should create game room', async function () {
      let timeoutBlock = 10
      let transaction = await rockPaperScissors.createGameRoom(gameHash, timeoutBlock, { from: alice, value: 10 });
      let { event, args } = transaction.logs[0];

      let blockNumber = await web3.eth.getBlockPromise('latest');
      assert.equal(event, 'LogCreateGameRoom');
      assert.equal(args.gameHash, gameHash);
      assert.equal(args.blockNumber, blockNumber.number);
      assert.equal(args.timeoutBlockNumber, blockNumber.number + timeoutBlock);
      assert.equal(args.playerA, alice);
      assert.equal(args.bets.toString(), '10');
    })

    it('should fail when game hash duplicate', async function () {
      let timeoutBlock = 10
      await rockPaperScissors.createGameRoom(gameHash, timeoutBlock, { from: alice, value: 10 });

      await expectedExceptionPromise(() => (
        rockPaperScissors.createGameRoom(gameHash, timeoutBlock, { from: bob, value: 10 })
      ));
    })
  })

  describe('joinGameRoom function', function () {
    beforeEach('create game room', async function () {
      let timeoutBlock = 10
      await rockPaperScissors.createGameRoom(gameHash, timeoutBlock, { from: alice, value: 10 });
    })

    it('should join the game room', async function () {
      let transaction = await rockPaperScissors.joinGameRoom(gameHash, gameElements.rock, { from: bob, value: 10 });

      let { event, args } = transaction.logs[0];
      assert.equal(event, 'LogJoinGameRoom');
      assert.equal(args.gameHash, gameHash);
      assert.equal(args.playerB, bob);
      assert.equal(args.playerBElement, gameElements.rock);
      assert.equal(args.bets.toString(), (20).toString());
    })

    it('should fail when playB set wrong element', async function () {
      let gameElements = 4;
      await expectedExceptionPromise(() => (
        rockPaperScissors.joinGameRoom(gameHash, gameElements, { from: bob, value: 10 })
      ));
    })

    it('should fail when game room not exists', async function () {
      let gameHash = await rockPaperScissors.createGameHash(gameElements.rock, web3.fromUtf8('some_string'), { from: alice });
      await expectedExceptionPromise(() => (
        rockPaperScissors.joinGameRoom(gameHash, gameElements.rock, { from: bob, value: 10 })
      ));
    })

    it('should fail when game room started. (playerB joined)', async function () {
      await rockPaperScissors.joinGameRoom(gameHash, gameElements.rock, { from: bob, value: 10 });

      await expectedExceptionPromise(() => (
        rockPaperScissors.joinGameRoom(gameHash, gameElements.rock, { from: somebody, value: 10 })
      ));
    })

    it('should fail when game room expired', async function () {
      let timeoutBlock = 1;
      let gameHashFirst = await rockPaperScissors.createGameHash(gameElements.rock, web3.fromUtf8('some_string_kr'), { from: alice });
      await rockPaperScissors.createGameRoom(gameHashFirst, timeoutBlock, { from: alice, value: 10 });

      await expectedExceptionPromise(() => (
        rockPaperScissors.joinGameRoom(gameHashFirst, gameElements.rock, { from: bob, value: 10 })
      ));
    })
  })

  describe('revealGame function', function () {
    it('should reveal the game', async function () {
      // alice create game
      let randomString = web3.fromUtf8("this_is_player_defined_secret_string");
      let gameHash = await rockPaperScissors.createGameHash(gameElements.rock, randomString, { from: alice });

      let timeoutBlock = 10
      await rockPaperScissors.createGameRoom(gameHash, timeoutBlock, { from: alice, value: 10 });

      // bob join the game
      await rockPaperScissors.joinGameRoom(gameHash, gameElements.paper, { from: bob, value: 10 });

      // alice reveal the game
      let transaction = await rockPaperScissors.revealGame(gameHash, gameElements.rock, randomString, { from: alice });

      let { event, args } = transaction.logs[0];
      assert.equal(event, 'LogRevealGame');
      assert.equal(args.gameHash, gameHash);
      assert.equal(args.bets.toString(), (20).toString());
      assert.equal(args.playerAElement.toString(), gameElements.rock);
      assert.equal(args.playerBElement.toString(), gameElements.paper);
      assert.equal(args.winner, bob);
      assert.equal(args.isOver, true);
    })
  })

  describe('revealGameForce function', function () {
    // playerB joined this game, but playerA not reveal the game in the time
    it('should force reveal the game', async function () {
      // alice create game
      let randomString = web3.fromUtf8("this_is_player_defined_secret_string");
      let timeoutBlock = 2;

      let gameHash = await rockPaperScissors.createGameHash(gameElements.rock, randomString, { from: alice });
      await rockPaperScissors.createGameRoom(gameHash, timeoutBlock, { from: alice, value: 10 });

      // bob join the game
      await rockPaperScissors.joinGameRoom(gameHash, gameElements.paper, { from: bob, value: 10 });

      // playerB can reveal the game
      let transaction = await rockPaperScissors.revealGameForce(gameHash, { from: bob });

      let { event, args } = transaction.logs[0];
      assert.equal(event, 'LogRevealGame');
      assert.equal(args.gameHash, gameHash);
      assert.equal(args.bets.toString(), (20).toString());
      assert.equal(args.playerAElement.toString(), gameElements.default);
      assert.equal(args.playerBElement.toString(), gameElements.paper);
      assert.equal(args.winner, bob);
      assert.equal(args.isOver, true);
    })
  })

  describe('rewardGame function', function () {
    it('should get reward from the game', async function () {
      // alice create the game
      let timeoutBlock = 2
      await rockPaperScissors.createGameRoom(gameHash, timeoutBlock, { from: alice, value: 10 });

      // bob join the game
      await rockPaperScissors.joinGameRoom(gameHash, gameElements.paper, { from: bob, value: 10 });

      // alice reveal the game
      let randomString = web3.fromUtf8("this_is_player_defined_secret_string");
      await rockPaperScissors.revealGame(gameHash, gameElements.rock, randomString, { from: alice });

      // get reward
      let transaction = await rockPaperScissors.rewardGame(gameHash);
      let { event, args } = transaction.logs[0];
      assert.equal(event, 'LogRewardGame');
      assert.equal(args.gameHash, gameHash);
      assert.equal(args.bets.toString(), '20');
      assert.equal(args.winner, bob);
      assert.equal(args.playerABalance.toString(), '0');
      assert.equal(args.playerBBalance.toString(), '20');
      assert.equal(args.isReward, true);
    })

    it('should let player take their money back when game ended in a draw', async function () {
      // alice create the game
      let timeoutBlock = 2
      await rockPaperScissors.createGameRoom(gameHash, timeoutBlock, { from: alice, value: 30 });

      // bob join the game
      await rockPaperScissors.joinGameRoom(gameHash, gameElements.rock, { from: bob, value: 30 });

      // alice reveal the game
      let randomString = web3.fromUtf8("this_is_player_defined_secret_string");
      await rockPaperScissors.revealGame(gameHash, gameElements.rock, randomString, { from: alice });

      // get reward
      let transaction = await rockPaperScissors.rewardGame(gameHash);
      let { event, args } = transaction.logs[0];
      assert.equal(event, 'LogRewardGame');
      assert.equal(args.gameHash, gameHash);
      assert.equal(args.bets.toString(), '60');
      assert.equal(args.winner, 0);
      assert.equal(args.playerABalance.toString(), '30');
      assert.equal(args.playerBBalance.toString(), '30');
      assert.equal(args.isReward, true);
    })
  })

  describe('withdraw function', function () {
    it('should let winner take money back', async function () {
      // alice create the game
      let timeoutBlock = 2
      await rockPaperScissors.createGameRoom(gameHash, timeoutBlock, { from: alice, value: 25 });

      // bob join the game
      await rockPaperScissors.joinGameRoom(gameHash, gameElements.scissor, { from: bob, value: 25 });

      // alice reveal the game
      let randomString = web3.fromUtf8("this_is_player_defined_secret_string");
      await rockPaperScissors.revealGame(gameHash, gameElements.rock, randomString, { from: alice });

      // get reward
      await rockPaperScissors.rewardGame(gameHash);

      // alice cant get 50
      let transaction = await rockPaperScissors.withdraw({ from: alice });
      let { event, args } = transaction.logs[0];
      assert.equal(event, 'LogWithdraw');
      assert.equal(args.player, alice);
      assert.equal(args.balance.toString(), '50');
    })
  })

  /**
   * default test
   */
  describe('say somthing', function () {
    it('should return "hello world"', async function () {
      let result = await rockPaperScissors.say("hello world");
      assert.equal(result, 'hello world');
    })
  })
})