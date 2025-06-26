#!/bin/bash

echo "Getting Sequencer Info..."

# Get peer ID from op-node
PEER_ID=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"opp2p_self","params":[],"id":1}' \
  http://${SEQUENCER_IP}:9545 | jq -r '.result.peerID')

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me)

echo ""
echo "Sequencer Info:"
echo "=================="
echo "HTTP RPC: http://$PUBLIC_IP:8545"
echo "P2P Bootnode: /ip4/$PUBLIC_IP/tcp/9003/p2p/$PEER_ID"
echo ""
echo "Validator .env variables:"
echo "SEQUENCER_HTTP_RPC=http://$PUBLIC_IP:8545"
echo "SEQUENCER_P2P_BOOTNODE=/ip4/$PUBLIC_IP/tcp/9003/p2p/$PEER_ID"
