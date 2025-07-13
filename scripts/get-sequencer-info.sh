#!/bin/bash

# Script to extract sequencer peer information for validator configuration

echo "=== Getting Sequencer Peer Information ==="

# Get Reth node ID from sequencer
echo "Sequencer Reth Node ID:"
SEQUENCER_RETH_NODE_ID=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"method":"admin_nodeInfo","params":[],"id":1,"jsonrpc":"2.0"}' \
  http://localhost:8545 | jq -r '.result.enode' | cut -d'@' -f1)
echo $SEQUENCER_RETH_NODE_ID

# Get OP Node peer ID from sequencer  
echo "Sequencer OP Node Peer ID:"
SEQUENCER_OP_PEER_ID=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"method":"opp2p_self","params":[],"id":1,"jsonrpc":"2.0"}' \
  http://localhost:9545 | jq -r '.result.peerID')
echo $SEQUENCER_OP_PEER_ID

echo ""
echo "=== .env Configuration for Validator ==="
echo "# Add these to your validator's .env file:"
echo "SEQUENCER_RETH_STATIC_PEERS=${SEQUENCER_RETH_NODE_ID}@\${SEQUENCER_IP}:30303"
echo "SEQUENCER_OP_STATIC_PEERS=/ip4/\${SEQUENCER_IP}/tcp/9222/p2p/${SEQUENCER_OP_PEER_ID}"