## running-sova

A collection of docker-compose files that orchestrate running Sova validator services in various configurations.

### Dockerfiles

1. [./dockerfiles/dev-docker-compose](./dockerfiles/dev-docker-compose)
    - Used to run a Sova validator locally in --dev mode. This means validator consensus is mocked and there is only one tx per sova block. This uses a regtest bitcoin node to mock bitcoin interactions.

2. [./dockerfiles/testnet-aux-services-docker-compose](./dockerfiles/testnet-aux-services-docker-compose)
    - Used to run a centralized version of all Sova validator auxiliary services. This bundle of services can be used by a multinode validator testnet cluster.