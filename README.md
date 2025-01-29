# VOTING SYSTEM MODULE USING MOVE LANGUAGE  

This repository contains a Voting System module written in the Move language. The module allows administrators to create elections, manage candidates, and enable users to cast votes securely. The system also tracks voting events and ensures that each voter can only vote once per election.  

## FEATURES  

* **Election Creation** - Administrators can create elections with multiple candidates.  
* **Vote Casting** - Users can cast votes for candidates in active elections.  
* **Event Logging** - Records events for election creation and vote casting.  
* **Voter Validation** - Ensures voters cannot vote more than once in the same election.  
* **Election Details** - Provides a way to fetch election information, including the list of candidates and their vote counts.  

## DATA STRUCTURES  

### STRUCTS  
* **Candidate**: Represents a candidate with a name and vote count.  
* **Election**: Contains election details such as ID, title, candidates, and active status.  
* **VotingSystem**: Manages elections, event handles, and admin details.  
* **VoterRecord**: Tracks elections a user has voted in.  

### EVENTS  
* **ElectionCreatedEvent**: Fired when a new election is created.  
* **VoteCastEvent**: Fired when a vote is cast.  

