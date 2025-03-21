# How to Start an Apache Ignite 3 Cluster

This guide walks you through the process of setting up and running an Apache Ignite 3 cluster using Docker containers. Follow these steps to get a three-node cluster up and running quickly.

## Prerequisites

- Docker and Docker Compose installed on your system
- Basic familiarity with command-line operations
- Java 11 or higher installed (for connecting to the cluster)

## Step 1: Create a Docker Compose Configuration

1. Create a file named `docker-compose.yml` in your project directory:

```yaml
name: ignite3  
  
x-ignite-def: &ignite-def  
  image: apacheignite/ignite:3.0.0  
  environment:  
    JVM_MAX_MEM: "4g"  
    JVM_MIN_MEM: "4g"  
  configs:  
    - source: node_config  
      target: /opt/ignite/etc/ignite-config.conf  
  
services:  
  node1:  
    <<: *ignite-def  
    command: --node-name node1  
    ports:  
      - "10300:10300"  
      - "10800:10800"  
  node2:  
    <<: *ignite-def  
    command: --node-name node2  
    ports:  
      - "10301:10300"  
      - "10801:10800"  
  node3:  
    <<: *ignite-def  
    command: --node-name node3  
    ports:  
      - "10302:10300"  
      - "10802:10800"  
  
configs:  
  node_config:  
    content: |  
      ignite {  
        network {  
          port: 3344  
          nodeFinder.netClusterNodes = ["node1:3344", "node2:3344", "node3:3344"]  
        }  
      }
```

## Step 2: Start the Ignite Cluster

1. Open a terminal in the directory containing your `docker-compose.yml` file
2. Run the following command to start the cluster:

```bash
docker compose up -d
```

3. Verify that all containers are running:

```bash
docker compose ps
```

You should see all three nodes with "running" status.

## Step 3: Initialize the Cluster

1. Start the Ignite CLI in Docker:

```bash
docker run --rm -it --network=host -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 apacheignite/ignite:3.0.0 cli
```

2. Inside the CLI, connect to one of the nodes:

```
connect http://localhost:10300
```

3. Initialize the cluster with a name and metastorage group:

```
cluster init --name=ignite3 --metastorage-group=node1,node2,node3
```

4. Exit the CLI by typing `exit` or pressing Ctrl+D

## Step 4: Verify Your Cluster

To verify your cluster is running correctly, you can use a simple Java client to connect to it. Create a simple test class that establishes a connection to the cluster.

## Understanding Port Configuration

The Docker Compose file exposes two types of ports for each node:

- **10300-10302**: REST API ports for administrative operations
- **10800-10802**: Client connection ports for your applications

## Stopping the Cluster

When you're done working with the cluster, you can stop it using:

```bash
docker compose down
```

This will stop and remove all the containers. Your data will be lost unless you've configured persistent storage.
