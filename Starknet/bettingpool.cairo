use starknet::{ContractAddress,ClassHash};
use array::{ArrayTrait, SpanSerde};
use starknet::{
  Store,
  storage_address_from_base_and_offset,
  storage_read_syscall,
  storage_write_syscall,
  SyscallResult,
  StorageBaseAddress,
};

#[starknet::interface]
trait BettingTimeTrait<TContractState> {
    //write function
    fn createBet(ref self: TContractState, game_id: u256, amount: u256, choice: bool);
    fn takeBet(ref self: TContractState, bet_id: u256, amount: u256);
    fn claimBet(ref self: TContractState, bet_id: u256);
    //read function
    fn get_player_balance(self : @TContractState,player_address : ContractAddress) -> u256;
    fn get_player_bet(self : @TContractState, player_address: ContractAddress,game_id : u256) -> u256;

    fn upgrade(ref self: TContractState,classhash : ClassHash);
}

#[starknet::contract]
mod BettingTime {
    use array::{ SpanTrait, SpanSerde };
    use starknet::syscalls::replace_class_syscall;
    use starknet::{ContractAddress, get_caller_address, get_contract_address,ClassHash};
    use traits::{Into, TryInto};

    #[storage]
    struct Storage {
        bets: LegacyMap<u256, Bet>,
        next_bet_id: u256,
        players_balances: LegacyMap<ContractAddress, u256>,
        players_bets: LegacyMap<(u256, ContractAddress), u256>,
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct Bet {
        betOwner: ContractAddress,
        game_id: u256,
        total_bet_allocation: u256,
        choice: bool,
        total_players: u256,
        betConcluded: bool,
        betResult: bool,
        total_winner_bet: u256,
        total_loser_bet: u256,
    }


    #[constructor]
    fn constructor(ref self: ContractState) {
        self.next_bet_id.write(0);
    }

    fn read_oracle(bet_id:u256) -> bool {
      if bet_id % 2 == 0 {
        return true;
      }
      return false;
    }

    #[external(v0)]
    impl BettingTimeImpl of super::BettingTimeTrait<ContractState> {

        //players_balances
        fn get_player_balance(self : @ContractState,player_address : ContractAddress) -> u256{
            self.players_balances.read(player_address)
        }
        //player_bet
        fn get_player_bet(self : @ContractState, player_address: ContractAddress,game_id : u256) -> u256 {
            self.players_bets.read((game_id,player_address))
        }
        fn createBet(ref self: ContractState, game_id: u256, amount: u256, choice: bool) {
            let bet_id = self.next_bet_id.read();
            self.next_bet_id.write(bet_id + 1);

            let bet = Bet {
            betOwner: get_caller_address(),
            game_id: game_id,
            total_bet_allocation: amount,
            choice: choice,
            total_players: 1,
            betConcluded: false,
            betResult: false,
            total_winner_bet: 0_u256,
            total_loser_bet: 0_u256,
            };

            self.bets.write(bet_id, bet);
            self.players_bets.write((bet_id, get_caller_address()), amount);
}

        fn takeBet(ref self: ContractState, bet_id: u256, amount: u256) {
            let mut bet = self.bets.read(bet_id);
            assert(amount > 0, 'Amount must be > 0');
            let caller = get_caller_address();
            assert(bet.betOwner != caller, 'Owner cannot enter bet twice');

            let mut player_bet = self.players_bets.read((bet_id, caller));
            player_bet += amount;
            self.players_bets.write((bet_id, caller), player_bet);

            bet.total_players += 1;
            bet.total_bet_allocation += amount;

            self.bets.write(bet_id, bet);
}

        fn claimBet(ref self: ContractState, bet_id: u256) {
            let mut bet = self.bets.read(bet_id);
            let caller = get_caller_address();

            if !bet.betConcluded {
            bet.betResult = read_oracle(bet_id);
            bet.betConcluded = true;
    }

            let player_bet = self.players_bets.read((bet_id, caller));
            assert(player_bet > 0, 'No bet placed by the caller');

            let claimer_side = if bet.betOwner == caller { bet.choice } else { !bet.choice };
            assert(bet.betResult == claimer_side, 'Claimer did not win');

            // Calculate the share for the winner
            let total_winner_share = bet.total_loser_bet;
            let winner_share = (total_winner_share * player_bet) / bet.total_winner_bet;

            // Update the player's balance
            let player_balance = self.players_balances.read(caller);
            self.players_balances.write(caller, player_bet);
        }

        fn upgrade(ref self: ContractState,classhash : ClassHash) {
            replace_class_syscall(classhash).unwrap();
        }
    }
}













// use starknet::{ContractAddress,ClassHash};
// use array::{ArrayTrait, SpanSerde};
// use starknet::{
//   Store,
//   storage_address_from_base_and_offset,
//   storage_read_syscall,
//   storage_write_syscall,
//   SyscallResult,
//   StorageBaseAddress,
// };


// #[starknet::interface]
// trait BettingPoolTrait<TContractState> {
//     //read functions
//     fn get_player_balance(self : @TContractState,player_address : ContractAddress) -> u256;
//     fn get_player_bet(self : @TContractState, player_address: ContractAddress,game_id : u256) -> u256;
    
//     //write functions
//     fn createBettingPool(ref self: TContractState,teamA: felt252, teamB: felt252, pool_id: u256, initial_amount: u256, teamId: u256);
//     fn bet(ref self: TContractState, bet_id: u256, amount: u256, choice: bool);
//     fn claimBet(ref self: TContractState, bet_id: u256);
//     fn withdraw(ref self: TContractState);

//     fn upgrade(ref self: TContractState,classhash : ClassHash);
// }


// #[starknet::contract]
// mod BettingPool {
//     use array::{ SpanTrait, SpanSerde };
//     use starknet::syscalls::replace_class_syscall;
//     use starknet::{ContractAddress, get_caller_address, get_contract_address,ClassHash};
//     use traits::{Into, TryInto};

//     #[storage]
//     struct Storage {
//         players_bets: LegacyMap<(u256, ContractAddress), u256>,
//         _bettingPools: u256,
//         amountPerPlayer: LegacyMap<ContractAddress, u256>, //Address to amount
//         teamPerPlayer: LegacyMap<ContractAddress, u256>, //The team that the player has bet for
//         playerClaimedWinnings: LegacyMap<ContractAddress, bool>, //True if the player has claimed their winnings
//     }

//     #[derive(Copy, Drop, Serde, starknet::Store)]
//     struct BettingPool {
//         pool_id: u256,
//         teamA: felt252,
//         teamB: felt252,
//         totalBetA: u256,//Total betting amount towards teamA
//         totalBetB: u256, //Total betting amount towards teamB
//         totalBettingAmount: u256,
//         winningTeam: u256,
//         safeId: ContractAddress, //Safe ID for Account Abstraction
//         timeOfCreation: u256, //maybe we just need the #[key] of the game_id or pool_id
//     }


//     #[constructor]
//     fn constructor(ref self: ContractState) {}

//     fn read_oracle(bet_id:u256) -> bool {
//       if bet_id % 2 == 0 {
//         return true;
//       }
//       return false;
//     }

//     #[external(v0)]
//     impl BettingPoolImpl of super::BettingPoolTrait<ContractState> {
//         //players_balances
//         fn get_player_balance(self : @ContractState,player_address : ContractAddress) -> u256{
//             self.players_balances.read(player_address)
//         }
//         //player_bet
//         fn get_player_bet(self : @ContractState, player_address: ContractAddress,game_id : u256) -> u256 {
//             self.players_bets.read((game_id,player_address))
//         }
//         fn createBettingPool(ref self: ContractState, teamA: felt252, teamB: felt252, pool_id: u256, initial_amount: u256, teamId: u256) {
//             let bet_id = self.next_bet_id.read();
//             let bet = self.amount.read();
//             self.next_bet_id.write(bet_id + 1);

//             let bet = Bet {
//             betOwner: get_caller_address(),
//             game_id: game_id,
//             total_bet_allocation: amount,
//             choice: choice,
//             total_players: 1,
//             betConcluded: false,
//             betResult: false,
//             total_winner_bet: 0_u256,
//             total_loser_bet: 0_u256,
//             };

//             self.bets.write(bet_id, bet);
//             self.players_bets.write((bet_id, get_caller_address()), amount);
// }

//         fn bet(ref self: ContractState, bet_id: u256, amount: u256, choice: bool) {
//             let mut bet = self.bets.read(bet_id);
//             assert(amount > 0, 'Amount must be > 0');
//             let caller = get_caller_address();
//             assert(bet.betOwner != caller, 'Owner cannot enter bet twice');

//             let mut player_bet = self.players_bets.read((bet_id, caller));
//             player_bet += amount;
//             self.players_bets.write((bet_id, caller), player_bet);

//             bet.total_players += 1;
//             bet.total_bet_allocation += amount;

//             self.bets.write(bet_id, bet);
// }

//         fn claimBet(ref self: ContractState, bet_id: u256) {
//             let mut bet = self.bets.read(bet_id);
//             let caller = get_caller_address();

//             if !bet.betConcluded {
//             bet.betResult = read_oracle(bet_id);
//             bet.betConcluded = true;
//     }

//             let player_bet = self.players_bets.read((bet_id, caller));
//             assert(player_bet > 0, 'No bet placed by the caller');

//             let claimer_side = if bet.betOwner == caller { bet.choice } else { !bet.choice };
//             assert(bet.betResult == claimer_side, 'Claimer did not win');

//             // Calculate the share for the winner
//             let total_winner_share = bet.total_loser_bet;
//             let winner_share = (total_winner_share * player_bet) / bet.total_winner_bet;

//             // Update the player's balance
//             let player_balance = self.players_balances.read(caller);
//             self.players_balances.write(caller, player_balance + winner_share);

//             self.bets.write(bet_id, bet);
//         }


//         fn withdraw(ref self: ContractState) {
//             let caller = get_caller_address();
//             let balance = self.players_balances.read(caller);
//             assert(balance > 0, 'No balance to withdraw');

//             // Logic to transfer the balance to the player's address
            
//             self.players_balances.write(caller, 0);
//         }

//         fn upgrade(ref self: ContractState,classhash : ClassHash) {
//             replace_class_syscall(classhash).unwrap();

//         }
//     }
// }