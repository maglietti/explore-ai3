# Explore Apache Ignite 3 with SQL

## Introduction

This project establishes a three-node Apache Ignite cluster for exploring and working with the [Chinook Database](https://github.com/lerocha/chinook-database/tree/master). You'll learn how to set up and manage a distributed data grid with Apache Ignite 3, execute SQL queries, and leverage advanced features like data partitioning and replication.

## Features

- **Distributed Data Grid**: Run a three-node Apache Ignite cluster using Docker
- **Data Partitioning**: Explore Ignite's data partitioning with the Chinook schema
- **Replication Zones**: Understand and utilize Ignite's replication capabilities
- **SQL Query Interface**: Execute complex SQL queries against distributed data
- **Monitoring**: Connect to GridGain ControlCenter for visual monitoring (optional)

## Requirements

To use this repository, you need:

- Docker and Docker Compose installed on your host system
- A suitable code editor (VS Code recommended)
- 12GB+ of available RAM for running the containers
- A GridGain [ControlCenter](https://portal.gridgain.com) account (optional, for monitoring)

## Quick Start

### Starting the Cluster

1. Clone this repository to your local machine
2. Start the cluster with the following command:

```shell
docker compose --profile cloud-connector up -d && docker compose logs -f
```

3. Start an interactive CLI container to connect to the cluster:

```shell
docker run --rm -it --network=ignite3_default -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 -v ./config/:/opt/ignite/downloads/ apacheignite/ignite:3.0.0 cli
```

### Connecting to the Cluster

Within the CLI, connect to the cluster:

```shell
connect http://node1:10300
```

### Verifying Cluster Topology

Check that all three nodes are running correctly:

```shell
cluster topology physical
```

You should see a table listing all three nodes (node1, node2, node3).

### Initializing the Cluster

Initialize the cluster with:

```shell
cluster init --name=ignite3 --metastorage-group=node1,node2,node3
```

Verify the cluster status:

```shell
cluster status
```

### Loading the Chinook Database

Populate the cluster with the Chinook dataset:

```shell
sql --file=/opt/ignite/downloads/Chinook_Ignite3.sql
```

## Working with Data

### Exploring Tables and Schema

Enter SQL mode in the CLI:

```shell
sql
```

List all tables in the database:

```sql
select * from system.tables;
```

View zone configuration:

```sql
select * from system.zones;
```

Examine the schema of a specific table:

```sql
select * from system.table_columns where TABLE_NAME = 'EMPLOYEE';
```

### Sample Queries

Verify that invoice totals match the sum of invoice lines:

```sql
SELECT
    Invoice.InvoiceId,
    SUM(InvoiceLine.UnitPrice * InvoiceLine.Quantity) AS CalculatedTotal,
    Invoice.Total AS Total
FROM
    InvoiceLine
    INNER JOIN Invoice ON InvoiceLine.InvoiceId = Invoice.InvoiceId
GROUP BY
    Invoice.InvoiceId,
    Invoice.Total
LIMIT 10;
```

Find the top twenty longest tracks:

```sql
SELECT
    trackid,
    name,
    MAX(milliseconds / (1000 * 60)) as duration
FROM
    track
WHERE
    genreId < 17
GROUP BY
    trackid,
    name
ORDER BY
    duration DESC
LIMIT 20;
```

## Monitoring with GridGain Control Center

For visual monitoring of your cluster:

1. Configure portal credentials (refer to GridGain documentation)
2. Open the GridGain Nebula [portal](https://portal.gridgain.com/)
3. Verify that all nodes are running and view cluster metrics
4. Use the Queries tab to monitor SQL execution

## Advanced Features

### Understanding Zone Configuration

The Chinook database utilizes two custom zones:

- **CHINOOK**: Standard zone with 2 replicas for most tables
- **CHINOOKREPLICATED**: Special zone with 3 replicas for frequently accessed reference data (Genre, MediaType)

### Colocation Keys

Tables are colocated to optimize join performance:

- Album is colocated by ArtistId
- InvoiceLine is colocated by InvoiceId
- Track is colocated by AlbumId
- Invoice is colocated by CustomerId

## Shutting Down

1. Exit the SQL CLI and CLI container:

```sql
sql-cli> exit;
[node1]> exit
```

2. Shut down the cluster:

```shell
docker compose --profile cloud-connector down
```

## Additional Resources

- [Apache Ignite Documentation](https://ignite.apache.org/docs/ignite3/latest/)
- [Chinook Database GitHub Repository](https://github.com/lerocha/chinook-database)
- [SQL System Views Reference](https://ignite.apache.org/docs/ignite3/latest/developers-guide/sql/system-views)
- [GridGain Control Center Documentation](https://docs.gridgain.com/docs/control-center-overview)

## License

This project is distributed under the same license as the Chinook database: [License](https://github.com/lerocha/Chinook-database/blob/master/LICENSE.md)
