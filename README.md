# Explore Apache Ignite 3 with SQL

## Introduction

This project is my digital scratchpad for all things as I learn and develop content for Apache Ignite.  Follow along as I learn how to set up and manage a distributed data grid with Apache Ignite 3, execute SQL queries, and leverage advanced features like data partitioning and replication.

## Requirements

To use this repository, you need:

- Docker and Docker Compose installed on your host system
- A suitable code editor (VS Code recommended)
- 12GB+ of available RAM for running the containers
- A GridGain [ControlCenter](https://portal.gridgain.com) account (optional, for monitoring)

## tl;dr Quick Start

### Starting the Cluster

1. Clone this repository to your local machine
2. Start the cluster with the following command:

```shell
docker compose up -d && docker compose logs -f
```

3. Start an interactive CLI container to connect to the cluster:

```shell
docker run --rm -it --network=ignite3_default -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 -v ./chinook_db/:/opt/ignite/downloads/ apacheignite/ignite:3.0.0 cli
```

### Connecting to the Cluster

Within the CLI, connect to the cluster:

```shell
connect http://node1:10300
```

### Initializing the Cluster

Initialize the cluster with:

```shell
cluster init --name=ignite3 --metastorage-group=node1,node2,node3
```

### Loading the Chinook Database

Populate the cluster with the Chinook dataset:

```shell
sql --file=/opt/ignite/downloads/chinook-ignite3.sql
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

Optionally, you can attach GridGain Control Center (NEBULA) for visual monitoring of your cluster:

1. Configure portal credentials (export `CC_USERNAME` and `CC_PASSWORD`)
2. Run the cluster with `--profile cloud-connector`
3. Open the GridGain Nebula [portal](https://portal.gridgain.com/)
4. Verify that all nodes are running and view cluster metrics
5. Use the Queries tab to monitor SQL execution

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
