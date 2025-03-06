# Getting Started with Apache Ignite 3 SQL

This guide walks you through using Apache Ignite 3's SQL capabilities via the command-line interface. You'll set up a distributed Apache Ignite cluster, create and manipulate the Chinook database (a sample database representing a digital media store), and learn to leverage Ignite's powerful SQL features.

## Prerequisites

* Docker and Docker Compose installed on your system
* Basic familiarity with SQL
* Command-line terminal access
* 8GB+ of available RAM for running the containers

## Setting Up an Apache Ignite 3 Cluster

Before we can start using SQL, we need to set up a multi-node Ignite cluster. We'll use Docker Compose to create a three-node cluster.

### Starting the Cluster

Open a terminal in the directory containing this guide and locate your `docker-compose.yml` file and start the cluster:

```bash
docker compose up -d
```

This command starts the cluster in detached mode and follows the logs. You should see startup messages from all three nodes. When they're ready, you'll see messages indicating that the servers have started successfully.

```bash
docker compose up -d 

[+] Running 4/4
 ✔ Network ignite3_default    Created
 ✔ Container ignite3-node2-1  Started 
 ✔ Container ignite3-node1-1  Started
 ✔ Container ignite3-node3-1  Started
```

Once the cluster is running, press Ctrl+C to exit the log view. You can check that all containers are running with:

```bash
docker compose ps
```

You should see all three nodes with a "running" status.

## Connecting to the Cluster Using Ignite CLI

Now we'll connect to our running cluster using Ignite's command-line interface (CLI).

### Starting the CLI

In your terminal, run:

```bash
docker run --rm -it \
  --network=ignite3_default \
  -e LANG=C.UTF-8 \
  -e LC_ALL=C.UTF-8 \
  -v ./sql/:/opt/ignite/downloads/ \
  apacheignite/ignite:3.0.0 \
  cli
```

This starts an interactive CLI container connected to the same Docker network as our cluster and mounts a volume containing the sql files for the Chinook Database. When prompted, connect to the first node by entering:

```
connect http://node1:10300
```

You should see a message that you're connected to `http://node1:10300` and possibly a note that the cluster is not initialized.

### Initializing the Cluster

Before we can use the cluster, we need to initialize it:

```
cluster init --name=ignite3 --metastorage-group=node1,node2,node3
```

You should see the message "Cluster was initialized successfully".

```bash
docker run --rm -it --network=ignite3_default -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 apacheignite/ignite:3.0.0 cli


           #              ___                         __
         ###             /   |   ____   ____ _ _____ / /_   ___
     #  #####           / /| |  / __ \ / __ `// ___// __ \ / _ \
   ###  ######         / ___ | / /_/ // /_/ // /__ / / / // ___/
  #####  #######      /_/  |_|/ .___/ \__,_/ \___//_/ /_/ \___/
  #######  ######            /_/
    ########  ####        ____               _  __           _____
   #  ########  ##       /  _/____ _ ____   (_)/ /_ ___     |__  /
  ####  #######  #       / / / __ `// __ \ / // __// _ \     /_ <
   #####  #####        _/ / / /_/ // / / // // /_ / ___/   ___/ /
     ####  ##         /___/ \__, //_/ /_//_/ \__/ \___/   /____/
       ##                  /____/

                      Apache Ignite CLI version 3.0.0


You appear to have not connected to any node yet. Do you want to connect to the default node http://localhost:10300? [Y/n] n
[disconnected]> connect http://node1:10300
Connected to http://node1:10300
The cluster is not initialized. Run cluster init command to initialize it.
[node1]> cluster init --name=ignite3 --metastorage-group=node1,node2,node3
Cluster was initialized successfully
[node1]> 
```

## Creating the Chinook Database Schema

Now that our cluster is running and initialized, we can start using SQL to create and work with data. The Chinook database represents a digital music store, with tables for artists, albums, tracks, customers, and sales.

### Entering SQL Mode

To start working with SQL, enter SQL mode in the CLI:

```
sql
```

Your prompt should change to `sql-cli>` indicating you're now in SQL mode.

```bash
[node1]> sql
sql-cli> 
```

### Creating Distribution Zones

Before we create tables, let's set up distribution zones to control how our data is distributed and replicated across the cluster:

```sql
CREATE ZONE IF NOT EXISTS Chinook WITH replicas=2, storage_profiles='default';
CREATE ZONE IF NOT EXISTS ChinookReplicated WITH replicas=3, partitions=25, storage_profiles='default';
```

These commands create two zones:

* `Chinook` - Standard zone with 2 replicas for most tables
* `ChinookReplicated` - Zone with 3 replicas for frequently accessed reference data

### Creating Core Tables

Now let's create the main tables for the Chinook database. We'll start with the Artist and Album tables:

```sql
CREATE TABLE Artist (
    ArtistId INT NOT NULL,
    Name VARCHAR(120),
    PRIMARY KEY (ArtistId)
) ZONE Chinook;

CREATE TABLE Album (
    AlbumId INT NOT NULL,
    Title VARCHAR(160) NOT NULL,
    ArtistId INT NOT NULL,
    ReleaseYear INT,
    PRIMARY KEY (AlbumId, ArtistId)
) COLOCATE BY (ArtistId) ZONE Chinook;
```

Notice the `COLOCATE BY` clause in the Album table. This ensures that albums by the same artist are stored on the same nodes, which optimizes joins and queries involving both tables.

Next, let's create the Genre and MediaType reference tables:

```sql
CREATE TABLE Genre (
    GenreId INT NOT NULL,
    Name VARCHAR(120),
    PRIMARY KEY (GenreId)
) ZONE ChinookReplicated;

CREATE TABLE MediaType (
    MediaTypeId INT NOT NULL,
    Name VARCHAR(120),
    PRIMARY KEY (MediaTypeId)
) ZONE ChinookReplicated;
```

These tables are assigned to the `ChinookReplicated` zone since they contain reference data that doesn't change often but is frequently accessed.

Now, let's create the Track table, which references the Album, Genre, and MediaType tables:

```sql
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
) COLOCATE BY (AlbumId) ZONE Chinook;
```

The Track table is colocated by AlbumId to optimize queries that join tracks with their albums.

Let's also create tables to manage customers, employees, and sales:

```sql
CREATE TABLE Employee (
    EmployeeId INT NOT NULL,
    LastName VARCHAR(20) NOT NULL,
    FirstName VARCHAR(20) NOT NULL,
    Title VARCHAR(30),
    ReportsTo INT,
    BirthDate DATE,
    HireDate DATE,
    Address VARCHAR(70),
    City VARCHAR(40),
    State VARCHAR(40),
    Country VARCHAR(40),
    PostalCode VARCHAR(10),
    Phone VARCHAR(24),
    Fax VARCHAR(24),
    Email VARCHAR(60),
    PRIMARY KEY (EmployeeId)
) ZONE Chinook;

CREATE TABLE Customer (
    CustomerId INT NOT NULL,
    FirstName VARCHAR(40) NOT NULL,
    LastName VARCHAR(20) NOT NULL,
    Company VARCHAR(80),
    Address VARCHAR(70),
    City VARCHAR(40),
    State VARCHAR(40),
    Country VARCHAR(40),
    PostalCode VARCHAR(10),
    Phone VARCHAR(24),
    Fax VARCHAR(24),
    Email VARCHAR(60) NOT NULL,
    SupportRepId INT,
    PRIMARY KEY (CustomerId)
) ZONE Chinook;

CREATE TABLE Invoice (
    InvoiceId INT NOT NULL,
    CustomerId INT NOT NULL,
    InvoiceDate DATE NOT NULL,
    BillingAddress VARCHAR(70),
    BillingCity VARCHAR(40),
    BillingState VARCHAR(40),
    BillingCountry VARCHAR(40),
    BillingPostalCode VARCHAR(10),
    Total NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (InvoiceId, CustomerId)
) COLOCATE BY (CustomerId) ZONE Chinook;

CREATE TABLE InvoiceLine (
    InvoiceLineId INT NOT NULL,
    InvoiceId INT NOT NULL,
    TrackId INT NOT NULL,
    UnitPrice NUMERIC(10,2) NOT NULL,
    Quantity INT NOT NULL,
    PRIMARY KEY (InvoiceLineId, InvoiceId)
) COLOCATE BY (InvoiceId) ZONE Chinook;
```

Finally, let's create the playlist-related tables:

```sql
CREATE TABLE Playlist (
    PlaylistId INT NOT NULL,
    Name VARCHAR(120),
    PRIMARY KEY (PlaylistId)
) ZONE Chinook;

CREATE TABLE PlaylistTrack (
    PlaylistId INT NOT NULL,
    TrackId INT NOT NULL,
    PRIMARY KEY (PlaylistId, TrackId)
) ZONE Chinook;
```

### Verifying Table Creation

Let's confirm that all our tables were created successfully:

```sql
SELECT * FROM system.tables WHERE schema = 'PUBLIC';
```

This query checks the system tables to verify that our tables exist. You should see a list of all the tables we've created.

```bash
sql-cli> SELECT * FROM system.tables WHERE schema = 'PUBLIC';
╔════════╤═══════════════╤════╤═════════════╤═══════════════════╤═════════════════╤══════════════════════╗
║ SCHEMA │ NAME          │ ID │ PK_INDEX_ID │ ZONE              │ STORAGE_PROFILE │ COLOCATION_KEY_INDEX ║
╠════════╪═══════════════╪════╪═════════════╪═══════════════════╪═════════════════╪══════════════════════╣
║ PUBLIC │ ALBUM         │ 20 │ 21          │ CHINOOK           │ default         │ ARTISTID             ║
╟────────┼───────────────┼────┼─────────────┼───────────────────┼─────────────────┼──────────────────────╢
║ PUBLIC │ GENRE         │ 22 │ 23          │ CHINOOKREPLICATED │ default         │ GENREID              ║
╟────────┼───────────────┼────┼─────────────┼───────────────────┼─────────────────┼──────────────────────╢
║ PUBLIC │ ARTIST        │ 18 │ 19          │ CHINOOK           │ default         │ ARTISTID             ║
╟────────┼───────────────┼────┼─────────────┼───────────────────┼─────────────────┼──────────────────────╢
║ PUBLIC │ TRACK         │ 26 │ 27          │ CHINOOK           │ default         │ ALBUMID              ║
╟────────┼───────────────┼────┼─────────────┼───────────────────┼─────────────────┼──────────────────────╢
║ PUBLIC │ PLAYLIST      │ 36 │ 37          │ CHINOOK           │ default         │ PLAYLISTID           ║
╟────────┼───────────────┼────┼─────────────┼───────────────────┼─────────────────┼──────────────────────╢
║ PUBLIC │ PLAYLISTTRACK │ 38 │ 39          │ CHINOOK           │ default         │ PLAYLISTID, TRACKID  ║
╟────────┼───────────────┼────┼─────────────┼───────────────────┼─────────────────┼──────────────────────╢
║ PUBLIC │ MEDIATYPE     │ 24 │ 25          │ CHINOOKREPLICATED │ default         │ MEDIATYPEID          ║
╟────────┼───────────────┼────┼─────────────┼───────────────────┼─────────────────┼──────────────────────╢
║ PUBLIC │ INVOICELINE   │ 34 │ 35          │ CHINOOK           │ default         │ INVOICEID            ║
╟────────┼───────────────┼────┼─────────────┼───────────────────┼─────────────────┼──────────────────────╢
║ PUBLIC │ EMPLOYEE      │ 28 │ 29          │ CHINOOK           │ default         │ EMPLOYEEID           ║
╟────────┼───────────────┼────┼─────────────┼───────────────────┼─────────────────┼──────────────────────╢
║ PUBLIC │ CUSTOMER      │ 30 │ 31          │ CHINOOK           │ default         │ CUSTOMERID           ║
╟────────┼───────────────┼────┼─────────────┼───────────────────┼─────────────────┼──────────────────────╢
║ PUBLIC │ INVOICE       │ 32 │ 33          │ CHINOOK           │ default         │ CUSTOMERID           ║
╚════════╧═══════════════╧════╧═════════════╧═══════════════════╧═════════════════╧══════════════════════╝
```

## Inserting Sample Data

Now that we have our tables set up, let's populate them with sample data.

### Adding Artists and Albums

Let's start by adding some artists:

```sql
INSERT INTO Artist (ArtistId, Name) VALUES
    (1, 'AC/DC'),
    (2, 'Accept'),
    (3, 'Aerosmith'),
    (4, 'Alanis Morissette'),
    (5, 'Alice In Chains');
```

Now let's add albums for these artists:

```sql
INSERT INTO Album (AlbumId, Title, ArtistId, ReleaseYear) VALUES
    (1, 'For Those About To Rock We Salute You', 1, 1981),
    (2, 'Balls to the Wall', 2, 1983),
    (3, 'Restless and Wild', 2, 1982),
    (4, 'Let There Be Rock', 1, 1977),
    (5, 'Big Ones', 3, 1994);
```

### Adding Genres and Media Types

Let's populate our reference tables:

```sql
INSERT INTO Genre (GenreId, Name) VALUES
    (1, 'Rock'),
    (2, 'Jazz'),
    (3, 'Metal'),
    (4, 'Alternative & Punk'),
    (5, 'Rock And Roll');

INSERT INTO MediaType (MediaTypeId, Name) VALUES
    (1, 'MPEG audio file'),
    (2, 'Protected AAC audio file'),
    (3, 'Protected MPEG-4 video file'),
    (4, 'Purchased AAC audio file'),
    (5, 'AAC audio file');
```

### Adding Tracks

Now let's add some tracks to our albums:

```sql
INSERT INTO Track (TrackId, Name, AlbumId, MediaTypeId, GenreId, Composer, Milliseconds, Bytes, UnitPrice) VALUES
    (1, 'For Those About To Rock (We Salute You)', 1, 1, 1, 'Angus Young, Malcolm Young, Brian Johnson', 343719, 11170334, 0.99),
    (2, 'Balls to the Wall', 2, 2, 1, 'U. Dirkschneider, W. Hoffmann, H. Frank, P. Baltes, S. Kaufmann, G. Hoffmann', 342562, 5510424, 0.99),
    (3, 'Fast As a Shark', 3, 2, 1, 'F. Baltes, S. Kaufman, U. Dirkscneider & W. Hoffman', 230619, 3990994, 0.99),
    (4, 'Restless and Wild', 3, 2, 1, 'F. Baltes, R.A. Smith-Diesel, S. Kaufman, U. Dirkscneider & W. Hoffman', 252051, 4331779, 0.99),
    (5, 'Princess of the Dawn', 3, 2, 1, 'Deaffy & R.A. Smith-Diesel', 375418, 6290521, 0.99);
```

### Adding Employees and Customers

Let's add some employee and customer data:

```sql
INSERT INTO Employee (EmployeeId, LastName, FirstName, Title, ReportsTo, BirthDate, HireDate, Address, City, State, Country, PostalCode, Phone, Fax, Email) VALUES
    (1, 'Adams', 'Andrew', 'General Manager', NULL, date '1962-02-18', date '2002-08-14', '11120 Jasper Ave NW', 'Edmonton', 'AB', 'Canada', 'T5K 2N1', '+1 (780) 428-9482', '+1 (780) 428-3457', 'andrew@chinookcorp.com'),
    (2, 'Edwards', 'Nancy', 'Sales Manager', 1, date '1958-12-08', date '2002-05-01', '825 8 Ave SW', 'Calgary', 'AB', 'Canada', 'T2P 2T3', '+1 (403) 262-3443', '+1 (403) 262-3322', 'nancy@chinookcorp.com'),
    (3, 'Peacock', 'Jane', 'Sales Support Agent', 2, date '1973-08-29', date '2002-04-01', '1111 6 Ave SW', 'Calgary', 'AB', 'Canada', 'T2P 5M5', '+1 (403) 262-3443', '+1 (403) 262-6712', 'jane@chinookcorp.com');

INSERT INTO Customer (CustomerId, FirstName, LastName, Company, Address, City, State, Country, PostalCode, Phone, Fax, Email, SupportRepId) VALUES
    (1, 'Luís', 'Gonçalves', 'Embraer - Empresa Brasileira de Aeronáutica S.A.', 'Av. Brigadeiro Faria Lima, 2170', 'São José dos Campos', 'SP', 'Brazil', '12227-000', '+55 (12) 3923-5555', '+55 (12) 3923-5566', 'luisg@embraer.com.br', 3),
    (2, 'Leonie', 'Köhler', NULL, 'Theodor-Heuss-Straße 34', 'Stuttgart', NULL, 'Germany', '70174', '+49 0711 2842222', NULL, 'leonekohler@surfeu.de', 3),
    (3, 'François', 'Tremblay', NULL, '1498 rue Bélanger', 'Montréal', 'QC', 'Canada', 'H2G 1A7', '+1 (514) 721-4711', NULL, 'ftremblay@gmail.com', 3);
```

### Adding Invoices and Invoice Lines

Finally, let's add some sales data:

```sql
INSERT INTO Invoice (InvoiceId, CustomerId, InvoiceDate, BillingAddress, BillingCity, BillingState, BillingCountry, BillingPostalCode, Total) VALUES
    (1, 2, date '2021-01-01', 'Theodor-Heuss-Straße 34', 'Stuttgart', NULL, 'Germany', '70174', 1.98),
    (2, 3, date '2021-01-02', '1498 rue Bélanger', 'Montréal', 'QC', 'Canada', 'H2G 1A7', 3.96);

INSERT INTO InvoiceLine (InvoiceLineId, InvoiceId, TrackId, UnitPrice, Quantity) VALUES
    (1, 1, 2, 0.99, 1),
    (2, 1, 4, 0.99, 1),
    (3, 2, 1, 0.99, 1),
    (4, 2, 2, 0.99, 1),
    (5, 2, 3, 0.99, 1);
```

## Querying Data in Ignite SQL

Now that we have data in our tables, let's run some SQL queries to explore the Chinook database.

### Basic Queries

Let's start with some simple SELECT queries:

```sql
-- Get all artists
SELECT * FROM Artist;

-- Get all albums for a specific artist
SELECT * FROM Album WHERE ArtistId = 2;

-- Get all tracks for a specific album
SELECT * FROM Track WHERE AlbumId = 3;
```

```bash
sql-cli> SELECT * FROM Track WHERE AlbumId = 3;
╔═════════╤══════════════════════╤═════════╤═════════════╤═════════╤════════════════════════════════════════════════════════════════════════╤══════════════╤═════════╤═══════════╗
║ TRACKID │ NAME                 │ ALBUMID │ MEDIATYPEID │ GENREID │ COMPOSER                                                               │ MILLISECONDS │ BYTES   │ UNITPRICE ║
╠═════════╪══════════════════════╪═════════╪═════════════╪═════════╪════════════════════════════════════════════════════════════════════════╪══════════════╪═════════╪═══════════╣
║ 3       │ Fast As a Shark      │ 3       │ 2           │ 1       │ F. Baltes, S. Kaufman, U. Dirkscneider & W. Hoffman                    │ 230619       │ 3990994 │ 0.99      ║
╟─────────┼──────────────────────┼─────────┼─────────────┼─────────┼────────────────────────────────────────────────────────────────────────┼──────────────┼─────────┼───────────╢
║ 5       │ Princess of the Dawn │ 3       │ 2           │ 1       │ Deaffy & R.A. Smith-Diesel                                             │ 375418       │ 6290521 │ 0.99      ║
╟─────────┼──────────────────────┼─────────┼─────────────┼─────────┼────────────────────────────────────────────────────────────────────────┼──────────────┼─────────┼───────────╢
║ 4       │ Restless and Wild    │ 3       │ 2           │ 1       │ F. Baltes, R.A. Smith-Diesel, S. Kaufman, U. Dirkscneider & W. Hoffman │ 252051       │ 4331779 │ 0.99      ║
╚═════════╧══════════════════════╧═════════╧═════════════╧═════════╧════════════════════════════════════════════════════════════════════════╧══════════════╧═════════╧═══════════╝
```

### Joins

Now let's try some more complex queries with joins:

```sql
-- Get all tracks with artist and album information
SELECT 
    t.Name AS TrackName, 
    a.Title AS AlbumTitle, 
    ar.Name AS ArtistName
FROM 
    Track t
    JOIN Album a ON t.AlbumId = a.AlbumId
    JOIN Artist ar ON a.ArtistId = ar.ArtistId;
```

This query joins the Track, Album, and Artist tables to show a complete list of tracks with their album and artist information.

```sql
-- Get all sales with customer information
SELECT 
    i.InvoiceId, 
    i.InvoiceDate, 
    c.FirstName || ' ' || c.LastName AS CustomerName,
    i.Total
FROM 
    Invoice i
    JOIN Customer c ON i.CustomerId = c.CustomerId;
```

This query joins the Invoice and Customer tables to show invoices with customer names.

### Aggregate Functions

Let's explore some aggregate functions to analyze our data:

```sql
-- Get total sales by country
SELECT 
    BillingCountry, 
    COUNT(InvoiceId) AS InvoiceCount, 
    SUM(Total) AS TotalSales
FROM 
    Invoice
GROUP BY 
    BillingCountry
ORDER BY 
    TotalSales DESC;
```

This query groups invoices by country and calculates the total sales.

```sql
-- Get track count and average length by genre
SELECT 
    g.Name AS Genre, 
    COUNT(t.TrackId) AS TrackCount, 
    AVG(t.Milliseconds / 1000) AS AvgLengthInSeconds
FROM 
    Track t
    JOIN Genre g ON t.GenreId = g.GenreId
GROUP BY 
    g.Name
ORDER BY 
    TrackCount DESC;
```

This query calculates the number of tracks and average track length for each genre.

### Using Common Table Expressions (CTEs)

Ignite SQL supports Common Table Expressions (CTEs), which allow you to define temporary result sets:

```sql
-- Find the top-selling track for each genre
WITH TrackSales AS (
    SELECT 
        t.TrackId, 
        t.Name AS TrackName, 
        g.Name AS Genre, 
        SUM(il.Quantity) AS TotalSold
    FROM 
        Track t
        JOIN Genre g ON t.GenreId = g.GenreId
        JOIN InvoiceLine il ON t.TrackId = il.TrackId
    GROUP BY 
        t.TrackId, t.Name, g.Name
)
SELECT 
    ts.Genre,
    ts.TrackName,
    ts.TotalSold
FROM 
    TrackSales ts
    JOIN (
        SELECT 
            Genre, 
            MAX(TotalSold) AS MaxSold
        FROM 
            TrackSales
        GROUP BY 
            Genre
    ) MaxSales ON ts.Genre = MaxSales.Genre AND ts.TotalSold = MaxSales.MaxSold
ORDER BY 
    ts.Genre;
```

This query uses a CTE to calculate sales for each track and then finds the top-selling track in each genre.

### Working with Window Functions

Note that Apache Ignite 3 (as of version 3.0.0) does not support window functions like `SUM() OVER()` or `RANK() OVER()`. If you attempt to use them, you'll receive an error message such as `cannot translate expression SUM($t1) OVER (ORDER BY $t0 NULLS LAST)`.

For analytics that would typically use window functions, we need to use alternative approaches:

```sql
-- Calculate running total of sales using a self-join instead of window functions
SELECT 
    i1.InvoiceDate, 
    i1.Total,
    SUM(i2.Total) AS RunningTotal
FROM 
    Invoice i1
    JOIN Invoice i2 ON i2.InvoiceDate <= i1.InvoiceDate
GROUP BY 
    i1.InvoiceId, i1.InvoiceDate, i1.Total
ORDER BY 
    i1.InvoiceDate;
```

This query achieves a running total by joining the Invoice table to itself and summing all invoices with a date less than or equal to each invoice's date.

```sql
-- Find the track count for each album and the artist's highest track count
-- (alternative to using RANK window function)
WITH AlbumTrackCounts AS (
    SELECT 
        a.AlbumId,
        a.Title AS AlbumTitle,
        ar.ArtistId,
        ar.Name AS ArtistName,
        COUNT(t.TrackId) AS TrackCount
    FROM 
        Track t
        JOIN Album a ON t.AlbumId = a.AlbumId
        JOIN Artist ar ON a.ArtistId = ar.ArtistId
    GROUP BY 
        a.AlbumId, a.Title, ar.ArtistId, ar.Name
),
ArtistMaxTracks AS (
    SELECT
        ArtistId,
        MAX(TrackCount) AS MaxTrackCount
    FROM
        AlbumTrackCounts
    GROUP BY
        ArtistId
)
SELECT 
    atc.AlbumTitle, 
    atc.ArtistName,
    atc.TrackCount,
    CASE 
        WHEN atc.TrackCount = amt.MaxTrackCount THEN 'Most Tracks' 
        ELSE '' 
    END AS AlbumRanking
FROM 
    AlbumTrackCounts atc
    JOIN ArtistMaxTracks amt ON atc.ArtistId = amt.ArtistId
ORDER BY 
    atc.ArtistName, atc.TrackCount DESC;
```

This query identifies each artist's albums with the highest track count using CTEs and self-joins instead of window functions.

## Data Manipulation in Ignite SQL

Let's explore how to modify data using SQL in Ignite.

### Inserting Data with SELECT

You can insert data based on the results of a SELECT query:

```sql
-- Insert a new artist
INSERT INTO Artist (ArtistId, Name) 
VALUES (6, 'Queen');

-- Insert a new album for this artist
INSERT INTO Album (AlbumId, Title, ArtistId, ReleaseYear)
VALUES (6, 'A Night at the Opera', 6, 1975);

-- Add tracks to the new album
INSERT INTO Track (TrackId, Name, AlbumId, MediaTypeId, GenreId, Composer, Milliseconds, Bytes, UnitPrice)
VALUES
    (6, 'Bohemian Rhapsody', 6, 1, 1, 'Freddie Mercury', 354947, 5733664, 0.99),
    (7, 'You''re My Best Friend', 6, 1, 1, 'John Deacon', 175733, 2875239, 0.99);
```

### Updating Data

Let's update some existing data:

```sql
-- Update an artist's name
UPDATE Artist
SET Name = 'Queen - The Band'
WHERE ArtistId = 6;

-- Increase the price of all tracks by 10%
UPDATE Track
SET UnitPrice = UnitPrice * 1.1;
```

### Transactions

Note that Apache Ignite 3 (as of version 3.0.0) has limited support for transactions using the Java API using a SQL Script.

## Advanced SQL Features

Let's explore some of Ignite's more advanced SQL features.

### Querying System Views

Ignite provides system views that let you inspect cluster metadata:

```sql
-- View all tables in the cluster
SELECT * FROM system.tables;

-- View all zones
SELECT * FROM system.zones;

-- View all columns for a specific table
SELECT * FROM system.table_columns WHERE TABLE_NAME = 'TRACK';

-- Check index information
SELECT * FROM system.indexes;
```

### Creating Indexes for Better Performance

Let's add some indexes to improve query performance:

```sql
-- Create an index on the Name column of the Track table
CREATE INDEX idx_track_name ON Track (Name);

-- Create a composite index on Artist and Album
CREATE INDEX idx_album_artist ON Album (ArtistId, Title);

-- Create a hash index for lookups by email
CREATE INDEX idx_customer_email ON Customer USING HASH (Email);
```

## Creating a Dashboard Using SQL

Let's create SQL queries that could be used for a music store dashboard. These queries could be saved and run periodically to generate reports.

### Monthly Sales Summary

```sql
-- Monthly sales summary for the last 12 months
SELECT 
    CAST(EXTRACT(YEAR FROM i.InvoiceDate) AS VARCHAR) || '-' || 
    CASE 
        WHEN EXTRACT(MONTH FROM i.InvoiceDate) < 10 
        THEN '0' || CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
        ELSE CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
    END AS YearMonth,
    COUNT(DISTINCT i.InvoiceId) AS InvoiceCount,
    COUNT(DISTINCT i.CustomerId) AS CustomerCount,
    SUM(i.Total) AS MonthlyRevenue,
    AVG(i.Total) AS AverageOrderValue
FROM 
    Invoice i
GROUP BY 
    EXTRACT(YEAR FROM i.InvoiceDate), EXTRACT(MONTH FROM i.InvoiceDate)
ORDER BY 
    YearMonth DESC;
```

### Top Selling Genres

```sql
-- Top selling genres by revenue
SELECT
    g.Name AS Genre,
    SUM(il.UnitPrice * il.Quantity) AS Revenue
FROM
    InvoiceLine il
    JOIN Track t ON il.TrackId = t.TrackId
    JOIN Genre g ON t.GenreId = g.GenreId
GROUP BY
    g.Name
ORDER BY
    Revenue DESC;
```

### Sales Performance by Employee

```sql
-- Sales performance by employee
SELECT 
    e.EmployeeId,
    e.FirstName || ' ' || e.LastName AS EmployeeName,
    COUNT(DISTINCT i.InvoiceId) AS TotalInvoices,
    COUNT(DISTINCT i.CustomerId) AS UniqueCustomers,
    SUM(i.Total) AS TotalSales
FROM 
    Employee e
    JOIN Customer c ON e.EmployeeId = c.SupportRepId
    JOIN Invoice i ON c.CustomerId = i.CustomerId
GROUP BY 
    e.EmployeeId, e.FirstName, e.LastName
ORDER BY 
    TotalSales DESC;
```

### Top 20 Longest Tracks with Genres

```sql
-- Top 20 longest tracks with genre information
SELECT
    t.trackid,
    t.name AS track_name,
    g.name AS genre_name,
    ROUND(t.milliseconds / (1000 * 60), 2) AS duration_minutes
FROM
    track t
    JOIN genre g ON t.genreId = g.genreId
WHERE
    t.genreId < 17
ORDER BY
    duration_minutes DESC
LIMIT
    20;
```

### Customer Purchase Patterns by Month

```sql
-- Customer purchase patterns by month
SELECT 
    c.CustomerId,
    c.FirstName || ' ' || c.LastName AS CustomerName,
    CAST(EXTRACT(YEAR FROM i.InvoiceDate) AS VARCHAR) || '-' || 
    CASE 
        WHEN EXTRACT(MONTH FROM i.InvoiceDate) < 10 
        THEN '0' || CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
        ELSE CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
    END AS YearMonth,
    COUNT(DISTINCT i.InvoiceId) AS NumberOfPurchases,
    SUM(i.Total) AS TotalSpent,
    SUM(i.Total) / COUNT(DISTINCT i.InvoiceId) AS AveragePurchaseValue
FROM 
    Customer c
    JOIN Invoice i ON c.CustomerId = i.CustomerId
GROUP BY 
    c.CustomerId, c.FirstName, c.LastName, 
    EXTRACT(YEAR FROM i.InvoiceDate), EXTRACT(MONTH FROM i.InvoiceDate)
ORDER BY 
    c.CustomerId, YearMonth;
```

## Performance Tuning with Colocated Tables

One of the key advantages of Ignite is its ability to optimize joins through data colocation. Let's explore this with our existing colocated tables.

### Verifying Colocated Queries

To see if a query benefits from colocation, you can check the execution plan:

```sql
EXPLAIN PLAN FOR
SELECT 
    il.InvoiceId,
    COUNT(il.InvoiceLineId) AS LineItemCount,
    SUM(il.UnitPrice * il.Quantity) AS InvoiceTotal,
    t.Name AS TrackName,
    a.Title AS AlbumTitle
FROM 
    InvoiceLine il
    JOIN Track t ON il.TrackId = t.TrackId
    JOIN Album a ON t.AlbumId = a.AlbumId
WHERE 
    il.InvoiceId = 1
GROUP BY 
    il.InvoiceId, t.Name, a.Title;
```

```bash
╔═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
║ PLAN                                                                                                                                                                                                                                        ║
╠═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╣
║ Project(INVOICEID=[$0], LINEITEMCOUNT=[$3], INVOICETOTAL=[$4], TRACKNAME=[$1], ALBUMTITLE=[$2]): rowcount = 1.0, cumulative cost = IgniteCost [rowCount=50.3, cpu=105.2, memory=58.136, io=2.0, network=150.0], id = 18992                  ║
║   ColocatedHashAggregate(group=[{0, 1, 2}], LINEITEMCOUNT=[COUNT()], INVOICETOTAL=[SUM($3)]): rowcount = 1.0, cumulative cost = IgniteCost [rowCount=48.3, cpu=103.2, memory=57.136, io=1.0, network=149.0], id = 18991                     ║
║     Project(INVOICEID=[$5], TRACKNAME=[$3], ALBUMTITLE=[$1], $f4=[*($7, $8)]): rowcount = 1.0, cumulative cost = IgniteCost [rowCount=47.3, cpu=102.2, memory=46.400000000000006, io=1.0, network=149.0], id = 18990                        ║
║       NestedLoopJoin(condition=[=($4, $0)], joinType=[inner]): rowcount = 1.0, cumulative cost = IgniteCost [rowCount=45.3, cpu=100.2, memory=45.400000000000006, io=0.0, network=148.0], id = 18989                                        ║
║         Exchange(distribution=[single]): rowcount = 6.0, cumulative cost = IgniteCost [rowCount=12.0, cpu=12.0, memory=0.0, io=0.0, network=48.0], id = 18983                                                                               ║
║           TableScan(table=[[PUBLIC, ALBUM]], tableId=[20], requiredColumns=[{0, 1}]): rowcount = 6.0, cumulative cost = IgniteCost [rowCount=6.0, cpu=6.0, memory=0.0, io=0.0, network=0.0], id = 18982                                     ║
║         NestedLoopJoin(condition=[=($4, $0)], joinType=[inner]): rowcount = 1.05, cumulative cost = IgniteCost [rowCount=27.0, cpu=63.0, memory=16.0, io=0.0, network=100.0], id = 18988                                                    ║
║           Exchange(distribution=[single]): rowcount = 7.0, cumulative cost = IgniteCost [rowCount=14.0, cpu=14.0, memory=0.0, io=0.0, network=84.0], id = 18985                                                                             ║
║             TableScan(table=[[PUBLIC, TRACK]], tableId=[26], requiredColumns=[{0, 1, 2}]): rowcount = 7.0, cumulative cost = IgniteCost [rowCount=7.0, cpu=7.0, memory=0.0, io=0.0, network=0.0], id = 18984                                ║
║           Exchange(distribution=[single]): rowcount = 1.0, cumulative cost = IgniteCost [rowCount=6.0, cpu=21.0, memory=0.0, io=0.0, network=16.0], id = 18987                                                                              ║
║             TableScan(table=[[PUBLIC, INVOICELINE]], tableId=[34], filters=[=($t0, 1)], requiredColumns=[{1, 2, 3, 4}]): rowcount = 1.0, cumulative cost = IgniteCost [rowCount=5.0, cpu=20.0, memory=0.0, io=0.0, network=0.0], id = 18986 ║
╚═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
```

This execution plan demonstrates how Apache Ignite processes a query involving multiple joined tables with defined colocation relationships:

#### Key Observations in the Execution Plan

**ColocatedHashAggregate Operation**: The plan uses a `ColocatedHashAggregate` operation, which indicates Ignite recognizes that portions of the aggregation can happen on colocated data before results are combined. This reduces network transfer during the GROUP BY operation.

**Exchange Operations**: Several `Exchange(distribution=[single])` operations appear in the plan, indicating data movement between nodes is still necessary. These operations are applied to:

* Album table results
* Track table results
* InvoiceLine filtered results

**NestedLoopJoin Implementation**: The plan shows two `NestedLoopJoin` operations rather than hash joins, which suggests the optimizer has determined this is more efficient for the data volumes involved.

**Filter Pushdown**: The filter `il.InvoiceId = 1` is pushed down to the TableScan operation on InvoiceLine, which is an important optimization that minimizes the data being processed.

#### Colocation Impact

While full colocation benefits aren't visible in this specific plan (possibly due to limited test data), there are aspects that show Ignite is considering colocation:

* The `ColocatedHashAggregate` operation specifically leverages colocation for the aggregation phase.
* The query execution begins with individual table scans before joining, allowing each node to work with its local data first.
* The execution metrics show relatively modest network costs, indicating some colocation benefits.

#### Optimizing for Better Colocation

To further leverage colocation benefits:

* Ensure your data volume is significant enough to make distributed optimization worthwhile.
* Design queries that filter on the colocation keys when possible.
* Consider modifying the colocation strategy if certain join patterns are very common in your workload.

In production environments with larger datasets distributed across many nodes, the performance improvements from colocation become much more significant than in test environments.

### Custom Colocation Strategies

When creating tables, we can specify colocation to optimize specific query patterns. We've already done this with our schema, but here's a reminder of the patterns used:

* Albums are colocated by ArtistId (optimizes Artist-Album joins)
* Tracks are colocated by AlbumId (optimizes Album-Track joins)
* Invoices are colocated by CustomerId (optimizes Customer-Invoice joins)
* InvoiceLines are colocated by InvoiceId (optimizes Invoice-InvoiceLine joins)

This colocation ensures that related data is stored on the same cluster nodes, minimizing network transfer during joins.

## Cleaning Up

When you're finished with the Ignite SQL CLI, you can exit by typing:

```sql
exit;
```

This will return you to the Ignite CLI. To exit the Ignite CLI, type:

```
exit
```

To stop the Ignite cluster, run the following command in your terminal:

```bash
docker compose down
```

This will stop and remove the Docker containers for your Ignite cluster.

## Advanced Topics in Ignite SQL

Now that you're familiar with the basics, let's explore some advanced features of Ignite SQL.

### Working with Distributed Joins

Ignite can perform distributed joins when data isn't colocated. For example, if you join tables that aren't colocated, Ignite will distribute the data across the network as needed. While this works, it's less efficient than colocated joins:

```sql
-- This uses a distributed join since PlaylistTrack and Track 
-- don't have a colocation relationship
SELECT 
    p.Name AS PlaylistName, 
    t.Name AS TrackName
FROM 
    Playlist p
    JOIN PlaylistTrack pt ON p.PlaylistId = pt.PlaylistId
    JOIN Track t ON pt.TrackId = t.TrackId
ORDER BY 
    p.Name, t.Name;
```

### Using Transactions for Data Consistency

Transactions are crucial for maintaining data consistency. Let's explore a more complex transaction:

```sql
-- Start a transaction
START TRANSACTION READ WRITE;

-- Add a new customer
INSERT INTO Customer (CustomerId, FirstName, LastName, Email, SupportRepId)
VALUES (4, 'John', 'Doe', 'john.doe@example.com', 3);

-- Create a new invoice for the customer
INSERT INTO Invoice (InvoiceId, CustomerId, InvoiceDate, Total)
VALUES (4, 4, CURRENT_DATE, 0.00);

-- Add items to the invoice
INSERT INTO InvoiceLine (InvoiceLineId, InvoiceId, TrackId, UnitPrice, Quantity)
VALUES
    (8, 4, 1, 0.99, 2),  -- Two copies of track 1
    (9, 4, 3, 0.99, 1);  -- One copy of track 3

-- Update the invoice total
UPDATE Invoice
SET Total = (
    SELECT SUM(UnitPrice * Quantity)
    FROM InvoiceLine
    WHERE InvoiceId = 4
)
WHERE InvoiceId = 4;

-- Commit the transaction
COMMIT;

-- Verify the results
SELECT 
    c.FirstName || ' ' || c.LastName AS CustomerName,
    i.InvoiceId,
    i.Total,
    COUNT(il.InvoiceLineId) AS ItemCount
FROM 
    Customer c
    JOIN Invoice i ON c.CustomerId = i.CustomerId
    JOIN InvoiceLine il ON i.InvoiceId = il.InvoiceId
WHERE 
    c.CustomerId = 4
GROUP BY 
    c.FirstName, c.LastName, i.InvoiceId, i.Total;
```

### Schema Modification

In a production environment, you may need to modify your schema over time. Ignite SQL supports standard DDL operations for this purpose:

```sql
-- Add a new column to the Customer table
ALTER TABLE Customer ADD COLUMN DateRegistered DATE;

-- Set a default value for new records
ALTER TABLE Customer ALTER COLUMN DateRegistered SET DEFAULT CURRENT_DATE;

-- Update existing records
UPDATE Customer
SET DateRegistered = date '2020-01-01'
WHERE DateRegistered IS NULL;

-- Drop a column we don't need
ALTER TABLE Album DROP COLUMN ReleaseYear;
```

### Creating Views

Views allow you to save complex queries as virtual tables:

```sql
-- Create a view for sales analytics
CREATE VIEW SalesByGenre AS
SELECT 
    g.Name AS Genre,
    COUNT(DISTINCT t.TrackId) AS UniqueTracksCount,
    SUM(il.Quantity) AS TotalTracksSold,
    SUM(il.Quantity * il.UnitPrice) AS TotalRevenue
FROM 
    Genre g
    JOIN Track t ON g.GenreId = t.GenreId
    JOIN InvoiceLine il ON t.TrackId = il.TrackId
GROUP BY 
    g.Name;

-- Query the view
SELECT * FROM SalesByGenre ORDER BY TotalRevenue DESC;
```

## Performance Optimization Techniques

Here are some additional techniques to optimize your Ignite SQL queries.

### Creating and Using Indexes

Indexes can significantly improve query performance. Let's create and use some additional indexes:

```sql
-- Create an index on multiple columns
CREATE INDEX idx_customer_location ON Customer (Country, State, City);

-- Create an index on invoice date for report queries
CREATE INDEX idx_invoice_date ON Invoice (InvoiceDate DESC);

-- Query using the indexes
SELECT * FROM Customer WHERE Country = 'Canada' AND State = 'QC';
SELECT * FROM Invoice WHERE InvoiceDate >= date '2021-01-01' ORDER BY InvoiceDate DESC;
```

### Analyzing Query Execution Plans

You can use the EXPLAIN statement to understand how Ignite executes your queries:

```sql
-- Get the execution plan for a complex query
EXPLAIN SELECT 
    c.FirstName || ' ' || c.LastName AS CustomerName,
    COUNT(DISTINCT i.InvoiceId) AS InvoiceCount,
    SUM(i.Total) AS TotalSpent
FROM 
    Customer c
    JOIN Invoice i ON c.CustomerId = i.CustomerId
WHERE 
    c.Country = 'Germany'
GROUP BY 
    c.FirstName, c.LastName
ORDER BY 
    TotalSpent DESC;
```

Analyze the plan for potential optimization opportunities:

1. Look for table scans that could be replaced with index scans
2. Check if joins are utilizing colocation
3. Identify parts of the query that might be expensive to compute

### Using Data Partitioning

In Ignite, data is automatically partitioned based on primary key and colocation settings. You can leverage this to optimize queries by ensuring that frequently joined tables are colocated, as we've done in our schema.

For large datasets, consider additional partitioning strategies:

* Temporal partitioning (e.g., partitioning invoices by year)
* Geographical partitioning (e.g., partitioning customers by region)

## Real-World Examples

Let's look at some real-world examples of how you might use Ignite SQL for a music store application.

### Customer Analytics

```sql
-- Find top-spending customers in the last month
SELECT 
    c.CustomerId,
    c.FirstName || ' ' || c.LastName AS CustomerName,
    COUNT(i.InvoiceId) AS PurchaseCount,
    SUM(i.Total) AS TotalSpent
FROM 
    Customer c
    JOIN Invoice i ON c.CustomerId = i.CustomerId
WHERE 
    i.InvoiceDate >= CURRENT_DATE - INTERVAL '30' DAY
GROUP BY 
    c.CustomerId, c.FirstName, c.LastName
ORDER BY 
    TotalSpent DESC
LIMIT 10;

-- Calculate customer lifetime value (CLV)
SELECT 
    c.CustomerId,
    c.FirstName || ' ' || c.LastName AS CustomerName,
    SUM(i.Total) AS LifetimeValue,
    MIN(i.InvoiceDate) AS FirstPurchaseDate,
    MAX(i.InvoiceDate) AS LastPurchaseDate,
    COUNT(i.InvoiceId) AS TotalPurchases
FROM 
    Customer c
    JOIN Invoice i ON c.CustomerId = i.CustomerId
GROUP BY 
    c.CustomerId, c.FirstName, c.LastName
ORDER BY 
    LifetimeValue DESC;
```

### Inventory Management

```sql
-- Track popularity and potential restock needs
SELECT 
    t.TrackId,
    t.Name AS TrackName,
    al.Title AS AlbumTitle,
    ar.Name AS ArtistName,
    SUM(il.Quantity) AS TotalSold,
    COUNT(DISTINCT i.InvoiceId) AS NumberOfOrders
FROM 
    Track t
    JOIN InvoiceLine il ON t.TrackId = il.TrackId
    JOIN Invoice i ON il.InvoiceId = i.InvoiceId
    JOIN Album al ON t.AlbumId = al.AlbumId
    JOIN Artist ar ON al.ArtistId = ar.ArtistId
WHERE 
    i.InvoiceDate >= CURRENT_DATE - INTERVAL '90' DAY
GROUP BY 
    t.TrackId, t.Name, al.Title, ar.Name
ORDER BY 
    TotalSold DESC;
```

### Employee Performance Tracking

```sql
-- Track sales by employee over time
SELECT 
    e.EmployeeId,
    e.FirstName || ' ' || e.LastName AS EmployeeName,
    CAST(EXTRACT(YEAR FROM i.InvoiceDate) AS VARCHAR) || '-' || 
    CASE 
        WHEN EXTRACT(MONTH FROM i.InvoiceDate) < 10 
        THEN '0' || CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
        ELSE CAST(EXTRACT(MONTH FROM i.InvoiceDate) AS VARCHAR)
    END AS YearMonth,
    COUNT(DISTINCT i.InvoiceId) AS InvoiceCount,
    COUNT(DISTINCT c.CustomerId) AS CustomerCount,
    SUM(i.Total) AS TotalSales
FROM 
    Employee e
    JOIN Customer c ON e.EmployeeId = c.SupportRepId
    JOIN Invoice i ON c.CustomerId = i.CustomerId
GROUP BY 
    e.EmployeeId, e.FirstName, e.LastName, 
    EXTRACT(YEAR FROM i.InvoiceDate), EXTRACT(MONTH FROM i.InvoiceDate)
ORDER BY 
    e.EmployeeId, YearMonth;
```

## Best Practices for Ignite SQL

To get the most out of Ignite SQL, follow these best practices:

### Schema Design

* Use appropriate colocation for tables that are frequently joined
* Choose primary keys that distribute data evenly across the cluster
* Design with query patterns in mind, especially for large-scale deployments

### Query Optimization

* Create indexes for columns used in WHERE, JOIN, and ORDER BY clauses
* Use the EXPLAIN statement to analyze and optimize your queries
* Avoid cartesian products and inefficient join conditions

### Transaction Management

* Keep transactions as short as possible
* Don't hold transactions open during user think time
* Group related operations into a single transaction for atomicity

### Resource Management

* Monitor query performance in production
* Consider partitioning strategies for very large tables
* Use appropriate data types to minimize storage requirements

## Conclusion

In this guide, you've learned how to set up an Apache Ignite 3 cluster and use SQL to create, query, and manage a distributed database. We've covered everything from basic SQL operations to advanced features like distributed joins, transactions, and performance optimization.

Apache Ignite's SQL capabilities make it a powerful platform for building distributed applications that require high throughput, low latency, and strong consistency. By following the patterns and practices in this guide, you can leverage Ignite SQL to build scalable, resilient systems.

Remember that Ignite is not just a SQL database—it's a comprehensive distributed computing platform with capabilities beyond what we've covered here. As you become more comfortable with Ignite SQL, you may want to explore other features such as compute grid, machine learning, and stream processing.

Happy querying!
