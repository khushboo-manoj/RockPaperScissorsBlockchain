// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

contract RPSGame {
    // GameState - INITIATED after initial game setup, RESPONDED after responder adds hash choice, WIN or DRAW after final scoring
    enum RPSGameState {INITIATED, RESPONDED, WIN, DRAW}
    
    // PlayerState - PENDING until they add hashed choice, PLAYED after adding hash choice, CHOICE_STORED once raw choice and random string are stored
    enum PlayerState {PENDING, PLAYED, CHOICE_STORED}
    
    // 0 before choices are stored, 1 for Rock, 2 for Paper, 3 for Scissors. Strings are stored only to generate comment with choice names
    string[4] choiceMap = ['None', 'Rock', 'Paper', 'Scissors'];
    
    struct RPSGameData {
        address initiator; // Address of the initiator
        PlayerState initiator_state; // State of the initiator
        bytes32 initiator_hash; // Hashed choice of the initiator
        uint8 initiator_choice; // Raw number of initiator's choice - 1 for Rock, 2 for Paper, 3 for Scissors
        string initiator_random_str; // Random string chosen by the initiator
        
	    address responder; // Address of the responder
        PlayerState responder_state; // State of the responder
        bytes32 responder_hash; // Hashed choice of the responder
        uint8 responder_choice; // Raw number of responder's choice - 1 for Rock, 2 for Paper, 3 for Scissors
        string responder_random_str; // Random string chosen by the responder
                
        RPSGameState state; // Game State
        address winner; // Address of winner after completion. address(0) in case of draw
        string comment; // Comment specifying what happened in the game after completion
    }
    
    RPSGameData _gameData;
    
    // Initiator sets up the game and stores its hashed choice in the creation itself. Game and player states are adjusted accordingly
    constructor(address _initiator, address _responder, bytes32 _initiator_hash) {
        _gameData = RPSGameData({
                                    initiator: _initiator,
                                    initiator_state: PlayerState.PLAYED,
                                    initiator_hash: _initiator_hash, 
                                    initiator_choice: 0,
                                    initiator_random_str: '',
                                    responder: _responder, 
                                    responder_state: PlayerState.PENDING,
                                    responder_hash: 0, 
                                    responder_choice: 0,
                                    responder_random_str: '',
                                    state: RPSGameState.INITIATED,
                                    winner: address(0),
                                    comment: ''
                            });
    }
    
    // Responder stores their hashed choice. Game and player states are adjusted accordingly.
    function addResponse(bytes32 _responder_hash) public {
        require(_gameData.state == RPSGameState.INITIATED, "Hashed choice already added!");
        _gameData.responder_hash = _responder_hash;
        _gameData.state = RPSGameState.RESPONDED;
        _gameData.responder_state = PlayerState.PLAYED;
    }
    
    // Initiator adds raw choice number and random string. If responder has already done the same, the game should process the completion execution
    function addInitiatorChoice(uint8 _choice, string memory _randomStr) public returns (bool) {
        require(_gameData.state == RPSGameState.RESPONDED, "Choice details already added or too early to add!");
        require(_gameData.initiator_state == PlayerState.PLAYED, "Choice details already added or too early to add!");
        _gameData.initiator_choice = _choice;
        _gameData.initiator_random_str = _randomStr;
        _gameData.initiator_state = PlayerState.CHOICE_STORED;
        if (_gameData.responder_state == PlayerState.CHOICE_STORED) {
            __validateAndExecute();
        }
        return true;
    }

    // Responder adds raw choice number and random string. If initiator has already done the same, the game should process the completion execution
    function addResponderChoice(uint8 _choice, string memory _randomStr) public returns (bool) {
        require(_gameData.state == RPSGameState.RESPONDED, "Choice details already added or too early to add!");
        require(_gameData.responder_state == PlayerState.PLAYED, "Choice details already added or too early to add!");
        _gameData.responder_choice = _choice;
        _gameData.responder_random_str = _randomStr;
        _gameData.responder_state = PlayerState.CHOICE_STORED;
        if (_gameData.initiator_state == PlayerState.CHOICE_STORED) {
            __validateAndExecute();
        }
        return true;
    }
    
    // Core game logic to check raw choices against stored hashes, and then the actual choice comparison
    // Can be split into multiple functions internally
    function __validateAndExecute() private {
        bytes32 initiatorCalcHash = sha256(abi.encodePacked(choiceMap[_gameData.initiator_choice], '-', _gameData.initiator_random_str));
        bytes32 responderCalcHash = sha256(abi.encodePacked(choiceMap[_gameData.responder_choice], '-', _gameData.responder_random_str));
        bool initiatorAttempt = false;
        bool responderAttempt = false;
        
        if (initiatorCalcHash == _gameData.initiator_hash) {
            initiatorAttempt = true;
        }
        
        if (responderCalcHash == _gameData.responder_hash) {
            responderAttempt = true;
        }
        
        if (!initiatorAttempt && !responderAttempt) {
            _gameData.state = RPSGameState.DRAW;
            _gameData.winner = address(0);
            _gameData.comment = "Both choices invalid";
        } else if (!initiatorAttempt) {
            _gameData.state = RPSGameState.WIN;
            _gameData.winner = _gameData.responder;
            _gameData.comment = "Initiator choice invalid";
        } else if (!responderAttempt) {
            _gameData.state = RPSGameState.WIN;
            _gameData.winner = _gameData.initiator;
            _gameData.comment = "Responder choice invalid";
        } else {
            uint8 winner = __findWinner(_gameData.initiator_choice, _gameData.responder_choice);
            if (winner == 0) {
                _gameData.state = RPSGameState.DRAW;
                _gameData.winner = address(0);
                _gameData.comment = "Both choices are the same";
            } else if (winner == 1) {
                _gameData.state = RPSGameState.WIN;
                _gameData.winner = _gameData.initiator;
                _gameData.comment = string(abi.encodePacked(choiceMap[_gameData.initiator_choice], ' beats ', choiceMap[_gameData.responder_choice]));
            } else if (winner == 2) {
                _gameData.state = RPSGameState.WIN;
                _gameData.winner = _gameData.responder;
                _gameData.comment = string(abi.encodePacked(choiceMap[_gameData.responder_choice], ' beats ', choiceMap[_gameData.initiator_choice]));
            } else {
                _gameData.state = RPSGameState.DRAW;
                _gameData.winner = address(0);
                _gameData.comment = "An error occurred in game execution";
            }
        }
    }

    function __findWinner(uint8 _initiatorChoice, uint8 _responderChoice) private pure returns (uint8){
        if (_initiatorChoice == _responderChoice) {
            return 0;
        } else if (_initiatorChoice == 1) {
            if (_responderChoice == 2) {
                return 2;
            } else {
                return 1;
            }
        } else if (_initiatorChoice == 2) {
            if (_responderChoice == 3) {
                return 2;
            } else {
                return 1;
            }
        } else if (_initiatorChoice == 3) {
            if (_responderChoice == 1) {
                return 2;
            } else {
                return 1;
            }
        }
        
        return 0;
    }
    
    // Returns the address of the winner, GameState (2 for WIN, 3 for DRAW), and the comment
    function getResult() public view returns (address, RPSGameState, string memory) {
        require(_gameData.state == RPSGameState.WIN || _gameData.state == RPSGameState.DRAW, "Game not completed yet!");
        return (_gameData.winner, _gameData.state, _gameData.comment);
    } 
    
}


contract RPSServer {
    // Mapping for each game instance with the first address being the initiator and internal key address being the responder
    mapping(address => mapping(address => RPSGame)) _gameList;
    
    // Checks that zero address or same address is not passed
    modifier checkAddress(address _address){
        require(_address != address(0), "Zero address not allowed!");
        require(msg.sender != _address, "You can't play with yourself");
        _;
    }
    
    // Checks that choice is between 1-3
    modifier checkChoiceRange(uint8 _choice){
        require(_choice >= 1 && _choice <= 3, "Choice can only be in: 1 (Rock), 2 (Paper), 3 (Scissors)");
        _;
    }

    // Initiator sets up the game and stores its hashed choice in the creation itself. New game created and appropriate function called    
    function initiateGame(address _responder, bytes32 _initiator_hash) public checkAddress(_responder) {
        RPSGame game = new RPSGame(msg.sender, _responder, _initiator_hash);
        _gameList[msg.sender][_responder] = game;
    }

    // Responder stores their hashed choice. Appropriate RPSGame function called   
    function respond(address _initiator, bytes32 _responder_hash) public checkAddress(_initiator) {
        RPSGame game = _gameList[_initiator][msg.sender];
        game.addResponse(_responder_hash);
    }

    // Initiator adds raw choice number and random string. Appropriate RPSGame function called  
    function addInitiatorChoice(address _responder, uint8 _choice, string memory _randomStr) public checkAddress(_responder) checkChoiceRange(_choice) returns (bool) {
        RPSGame game = _gameList[msg.sender][_responder];
        return game.addInitiatorChoice(_choice, _randomStr);
    }

    // Responder adds raw choice number and random string. Appropriate RPSGame function called
    function addResponderChoice(address _initiator, uint8 _choice, string memory _randomStr) public checkAddress(_initiator) checkChoiceRange(_choice) returns (bool) {
        RPSGame game = _gameList[_initiator][msg.sender];
        return game.addResponderChoice(_choice, _randomStr);
    }
    
    // Result details request by the initiator
    function getInitiatorResult(address _responder) public view checkAddress(_responder) returns (address, RPSGame.RPSGameState, string memory) {
        RPSGame game = _gameList[msg.sender][_responder];
        return game.getResult();
    }

    // Result details request by the responder
    function getResponderResult(address _initiator) public view checkAddress(_initiator) returns (address, RPSGame.RPSGameState, string memory) {
        RPSGame game = _gameList[_initiator][msg.sender];
        return game.getResult();
    }
}







