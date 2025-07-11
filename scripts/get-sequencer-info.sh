#!/bin/bash

echo "Getting Sequencer Info..."

# Get ENR from op-node (more complete than just peer ID)
SEQUENCER_ENR=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"opp2p_self","params":[],"id":1}' \
  http://localhost:9545 | jq -r '.result.ENR')

# Get sova-reth enode and extract pubkey (corrected container name)
ENODE_PUBKEY=$(docker logs sova-op-testnet-sequencer-sova-reth-1 2>/dev/null | \
  grep "enode://" | \
  head -1 | \
  sed 's/.*enode:\/\/\([a-f0-9A-F]*\)@.*/\1/')

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me)

echo ""
echo "Sequencer Info:"
echo "=================="
echo "HTTP RPC: http://$PUBLIC_IP:8545"
echo "OP P2P Bootnode: $SEQUENCER_ENR"
echo "Reth P2P Bootnode: enode://$ENODE_PUBKEY@$PUBLIC_IP:30303"
echo ""
echo "Validator .env variables:"
echo "SEQUENCER_HTTP_RPC=http://$PUBLIC_IP:8545"
echo "SEQUENCER_P2P_BOOTNODE=$SEQUENCER_ENR"
echo "SEQUENCER_BOOTNODE=enode://$ENODE_PUBKEY@$PUBLIC_IP:30303"