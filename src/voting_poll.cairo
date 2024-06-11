use starknet::ContractAddress;

#[starknet::interface]
trait VoteTrait<TContractState> {
    fn get_vote_status(self: @TContractState) -> (u8, u8, u8, u8);
    fn voter_can_vote(self: @TContractState, voter_address: ContractAddress) -> bool;
    fn is_voter_registered(self: @TContractState, voter_address: ContractAddress) -> bool;
    fn vote(ref self: TContractState, vote: u8);
}

#[starknet::contract]
mod Vote {
    use starknet::{ContractAddress, get_caller_address};

    const YES: u8 = 1_u8;
    const NO: u8 = 0_u8;

    #[storage]
    struct Storage {
        vote_yes: u8,
        vote_no: u8,
        can_vote: LegacyMap::<ContractAddress, bool>,
        registered_voter: LegacyMap::<ContractAddress, bool>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, voter_1: ContractAddress, voter_2: ContractAddress, voter_3: ContractAddress) {
        self._register_voters(voter_1, voter_2, voter_3);

        // Initialize the vote count to 0
        self.vote_yes.write(0_u8);
        self.vote_no.write(0_u8);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        VoteCast: VoteCast,
        UnauthorizedAttempt: UnauthorizedAttempt,
    }

    #[derive(Drop, starknet::Event)]
    struct VoteCast {
        voter: ContractAddress,
        vote: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct UnauthorizedAttempt {
        Unauthorized_address: ContractAddress,
    }

    #[abi(embed_v0)]
    impl VoteImpl of super::VoteTrait<ContractState> {
        fn get_vote_status(self: @ContractState) -> (u8, u8, u8, u8) {
            let (n_yes, n_no) = self._get_voting_result();
            let (yes_percentage, no_percentage) = self._get_voting_result_in_percentage();
            (n_yes, n_no, yes_percentage, no_percentage)
        }

        fn voter_can_vote(self: @ContractState, voter_address: ContractAddress) -> bool {
            self.can_vote.read(voter_address)
        }

        fn is_voter_registered(self: @ContractState, voter_address: ContractAddress) -> bool {
            self.registered_voter.read(voter_address)
        }

        fn vote(ref self: ContractState, vote: u8) {
            assert!(vote == NO || vote == YES, "VOTE_0_OR_1");
            let caller: ContractAddress = get_caller_address();
            self._assert_allowed(caller);
            self.can_vote.write(caller, false);

            if (vote == YES) {
                self.vote_yes.write(self.vote_yes.read() + 1_u8);
            } else {
                self.vote_no.write(self.vote_no.read() + 1_u8);
            }

            self.emit(VoteCast {
                voter: caller,
                vote: vote,
            });
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _register_voters(ref self: ContractState, voter_1: ContractAddress, voter_2: ContractAddress, voter_3: ContractAddress) {
            self.registered_voter.write(voter_1, true);
            self.registered_voter.write(voter_2, true);
            self.registered_voter.write(voter_3, true);

            self.can_vote.write(voter_1, true);
            self.can_vote.write(voter_2, true);
            self.can_vote.write(voter_3, true);
        }
    }

    #[generate_trait]
    impl AssertsImpl of AssertsTrait {
        fn _assert_allowed(ref self: ContractState, address: ContractAddress) {
            let is_voter: bool = self.registered_voter.read((address));
            let can_vote: bool = self.can_vote.read((address));

            if (!can_vote) {
                self.emit(UnauthorizedAttempt {
                    Unauthorized_address: address,
                });
            }

            assert!(is_voter, "VOTER_NOT_REGISTERED");
            assert!(can_vote, "VOTER_ALREADY_VOTED");
        }
    }

    #[generate_trait]
    impl VoteResultFunctionsImpl of VoteResultFunctionsTrait {
        fn _get_voting_result(self: @ContractState) -> (u8, u8) {
            (self.vote_yes.read(), self.vote_no.read())
        }

        fn _get_voting_result_in_percentage(self: @ContractState) -> (u8, u8) {
            let total_votes: u8 = self.vote_yes.read() + self.vote_no.read();
            if (total_votes == 0_u8) {
                return (0_u8, 0_u8);
            }

            let yes_percentage: u8 = (self.vote_yes.read() * 100_u8) / (total_votes);
            let no_percentage: u8 = (self.vote_no.read() * 100_u8) / (total_votes);

            (yes_percentage, no_percentage)
        }
    }
}