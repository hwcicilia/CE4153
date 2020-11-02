// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;
pragma experimental ABIEncoderV2;

import "./Arbitration.sol";

contract Bet {

    struct Option {
        uint option_id;
        string description;
        uint option_balance;
        address payable[] addresses;
        uint[] individual_bets;
        uint individualCount;

    }

    struct Question{
        uint question_id;
        address payable owner;
        string description;
        uint expiryTime;
        bool open;
        address arbitrator;
        uint question_balance;
        uint deposit;

        Option[] options;
        
    }

    mapping(uint => Question) public questions;
    uint public questionsCount;
    address public owner;

    constructor () public {
        owner = msg.sender;
    }

    function addQuestion(string memory _desc, uint _expiryTime, address _arbitrator, string[] memory _options) public payable returns (uint) {
        require(msg.value >= 1);

        questionsCount++;

        Option[] memory optionsArray;
        address payable[] memory empty_address;
        uint[] memory empty_bets;

        for (uint i=0; i< _options.length; i++){
            optionsArray[i] = Option({
                option_id: i,
                description: _options[i],
                option_balance: 0,
                addresses: empty_address,
                individual_bets: empty_bets,
                individualCount: 0
            });
        }

        questions[questionsCount] = Question({
            question_id: questionsCount, 
            owner: msg.sender, 
            description: _desc, 
            expiryTime: _expiryTime,
            open: true,
            arbitrator: _arbitrator,
            options: optionsArray,
            question_balance: 0,
            deposit: msg.value}
        );

        return questionsCount;
    }

    function updateQuestionStatus() private {
        for(uint i=1; i<=questionsCount; i++){
            if((questions[i].open == true) && (questions[i].expiryTime <= block.timestamp)){
                closeQuestion(i);
            }
        }
    }

    function getAllQuestions() public returns (uint[] memory , string[] memory , uint[] memory){
        updateQuestionStatus();

        uint[] memory question_ids;
        string[] memory question_desc;
        uint[] memory question_exp;

        for (uint i=0; i<questionsCount; i++){
            question_ids[i] = questions[i].question_id;
            question_desc[i] = questions[i].description;
            question_exp[i] = questions[i].expiryTime;
        }
        return (question_ids, question_desc, question_exp);
    }

    function getFilteredQuestions(bool isOpen) public returns (uint[] memory , string[] memory , uint[] memory){
        updateQuestionStatus();

        uint[] memory question_ids;
        string[] memory question_desc;
        uint[] memory question_exp;

        for(uint i=1; i<=questionsCount; i++){
            if(questions[i].open == isOpen){
                question_ids[i] = questions[i].question_id;
                question_desc[i] = questions[i].description;
                question_exp[i] = questions[i].expiryTime;
            }
        }

        return (question_ids, question_desc, question_exp);
    }

    function getQuestionById(uint qid) public returns (uint, string memory, uint, string[] memory, uint[] memory) {
        updateQuestionStatus();
        require(qid <= questionsCount);

        Question memory qtn;

        for(uint i=1; i<=questionsCount; i++){
            if(questions[i].question_id == qid){
                qtn = questions[i];
                break;
            }
        }

        string[] memory opt_desc;
        uint[] memory opt_count;

        for(uint j=0; j<=3; j++){
            opt_desc[j] = qtn.options[j].description;
            opt_count[j] = qtn.options[j].individualCount;
        }

        return (qtn.question_id, qtn.description, qtn.expiryTime, opt_desc, opt_count);
        
    }

    function closeQuestion(uint question_id) public returns (uint){
        require(question_id <= questionsCount);
        require(questions[question_id].open == true);

        Question memory qtn = questions[question_id];

        Arbitration arb = Arbitration(qtn.arbitrator);
        // arb.addDetails(qtn.description, qtn.options);

        uint correct_prediction = arb.selectWinner();

        Option memory correct_option = qtn.options[correct_prediction];

        qtn.owner.transfer(qtn.deposit);

        uint total_reward = qtn.question_balance;

        for(uint i=1; i<=correct_option.individualCount; i++){
            address payable reward_address = correct_option.addresses[i];
            uint reward_amount = correct_option.individual_bets[i] / correct_option.option_balance * total_reward;

            require(reward_amount <= qtn.question_balance);
            qtn.question_balance -= reward_amount;
            reward_address.transfer(reward_amount);
        }

        qtn.open = false;

        return question_id;
    }

    function makeBet(uint question_id, uint option_id) public payable returns (uint){
        require(questions[question_id].open == true);

        Question memory qtn = questions[question_id];
        Option memory opt = qtn.options[option_id];

        uint index;
        for (uint i=0; i<opt.addresses.length; i++){
            if(opt.addresses[i] == msg.sender){
                index = i;
                break;
            }

            if(i == opt.addresses.length-1){
                index = i+1;
                opt.addresses[index] = msg.sender;
                opt.individualCount += 1;

            }
        }

        opt.individual_bets[index] += msg.value;
        opt.option_balance += msg.value;

        qtn.question_balance += msg.value;

        return question_id;
    }
    
}