"use client";

import { useState, useCallback } from 'react';
import { useCurrentAccount, useSignAndExecuteTransactionBlock } from '@mysten/dapp-kit';
import { SuiClient } from '@mysten/sui/client';
import { 
  createFixedChallengeTransaction,
  joinChallengeTransaction,
  claimRewardTransaction,
  submitFitnessDataTransaction,
  parseChallengeData,
  parseParticipantData
} from '@/utils/contractUtils';
import { showErrorToast } from '@/utils/toast';
import { getNetworkClient } from '@/utils/networkUtils';
import { CHALLENGE_REGISTRY_ID } from '@/config/contractConfig';
import { logOperationStart, logOperationSuccess, logOperationError, logDebug } from '@/utils/logger'; 

export function useChallenges() {
  const account = useCurrentAccount();
  const { mutateAsync: signAndExecuteTransactionBlock } = useSignAndExecuteTransactionBlock();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const suiClient = getNetworkClient();
  
  /**
   * Create a new challenge
   */
  const createChallenge = useCallback(async (params: CreateChallengeParams) => {
    if (!account) {
      throw new Error('Wallet not connected');
    }
    
    setLoading(true);
    setError(null);
    
    try {
      logOperationStart('createChallenge', params);
      
      // Validate parameters
      if (!params.title || !params.description) {
        throw new Error('Title and description are required');
      }
      
      // Create transaction
      const tx = createFixedChallengeTransaction({
        title: params.title,
        description: params.description,
        challengeType: params.challengeType,
        stakeAmount: params.stakeAmount,
        duration: params.duration
      });
      
      // Execute transaction
      logDebug('Executing createChallenge transaction');
      const result = await signAndExecuteTransactionBlock({
        transactionBlock: tx,
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  }, [account, signAndExecuteTransactionBlock]);

  return {
    loading,
    error,
    createChallenge
  };
} 