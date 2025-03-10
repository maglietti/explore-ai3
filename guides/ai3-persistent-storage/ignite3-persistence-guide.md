# Getting Started with Apache Ignite 3 Persistent Storage

## Introduction

Apache Ignite 3 provides robust persistent storage capabilities that allow your data to survive system restarts and crashes while maintaining high performance. This guide will walk you through the basics of setting up and using Ignite's RocksDB-based persistent storage with the Chinook database in a Docker-based environment.

## Persistence Fundamentals

### What is Ignite Persistence?

Ignite Persistence is designed to provide quick and responsive persistent storage. When using persistent storage:

- Ignite stores all data on disk
- It loads as much data as possible into RAM for processing
- Each partition is stored in a separate file on disk
- In addition to data partitions, Ignite stores indexes and metadata on disk

This architecture combines the performance benefits of in-memory computing with the durability of disk-based storage.

### Storage Types

Ignite 3 provides multiple storage options:

**Persistent Storage** - Data is stored on disk and survives cluster restarts

- **AIPerist Engine** - Default persistent storage engine with checkpointing
- **RocksDB Engine** - LSM-tree based persistent storage optimized for write-heavy workloads

**Volatile Storage** - Data is stored only in RAM and is lost on cluster shutdown

- **AIMem Engine** - In-memory storage with no persistence

## Setting Up Persistent Storage

### Storage Profiles

In Ignite 3, persistence is configured using **storage profiles**. A storage profile defines how data is stored, cached, and managed by the storage engine.

Each storage profile has specific properties depending on the engine type, but all profiles must specify:

- **name** - A unique identifier for the profile
- **engine** - The storage engine to use

### Basic Configuration Steps

Here's how to set up persistent storage in Apache Ignite 3:

- **Configure the Storage Engine**: Define the storage engine parameters
- **Create Storage Profile**: Define profiles that use the configured storage engines
- **Assign Profiles to Distribution Zones**: Link your storage profiles to distribution zones
- **Create Tables in These Zones**: Tables created in these zones will use the persistent storage

## Using Storage Profiles with Distribution Zones

After defining storage profiles, you need to assign them to distribution zones:

```sql
CREATE ZONE RocksDBZone WITH replicas=2, storage_profiles='rocksProfile';
CREATE ZONE InMemoryZone WITH replicas=2, storage_profiles='aimemory';
```

Then, when creating tables, specify the zone to determine the storage type:

```sql
-- This table will use RocksDB persistent storage
CREATE TABLE PersistentData (
    id INT PRIMARY KEY,
    value VARCHAR
) ZONE RocksDBZone;

-- This table will use in-memory storage only
CREATE TABLE VolatileData (
    id INT PRIMARY KEY,
    value VARCHAR
) ZONE InMemoryZone;
```

## Docker Cluster with Persistence

Create a `docker-compose.yml` file in your working directory:

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
    volumes:
      - ./data/node1:/opt/ignite/work

  node2:
    <<: *ignite-def
    command: --node-name node2
    ports:
      - "10301:10300"
      - "10801:10800"
    volumes:
      - ./data/node2:/opt/ignite/work

  node3:
    <<: *ignite-def
    command: --node-name node3
    ports:
      - "10302:10300"
      - "10802:10800"
    volumes:
      - ./data/node3:/opt/ignite/work

configs:
  node_config:
    content: |
      ignite {
        network {
          port: 3344
          nodeFinder.netClusterNodes = ["node1:3344", "node2:3344", "node3:3344"]
        }
        "storage": {
          "profiles": [
            {
              name: "rocksDbProfile"
              engine: "rocksdb"
            }
          ]
        }
      }
```

The `ignite` configuration in the Docker Compose file:

- Adds a storage profile named `rocksDbProfile` that uses the RocksDB engine to the default node configuration
- Sets the storage size to 256MB (268435456 bytes)
- Stores persistent data in the `data` directory where docker was run

### Start the Cluster

```bash
docker-compose up -d
```

### Verify the Cluster

In the same directory as your `docker-compose.yml` file, run `docker compose ps` and see that the nodes are "running".

```shell
docker compose ps
NAME              IMAGE                       COMMAND                  SERVICE   CREATED         STATUS         PORTS
ignite3-node1-1   apacheignite/ignite:3.0.0   "docker-entrypoint.s…"   node1     6 minutes ago   Up 6 minutes   0.0.0.0:10300->10300/tcp, 3344/tcp, 0.0.0.0:10800->10800/tcp
ignite3-node2-1   apacheignite/ignite:3.0.0   "docker-entrypoint.s…"   node2     6 minutes ago   Up 6 minutes   3344/tcp, 0.0.0.0:10301->10300/tcp, 0.0.0.0:10801->10800/tcp
ignite3-node3-1   apacheignite/ignite:3.0.0   "docker-entrypoint.s…"   node3     6 minutes ago   Up 6 minutes   3344/tcp, 0.0.0.0:10302->10300/tcp, 0.0.0.0:10802->10800/tcp
```

Verify the docker network configuration with `docker network ls` and see the `ignite3_default` network.

```shell
docker network ls
NETWORK ID     NAME              DRIVER    SCOPE
99728e97d2f6   bridge            bridge    local
b55ac8b4a057   host              host      local
8f56c9a9e047   ignite3_default   bridge    local
2a046c74a6bd   none              null      local
```

Check the volumes using `docker volume ls`.

```shell
docker volume ls
DRIVER    VOLUME NAME
local     ignite3_ignite-data1
local     ignite3_ignite-data2
local     ignite3_ignite-data3
```

Inspect the data directory with the `tree` command:

```shell
tree -L 2 data
data
├── node1
│   ├── cmg
│   ├── metastorage
│   ├── partitions
│   ├── vault
│   └── volatile-log-spillout
├── node2
│   ├── cmg
│   ├── metastorage
│   ├── partitions
│   ├── vault
│   └── volatile-log-spillout
└── node3
    ├── cmg
    ├── metastorage
    ├── partitions
    ├── vault
    └── volatile-log-spillout
```

### Connect to and Initialize the Cluster

In your terminal, run:

```bash
docker run -it --rm --net ignite3_default apacheignite/ignite3 cli
```

This starts an interactive CLI container connected to the same Docker network as our cluster and mounts a volume containing the sql files for the Chinook Database. When prompted, connect to the default node by entering `n`.

Connect to `node1` of the cluster:

```shell
connect http://node1:10300
```

You should see a message that you're connected to http://node1:10300 and possibly a note that the cluster is not initialized.

Before we can use the cluster, we need to initialize it:

```shell
cluster init --name=ignite3 --metastorage-group=node1,node2,node3
```

You should see the message "Cluster was initialized successfully".

```shell
[node1]> cluster init --name=ignite3 --metastorage-group=node1,node2,node3
Cluster was initialized successfully
```

### Create Persistent Distribution Zones

The Ignite configuration that we set in `docker compose` created a new storage profile that we will use to store data.

You can verify the storage profile with `node config show ignite.storage`:

```shell
[node1]> node config show ignite.storage
engines {
    aimem {
        pageSize=16384
    }
    aipersist {
        checkpoint {
            checkpointDelayMillis=200
            checkpointThreads=4
            compactionThreads=4
            interval=180000
            intervalDeviation=40
            logReadLockThresholdTimeout=0
            readLockTimeout=10000
            useAsyncFileIoFactory=true
        }
        pageSize=16384
    }
    rocksdb {
        flushDelayMillis=100
    }
}
profiles=[
    {
        engine=rocksdb
        name=rocksDbProfile
        size=268435456
        writeBufferSize=67108864
    },
    {
        engine=aipersist
        name=default
        replacementMode=CLOCK
        size=3138717286
    }
]
```

We will use the `rocksDbProfile` to store our Chinook Record Store data.

In the SQL CLI, enter the `sql-cli` by typing `sql` and create a distribution zone that uses our RocksDB storage profile:

```sql
CREATE ZONE ChinookRocksDB WITH replicas=2, storage_profiles='rocksDbProfile';
```

```shell
[node1]> sql 
sql-cli> CREATE ZONE ChinookRocksDB WITH replicas=2, storage_profiles='rocksDbProfile';
Updated 0 rows.
```

### Create Persistent Chinook Tables

Let's create the Chinook database tables in the RocksDB persistent zone:

```sql
-- Create Artist table
CREATE TABLE Artist (
    ArtistId INT NOT NULL,
    Name VARCHAR(120),
    PRIMARY KEY (ArtistId)
) ZONE ChinookRocksDB;

-- Create Album table
CREATE TABLE Album (
    AlbumId INT NOT NULL,
    Title VARCHAR(160) NOT NULL,
    ArtistId INT NOT NULL,
    PRIMARY KEY (AlbumId, ArtistId)
) COLOCATE BY (ArtistId) ZONE ChinookRocksDB;

-- Create Genre table
CREATE TABLE Genre (
    GenreId INT NOT NULL,
    Name VARCHAR(120),
    PRIMARY KEY (GenreId)
) ZONE ChinookRocksDB;

-- Create Track table
CREATE TABLE Track (
    TrackId INT NOT NULL,
    Name VARCHAR(200) NOT NULL,
    AlbumId INT,
    MediaTypeId INT NOT NULL,
    GenreId INT,
    Composer VARCHAR(220),
    Milliseconds INT NOT NULL,
    Bytes INT,
    UnitPrice NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (TrackId, AlbumId)
) COLOCATE BY (AlbumId) ZONE ChinookRocksDB;
```

### Load Chinook Data

Let's insert some sample data into our tables:

```sql
-- Insert data into Artist table
INSERT INTO Artist (ArtistId, Name) VALUES
(1, 'AC/DC'),
(2, 'Accept'),
(3, 'Aerosmith'),
(4, 'Alanis Morissette'),
(5, 'Alice In Chains');

-- Insert data into Album table
INSERT INTO Album (AlbumId, Title, ArtistId) VALUES
(1, 'For Those About To Rock We Salute You', 1),
(2, 'Balls to the Wall', 2),
(3, 'Restless and Wild', 2),
(4, 'Let There Be Rock', 1),
(5, 'Big Ones', 3);

-- Insert data into Genre table
INSERT INTO Genre (GenreId, Name) VALUES
(1, 'Rock'),
(2, 'Jazz'),
(3, 'Metal'),
(4, 'Alternative & Punk'),
(5, 'Rock And Roll');

-- Insert data into Track table
INSERT INTO Track (TrackId, Name, AlbumId, MediaTypeId, GenreId, Composer, Milliseconds, Bytes, UnitPrice) VALUES
(1, 'For Those About To Rock (We Salute You)', 1, 1, 1, 'Angus Young, Malcolm Young, Brian Johnson', 343719, 11170334, 0.99),
(2, 'Balls to the Wall', 2, 2, 1, 'U. Dirkschneider', 342562, 5510424, 0.99),
(3, 'Fast As a Shark', 3, 2, 1, 'F. Baltes, S. Kaufman', 230619, 3990994, 0.99),
(4, 'Restless and Wild', 3, 2, 1, 'F. Baltes, R.A. Smith-Diesel', 252051, 4331779, 0.99),
(5, 'Princess of the Dawn', 3, 2, 1, 'Deaffy & R.A. Smith-Diesel', 375418, 6290521, 0.99);
```

### Verify Persistence Works

Now let's test that our data persists through a cluster restart:

Query the data to ensure it's there:

```sql
SELECT a.Name as Artist, al.Title as Album, t.Name as Track
FROM Track t
JOIN Album al ON t.AlbumId = al.AlbumId
JOIN Artist a ON al.ArtistId = a.ArtistId
WHERE t.AlbumId = 1;
```

Exit the SQL CLI and restart the containers:

```bash
exit
docker-compose down
docker-compose up -d
```

Reconnect to the CLI to the cluster and enter the `sql-cli` again and run the same query:

```sql
SELECT a.Name as Artist, al.Title as Album, t.Name as Track
FROM Track t
JOIN Album al ON t.AlbumId = al.AlbumId
JOIN Artist a ON al.ArtistId = a.ArtistId
WHERE t.AlbumId = 1;
```

The data should still be present, demonstrating that our persistent storage is working correctly.

## Wrap Up

Apache Ignite 3 with RocksDB persistent storage provides a powerful way to maintain data durability while leveraging in-memory computing performance. RocksDB is particularly well-suited for write-intensive workloads, making it an excellent choice for many production environments.

This guide demonstrated how to:

- Configure RocksDB persistence for a Docker-based Ignite cluster
- Create and use RocksDB storage profiles
- Set up distribution zones with RocksDB persistence enabled
- Create Chinook database tables with RocksDB persistence
- Test persistence through cluster restarts and node failures
- Explore RocksDB-specific features through SQL CLI

RocksDB's LSM-tree architecture makes it particularly effective for applications with high write throughput requirements, while still providing good read performance. By correctly configuring storage profiles and distribution zones, you can balance performance and persistence requirements for your specific use case.

For more advanced configurations and optimizations, refer to the Apache Ignite 3 documentation.
