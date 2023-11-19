// src/pages/MatchesPage.js
import React, { useState } from 'react';
import { ethers } from 'ethers';
import { Tab, Tabs, TabList, TabPanel } from 'react-tabs';
import Modal from 'react-modal';
import BettingFormModal from '../components/BettingFormModal';
import 'react-tabs/style/react-tabs.css';
import './MatchesPage.css';
import { Web3Provider } from '@ethersproject/providers';
import SportsBettingContractABI from '../ProphetsABI.json';
import { toast } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';

//ETH Goerli Contract Address: 0xCaB40B230637fF23Fe8C3a5a2b58E96907189CCb
const contractAddress = '0xCaB40B230637fF23Fe8C3a5a2b58E96907189CCb'; // Replace with your deployed contract address
const contractAbi = SportsBettingContractABI;

const provider = new Web3Provider(window.ethereum);
const signer = provider.getSigner();
const contract = new ethers.Contract(contractAddress, contractAbi, signer);

Modal.setAppElement('#root'); // Set the root element for accessibility

const MatchesPage = () => {
  const [matches, setMatches] = useState([
    { id: 1, image: 'match1.jpg', status: 'New' },
    { id: 2, image: 'match2.jpg', status: 'Ongoing' },
    { id: 3, image: 'match1.jpg', status: 'Closed' },
    // ... other matches
  ]);

  const [showBettingModal, setShowBettingModal] = useState(false);
  const [selectedMatch, setSelectedMatch] = useState(null);

  const handleBettingStart = (match) => {
    setSelectedMatch(match);
    setShowBettingModal(true);
  };

  const handleBettingFormSubmit = async (formData) => {
    // Call the Ethereum contract method (createBettingPool) here
    // Update matches and move the match from "New" to "Ongoing"
    console.log('Betting form submitted with data:', formData);

    const teamA = ethers.encodeBytes32String(formData.teamA);
    const teamB = ethers.encodeBytes32String(formData.teamB);

    // Convert amountToBet to ethers format (wei)
    const amountToBetWei = ethers.parseEther(formData.amount);

    // Ensure contract is defined before proceeding
    if (!contract) {
        console.error('Contract is not defined.');
        return;
      }
  
      // Ensure createBettingPool method is present in the contract
      if (!contract.createBettingPool) {
        console.error('createBettingPool method not found in the contract.');
        return;
      }

    console.log("I am here before bettingPoolCall to estimate gas");

    // Prompt user to send Ether via MetaMask
    const userConfirmation = window.confirm(
        `Please confirm the transaction on MetaMask to send ${formData.amount} Ether.`
    );
    
    // Call the contract method (replace with your actual method and parameters)
    if (userConfirmation) {
        // Send the transaction
        console.log("I am here before bettingPoolCall");
        debugger;
        const tx = await contract.createBettingPool(
          teamA,
          teamB,
          amountToBetWei,
          1,
          {
            value: amountToBetWei, // Set the amount of Ether to send with the transaction
          }
        );
        
        await tx.wait();
        // Display a success notification
        toast.success('Transaction confirmed!', { autoClose: 5000 });
    
        // Update the matches state and close the modal
        setMatches((prevMatches) => {
        // Find the index of the match to be moved from "New" to "Ongoing"
         const matchIndex = prevMatches.findIndex((match) => match.status === 'New');

        if (matchIndex !== -1) {
         // Create a copy of the matches array and update the status of the matched item
            const updatedMatches = [...prevMatches];
            updatedMatches[matchIndex] = { ...updatedMatches[matchIndex], status: 'Ongoing' };

            return updatedMatches;
        }

        return prevMatches;
    });

    // Close the modal
    setShowBettingModal(false);
    }
  };

  return (
    <div className="matches-page">
      <h1>Matches</h1>
      <Tabs>
        <TabList>
          <Tab>New</Tab>
          <Tab>Ongoing</Tab>
          <Tab>Closed</Tab>
        </TabList>

        <TabPanel>
          {matches
            .filter((match) => match.status === 'New')
            .map((match) => (
              <div key={match.id} className="match-card">
                <img src={match.image} alt={`Match ${match.id}`} />
                <button onClick={() => handleBettingStart(match)}>Start Betting</button>
              </div>
            ))}
        </TabPanel>
        <TabPanel>
          {matches
            .filter((match) => match.status === 'Ongoing')
            .map((match) => (
              <div key={match.id} className="match-card">
                <img src={match.image} alt={`Match ${match.id}`} />
                <button onClick={() => handleBettingStart(match)}>Bet</button>
              </div>
            ))}
        </TabPanel>
        <TabPanel>
          {matches
            .filter((match) => match.status === 'Closed')
            .map((match) => (
              <div key={match.id} className="match-card">
                <img src={match.image} alt={`Match ${match.id}`} />
                <button onClick={() => handleBettingStart(match)}>Withdraw Winnings</button>
              </div>
            ))}
        </TabPanel>
        {/* ... Other TabPanels ... */}
      </Tabs>

      <Modal
        isOpen={showBettingModal}
        onRequestClose={() => setShowBettingModal(false)}
        contentLabel="Betting Form Modal"
      >
        {selectedMatch && (
          <BettingFormModal match={selectedMatch} onSubmit={handleBettingFormSubmit} />
        )}
      </Modal>
    </div>
  );
};

export default MatchesPage;