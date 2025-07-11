#!/bin/bash

echo "Getting Sequencer Info..."

# Get peer ID from op-node
PEER_ID=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"opp2p_self","params":[],"id":1}' \
  http://localhost:9545 | jq -r '.result.peerID')

# Get sova-reth enode and extract pubkey
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
echo "OP P2P Bootnode: /ip4/$PUBLIC_IP/tcp/9222/p2p/$PEER_ID"
echo "Reth P2P Bootnode: enode://$ENODE_PUBKEY@$PUBLIC_IP:30303"
echo ""
echo "Validator .env variables:"
echo "SEQUENCER_HTTP_RPC=http://$PUBLIC_IP:8545"
echo "SEQUENCER_P2P_BOOTNODE=/ip4/$PUBLIC_IP/tcp/9222/p2p/$PEER_ID"
echo "SEQUENCER_BOOTNODE=enode://$ENODE_PUBKEY@$PUBLIC_IP:30303"