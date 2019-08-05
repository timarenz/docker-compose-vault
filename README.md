# docker-compose Vault

This Docker Compose environment can be used to easily set up a three node Vault cluster using Raft as storage backend and Vault Transit for auto-unsealing.

## Disclaimer
This is Vault configuration example is only meant for experimentation. As root tokens, recovery and unseal keys are written in clear text to log files and the file system of the host machine do not use this in production.

Also, please do not use the unseal technique of the vault-transit instance in production.

## Usage

Just run `docker-compose up` and after a few moments a brand new Vault cluster will be listening on `http://localhost:8200`.

You can use the Vault binary on your local machine to talk to the Vault cluster or just point your browser to the address listed above.

### Enterprise binaries

To use enterprise binaries copy the linux amd64 version of the Vault enterprise binary along side the docker-compose.yaml file and make sure you comment line #3 in the `Dockerfile`.

The `Dockerfile` should look like this after you uncommented the line #3.

````Dockerfile
FROM vault:1.2.0
RUN apk add --no-cache curl
COPY vault /bin/vault
````

During the docker-compose up process a custom Vault Docker image will be build. Now that line #3 is uncommented the Vault enteprise binary in the parent folder will be copied into the Docker image

## Container overview

There are several containers with different functions.

### vault-transit

This is a single Vault instance with the transit engine enabled which allows the main Vault cluster to auto-unseal using Vault Transit.

Initialization, configuration and unsealing is automated by the `vault-transit-init.sh` script

### vault-1

This is the first members of the main Vault cluster. When this instance is started the first time it is automatically initialized using the `vault-init.sh` script.

For auto-unsealing the Transit Engine of the vault-transit instance is used.

### vault-2, vault-3

The second and third instances of the main Vault cluster are also automatically unsealed using the Transit Engine of the vault-transit instance.

During the first start each instance will be joined to the raft storage backend, intialized by the first Vault instance, using the `vault-raft-join.sh` script.

### load-balancer

HAProxy is running in this container to forward the traffic on port 8200 to the active Vault instance of the main cluster.

You can also connect to `http://localhost:8404`to have a look at the HAProxy stats and to see which one is the active Vault instance.

## Initialization and auto-unseal process of the vault-transit instance

The vault-transit instance uses a script (`vault-transit-init.sh`) which  automically initializes, configures and auto-unseals this instance.

During the initialization process the root token (`token.txt`) and the unseal key (`key.txt`) are saved in the `vault-transit` directory.

In additiona a flag file is created inside of the vault-transit container located at `$HOME/initialized.txt`. Which is used to only run the initial configuration (enable transit secret engine, creating token and policy for auto-unseal, etc.) during the first start of the container.

Should there be problems with the initial configuration just delete the file or destroy the container (volume) to force the intial configuration process to run again.

## Initialization process of the vault-1 instance

While the Transit Engine is used to auto-unseal the main Vault cluster it still needs to be initialized. This is done using the `vault-init.sh` script on the first Vault instance.

During the initial process the root token and the recovery keys are written in the `vault-1`directory.

## To Do

The following enhancements might be added in the future:

* Use TLS for all communication
* Configure proxy procotol with HAProxy to pass through client source IP
