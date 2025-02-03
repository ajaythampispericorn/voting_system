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

## PRE-REQUISTIES  

* APTOS CLI  

## INSTALLATION  

### APTOS CLI  

Go to Aptos [CLI release page](https://github.com/aptos-labs/aptos-core/releases?q=cli&expanded=true)  
Follow the instructions given to install Aptos CLI  

To verify installation,  
```  
aptos --version  
```  

## SETUP CLI CONFIGURATION  

1. Run the command  
```
aptos init  
```  

To use default settings, you can provide no input and just press “Enter”.  

## COMPILING AND TESTING  

```
aptos move compile  

aptos move test   
```  

## PUBLISHING   

```
aptos move publish  
```  

## INTERACTING WITH CONTRACT  

### Initialize module  

```  
aptos move call --function-id <voting_addr::voting_system::initialize> --args <account_address>  
```  

### Create Election  

```  
aptos move call --function-id <voting_addr::voting_system::create_election> --args <account_address> "Election Title" ["Candidate1", "Candidate2"]  
```  

### Cast A Vote  
```  
aptos move call --function-id <voting_addr::voting_system::cast_vote> --args <voter_address> <election_id> <candidate_index>  
```  

### Query Election Details  
```  
aptos move call --function-id <voting_addr::voting_system::get_election_details> --args <election_id>  
``` 

### Check If A User Has Voted  

```  
aptos move call --function-id <voting_addr::voting_system::has_voted> --args <voter_address> <election_id>  
```  

