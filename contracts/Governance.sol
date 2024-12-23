// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract GovernanceContract {
    struct Proposal {
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCounter;

    event ProposalCreated(uint256 indexed proposalId, string description);
    event ProposalVoted(uint256 indexed proposalId, bool support);
    event ProposalExecuted(uint256 indexed proposalId);

    function createProposal(string memory _description) external {
        proposalCounter++;
        proposals[proposalCounter] = Proposal(_description, 0, 0, block.timestamp + 1 weeks, false);
        emit ProposalCreated(proposalCounter, _description);
    }

    function vote(uint256 _proposalId, bool _support) external {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp < proposal.deadline, "Voting period ended");

        if (_support) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }
        emit ProposalVoted(_proposalId, _support);
    }

    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal rejected");

        proposal.executed = true;
        emit ProposalExecuted(_proposalId);
    }
}