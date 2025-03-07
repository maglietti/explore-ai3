# Getting Started with Apache Ignite 3 Persistent Storage

## Introduction

Apache Ignite 3 provides robust persistent storage capabilities that allow your data to survive system restarts and crashes while maintaining high performance. This guide will walk you through the basics of setting up and using Ignite's persistent storage.

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

1. **Persistent Storage** - Data is stored on disk and survives cluster restarts
   - **AIPerist Engine** - Default persistent storage engine with checkpointing
   - **RocksDB Engine** - LSM-tree based persistent storage optimized for write-heavy workloads

2. **Volatile Storage** - Data is stored only in RAM and is lost on cluster shutdown
   - **AIMem Engine** - In-memory storage with no persistence

## Setting Up Persistent Storage

### Storage Profiles

In Ignite 3, persistence is configured using **storage profiles**. A storage profile defines how data is stored, cached, and managed by the storage engine.

Each storage profile has specific properties depending on the engine type, but all profiles must specify:

- **name** - A unique identifier for the profile
- **engine** - The storage engine to use

### Basic Configuration Steps

Here's how to set up persistent storage in Apache Ignite 3:

1. **Configure the Storage Engine**: Define the storage engine parameters in node configuration
2. **Create Storage Profiles**: Define profiles that use the configured storage engines
3. **Assign Profiles to Distribution Zones**: Link your storage profiles to distribution zones
4. **Create Tables in These Zones**: Tables created in these zones will use the persistent storage

## Configuration

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

This node configuration:

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

This node configuration:

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

This node configuration:

- Creates a volatile storage profile that only stores data in memory
- Data in this profile will be lost when the cluster is shut down

## Using Storage Profiles with Distribution Zones

After defining storage profiles, you need to assign them to distribution zones:

```sql
CREATE ZONE PersistentZone WITH replicas=2, storage_profiles='clock_aipersist';
CREATE ZONE InMemoryZone WITH replicas=2, storage_profiles='aimemory';
```

Then, when creating tables, specify the zone to determine the storage type:

```sql
-- This table will use persistent storage
CREATE TABLE PersistentData (
    id INT PRIMARY KEY,
    value VARCHAR
) ZONE PersistentZone;

-- This table will use in-memory storage only
CREATE TABLE VolatileData (
    id INT PRIMARY KEY,
    value VARCHAR
) ZONE InMemoryZone;
```

## Understanding Checkpointing

Checkpointing is the process of copying dirty pages (updated data) from RAM to disk. This mechanism:

- Ensures data durability in case of node failures
- Manages disk space efficiently
- Creates recovery points for the system

By default, Ignite automatically manages checkpoints, but you can configure checkpoint frequency through the `checkpointDelayMillis` parameter.

## Performance Considerations

When using persistent storage, consider the following:

1. **Memory Configuration** - Allocate enough RAM to cache frequently accessed data
2. **Disk Type** - SSDs provide better performance than HDDs for persistent storage
3. **Storage Engine Selection**:
   - Use RocksDB for write-heavy workloads
   - Use AIPerist for balanced read/write workloads
4. **Checkpoint Frequency** - Frequent checkpoints increase durability but may impact performance

## Conclusion

Apache Ignite 3 persistent storage provides a powerful way to maintain data durability while leveraging in-memory computing performance. By correctly configuring storage profiles and distribution zones, you can balance performance and persistence requirements for your specific use case.

For more advanced configurations and optimizations, refer to the Apache Ignite 3 documentation.
