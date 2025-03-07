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

**Configure the Storage Engine**: Define the storage engine parameters
**Create Storage Profiles**: Define profiles that use the configured storage engines
**Assign Profiles to Distribution Zones**: Link your storage profiles to distribution zones
**Create Tables in These Zones**: Tables created in these zones will use the persistent storage

## Configuration Examples

### AIPerist Storage (Default Persistent Engine)

The AIPerist engine is the default persistent storage option with checkpointing capabilities.

```json
{
  "ignite": {
    "storage": {
      "engines": {
        "aipersist": {
          "checkpoint": {
            "checkpointDelayMillis": 100
          }
        }
      },
      "profiles": [
        {
          "name": "clock_aipersist",
          "engine": "aipersist",
          "replacementMode": "CLOCK"
        }
      ]
    }
  }
}
```

This configuration:

- Defines a storage engine called `aipersist` with a checkpoint delay of 100 milliseconds
- Creates a storage profile named `clock_aipersist` that uses the `aipersist` engine
- Configures a CLOCK replacement policy for memory management

### RocksDB Storage (Write-Optimized Persistence)

RocksDB is a persistent storage engine based on LSM tree, which performs well with high write loads.

```json
{
  "ignite": {
    "storage": {
      "profiles": [
        {
          "name": "rocks_profile",
          "engine": "rocksDb",
          "size": 2560000,
          "writeBufferSize": 67108864,
          "numShardBits": 4
        }
      ]
    }
  }
}
```

This configuration:

- Creates a storage profile named `rocks_profile` that uses the RocksDB engine
- Sets the storage size to approximately 2.5MB
- Configures a write buffer size of 64MB
- Sets up 16 shards (2^4) for the cache

### Volatile Storage (In-Memory Only)

For non-persistent in-memory storage:

```json
{
  "ignite": {
    "storage": {
      "profiles": [
        {
          "name": "aimemory",
          "engine": "aimem",
          "replacementMode": "CLOCK"
        }
      ]
    }
  }
}
```

This configuration:

- Creates a volatile storage profile that only stores data in memory
- Data in this profile will be lost when the cluster is shut down

## Using Storage Profiles with Distribution Zones

After defining storage profiles, you need to assign them to distribution zones:

```sql
CREATE ZONE RocksDBZone WITH replicas=2, storage_profiles='rocks_profile';
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

### Understanding RocksDB Storage

RocksDB is a high-performance embedded database designed for fast storage. In Ignite 3, it provides:

**LSM-Tree Structure** - Uses a Log-Structured Merge-tree for efficient writes
**Write Optimization** - Excellent for write-heavy workloads
**Compaction Process** - Automatically merges and organizes data for efficient storage
**Persistence Guarantees** - Full data durability across server restarts

Unlike checkpoint-based engines, RocksDB continuously writes data in an append-only manner, making it resilient to crashes while maintaining high write throughput.

## Data Eviction in Ignite 3

### Understanding Memory Management and Eviction

Even with persistent storage like RocksDB, Apache Ignite 3 still keeps frequently accessed data in memory for better performance. When memory resources become constrained, Ignite uses eviction policies to determine which data should be removed from memory (but not from disk).

### Eviction Basics

Eviction is primarily configured at the storage profile level. While our focus has been on RocksDB-based persistent storage, understanding eviction is important for optimizing the memory utilization of your cluster.

Based on the available documentation, eviction appears to work as follows:

**Eviction Modes**:

- `DISABLED` - No eviction occurs (default)
- `RANDOM_LRU` - Combination of random selection with least recently used algorithm
- `RANDOM_2_LRU` - Enhanced version of RANDOM_LRU that samples two entries and evicts the least recently used one
- `RANDOM` - Simple random selection of entries to evict

**Eviction Threshold**:
The default threshold is `0.9` (90%), meaning eviction starts when memory usage reaches 90% of the allocated maximum. This parameter helps prevent out-of-memory situations by proactively managing memory usage.

### Configuring Eviction with RocksDB

While the RocksDB engine is focused on persistent storage, memory management remains important. Here's how you might configure eviction with RocksDB:

```json
{
  "ignite": {
    "storage": {
      "profiles": [
        {
          "name": "rocks_with_eviction",
          "engine": "rocksDb",
          "size": 268435456,
          "writeBufferSize": 67108864,
          "numShardBits": 4,
          "evictionMode": "RANDOM_2_LRU",
          "evictionThreshold": 0.85
        }
      ]
    }
  }
}
```

This configuration:

- Creates a RocksDB storage profile with eviction enabled
- Uses the RANDOM_2_LRU algorithm for better selection of entries to evict
- Sets the eviction threshold to 85%, starting eviction earlier than the default

### Balancing Memory and Disk Operations

With RocksDB storage, there's an important interplay between:

**In-Memory Caching**: Keeping frequently accessed data in RAM for fast access
**Persistent Storage**: Maintaining all data on disk for durability
**Eviction Process**: Moving less frequently used data out of memory while preserving it on disk

The eviction policy you choose affects:

- Read performance (more aggressive eviction means more disk reads)
- Memory footprint (less aggressive eviction leads to higher memory usage)
- Overall throughput (balancing memory and disk operations)

### Monitoring Eviction

While specific monitoring tools aren't detailed in the documentation provided, you should watch for:

**Memory Usage**: Monitor the memory utilization of your Ignite nodes
**Eviction Rates**: Track how frequently data is being evicted from memory
**Cache Hit Ratios**: Measure how often requested data is found in memory vs. disk

### Best Practices (Based on Limited Information)

**Match Eviction to Workload**: For read-heavy workloads with repeated access patterns, consider RANDOM_LRU or RANDOM_2_LRU
**Tune Threshold**: Starting eviction earlier (lower threshold) provides a smoother performance profile but might increase disk reads
**Storage Engine Consideration**: Remember that RocksDB is optimized for writing - your eviction strategy should complement this strength

It's important to note that this section is based on limited information from the provided documentation. For production deployments, consulting the full Apache Ignite 3 documentation or seeking expert advice would be recommended.

## Implementing Persistence for Docker-Based Chinook Database

Now let's apply what we've learned to set up persistent storage for a Docker-based Apache Ignite 3 cluster running the Chinook database.

### Prerequisites

Docker and Docker Compose installed
Basic knowledge of SQL and Ignite 3 concepts

### Configure Docker Volumes for Persistence

First, we need to modify our Docker configuration to ensure data is persisted between container restarts:

```yaml
version: '3'
services:
  ignite-node1:
    image: apache/ignite:3.0
    container_name: ignite-node1
    volumes:
      - ./ignite-config:/opt/ignite/config
      - ignite-data1:/opt/ignite/data
    environment:
      - IGNITE_CONFIG=/opt/ignite/config/ignite.json

  ignite-node2:
    image: apache/ignite:3.0
    container_name: ignite-node2
    volumes:
      - ./ignite-config:/opt/ignite/config
      - ignite-data2:/opt/ignite/data
    environment:
      - IGNITE_CONFIG=/opt/ignite/config/ignite.json

  ignite-node3:
    image: apache/ignite:3.0
    container_name: ignite-node3
    volumes:
      - ./ignite-config:/opt/ignite/config
      - ignite-data3:/opt/ignite/data
    environment:
      - IGNITE_CONFIG=/opt/ignite/config/ignite.json

volumes:
  ignite-data1:
  ignite-data2:
  ignite-data3:
```

This configuration creates Docker volumes for persisting Ignite data and mounts the configuration directory.

### Create Ignite Configuration with RocksDB Persistence

Create an `ignite.json` file in your `./ignite-config` directory:

```json
{
  "ignite": {
    "storage": {
      "profiles": [
        {
          "name": "chinook_rocks",
          "engine": "rocksDb",
          "size": 268435456,
          "writeBufferSize": 67108864,
          "numShardBits": 4
        }
      ]
    }
  }
}
```

This configuration:

- Creates a storage profile named `chinook_rocks` that uses the RocksDB engine
- Sets the storage size to 256MB (268435456 bytes)
- Configures a write buffer size of 64MB, which helps optimize write performance
- Sets up 16 shards (2^4) for the cache to improve concurrent access

### Start the Cluster

```bash
docker-compose up -d
```

### Connect to the Cluster with SQL CLI

```bash
docker exec -it ignite-node1 /opt/ignite/bin/sql-cli.sh
```

### Create Persistent Distribution Zones

In the SQL CLI, create a distribution zone that uses our RocksDB storage profile:

```sql
CREATE ZONE ChinookRocksDB WITH replicas=2, storage_profiles='chinook_rocks';
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
JOIN Artist a ON al.ArtistId = a.ArtistId;
```

Exit the SQL CLI and restart the containers:

```bash
exit
docker-compose down
docker-compose up -d
```

Connect to the SQL CLI again and run the same query:

```bash
docker exec -it ignite-node1 /opt/ignite/bin/sql-cli.sh
```

```sql
SELECT a.Name as Artist, al.Title as Album, t.Name as Track
FROM Track t
JOIN Album al ON t.AlbumId = al.AlbumId
JOIN Artist a ON al.ArtistId = a.ArtistId;
```

The data should still be present, demonstrating that our persistent storage is working correctly.

### Taking a Node Out of Service and Bringing It Back

One of the key benefits of persistent storage in a distributed database is maintaining data availability when nodes go offline. Let's test this feature:

First, check which nodes are in the cluster:

```sql
SELECT * FROM INFORMATION_SCHEMA.NODES;
```

Now, let's take one node out of service:

```bash
# In a new terminal window, stop the second node
docker stop ignite-node2
```

Back in the SQL CLI, verify that the node is no longer in the cluster:

```sql
SELECT * FROM INFORMATION_SCHEMA.NODES;
```

Check that our data is still accessible despite the node being down:

```sql
SELECT a.Name as Artist, al.Title as Album, t.Name as Track
FROM Track t
JOIN Album al ON t.AlbumId = al.AlbumId
JOIN Artist a ON al.ArtistId = a.ArtistId;
```

You should still see all the data because we configured the distribution zone with `replicas=2`, ensuring data redundancy across nodes.

Now, let's insert some new data while the node is down:

```sql
INSERT INTO Artist (ArtistId, Name) VALUES (7, 'Nirvana');
INSERT INTO Album (AlbumId, Title, ArtistId) VALUES (7, 'Nevermind', 7);
INSERT INTO Track (TrackId, Name, AlbumId, MediaTypeId, GenreId, Composer, Milliseconds, Bytes, UnitPrice) VALUES
(6, 'Smells Like Teen Spirit', 7, 1, 1, 'Kurt Cobain', 301000, 9000000, 0.99);
```

Let's bring the node back online:

```bash
# In a new terminal window
docker start ignite-node2
```

Wait a minute for the node to rejoin the cluster, then check the nodes again:

```sql
SELECT * FROM INFORMATION_SCHEMA.NODES;
```

Verify that all the data, including the newly added records, is accessible:

```sql
SELECT a.Name as Artist, al.Title as Album, t.Name as Track
FROM Track t
JOIN Album al ON t.AlbumId = al.AlbumId
JOIN Artist a ON al.ArtistId = a.ArtistId;
```

This demonstrates how the persistent storage with replication ensures data availability and consistency even when nodes are temporarily unavailable.

### Exploring RocksDB Persistence Features

Let's explore some RocksDB persistence-related features:

**Checking RocksDB-specific Storage Profile Settings**:

```sql
SELECT * FROM INFORMATION_SCHEMA.STORAGE_PROFILES 
WHERE PROFILE_NAME = 'chinook_rocks';
```

**Testing Write Performance**:
RocksDB is optimized for write operations. Let's insert a batch of records and see the performance:

```sql
START TRANSACTION READ WRITE;

-- Insert a batch of artists
INSERT INTO Artist (ArtistId, Name) VALUES
(8, 'Metallica'),
(9, 'Queen'),
(10, 'Pink Floyd'),
(11, 'The Beatles'),
(12, 'Led Zeppelin'),
(13, 'The Rolling Stones'),
(14, 'Black Sabbath'),
(15, 'Deep Purple');

-- Insert corresponding albums
INSERT INTO Album (AlbumId, Title, ArtistId) VALUES
(8, 'Master of Puppets', 8),
(9, 'A Night at the Opera', 9),
(10, 'Dark Side of the Moon', 10),
(11, 'Abbey Road', 11),
(12, 'IV', 12),
(13, 'Sticky Fingers', 13),
(14, 'Paranoid', 14),
(15, 'Machine Head', 15);

COMMIT;
```

**RocksDB vs Other Storage Options**:

Unlike the checkpoint-based AIPerist engine, RocksDB uses a Log-Structured Merge-tree approach, which:

- Optimizes for write-heavy workloads
- Provides better write throughput
- May use more disk space due to its storage format
- Periodically compacts data to maintain efficiency

**Sample Performance Comparison Query**:

```sql
-- Measure time to insert records
-- Use this before and after your insert operations to compare
SELECT CURRENT_TIMESTAMP AS execution_time;
```

## Conclusion

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
