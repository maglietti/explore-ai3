# Getting Started with Apache Ignite 3 Using Java API with the Chinook Database

This guide walks you through creating a Java application that connects to an Apache Ignite 3 cluster, demonstrating how to use Ignite's Java API to work with the Chinook database - a sample database that represents a digital media store with tables for artists, albums, tracks, invoices, and customers.

## Prerequisites

* JDK 17 or later
* IntelliJ IDEA
* Docker and Docker Compose

## Setting Up Your Java Project in IntelliJ IDEA

### Create a New Java Project

* Open IntelliJ IDEA and select "New Project"
* Choose "Java" as the project type
* Select JDK 17 (or later) for your project SDK
* Name your project (e.g., "ignite3-chinook-demo")
* Click "Create"

### Configure Maven Dependencies

* Open the generated `pom.xml` file and add the following:

```xml
    <dependencies>
        <!-- Apache Ignite 3 Client -->
        <dependency>
            <groupId>org.apache.ignite</groupId>
            <artifactId>ignite-client</artifactId>
            <version>3.0.0</version>
        </dependency>
    </dependencies>
```

* Refresh Maven to download the dependencies

## Setting Up a Docker Compose File for Ignite 3

Now let's create a Docker Compose file inside our project to set up a local three-node Ignite 3 cluster:

* Create a file named `docker-compose.yml` in the root directory of your project
* Add the following content:

```yaml
# Docker Compose file for running an Apache Ignite 3 cluster.  
#  
# Usage:  
# - To start only the Ignite nodes (default behavior):  
#     docker compose up  
#  
# - To start the Ignite nodes along with the optional cloud-connector:  
#     docker compose --profile cloud-connector up  
#  
# The cloud-connector service is disabled by default and will only start if the "cloud-connector" profile is specified.  
#  
# - To start the CLI:  
#     docker run --rm -it --network=host -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 apacheignite/ignite:3.0.0 cli  
#  
# - To initialize the cluster  
#     cluster init --name=ignite3 --metastorage-group=node1,node2,node3  
#  
  
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

### Starting the Ignite Cluster

* Open a terminal in the directory containing your `docker-compose.yml` file
* Run: `docker compose up -d && docker compose logs -f`
* Check the status with: `docker compose ps`

### Initializing the Cluster and Creating the Chinook Schema

* Open a second terminal in the directory containing your `docker-compose.yml` file
* Run the Ignite CLI:

  ```bash
  docker run --rm -it --network=host -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 apacheignite/ignite:3.0.0 cli
  ```

* Connect to the default node by selecting Yes or `connect http://localhost:10300`
* Inside the CLI, initialize the cluster:

  ```shell
  cluster init --name=ignite3 --metastorage-group=node1,node2,node3
  ```

* Enter SQL cli mode by typing `sql`
* Create the Chinook database schema:

  ```sql
  -- Create Distribution Zones
  CREATE ZONE IF NOT EXISTS Chinook WITH replicas=2, storage_profiles='default';
  CREATE ZONE IF NOT EXISTS ChinookReplicated WITH replicas=3, partitions=25, storage_profiles='default';

  -- Create Tables
  CREATE TABLE Artist (
      ArtistId INT NOT NULL,
      Name VARCHAR(120),
      PRIMARY KEY (ArtistId)
  ) ZONE Chinook;

  CREATE TABLE Album (
      AlbumId INT NOT NULL,
      Title VARCHAR(160) NOT NULL,
      ArtistId INT NOT NULL,
      PRIMARY KEY (AlbumId, ArtistId)
  ) COLOCATE BY (ArtistId) ZONE Chinook;

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

  -- Insert some sample data
  INSERT INTO Artist (ArtistId, Name) VALUES
      (1, 'AC/DC'),
      (2, 'Accept'),
      (3, 'Aerosmith'),
      (4, 'Alanis Morissette'),
      (5, 'Alice In Chains');

  INSERT INTO Album (AlbumId, Title, ArtistId) VALUES
      (1, 'For Those About To Rock We Salute You', 1),
      (2, 'Balls to the Wall', 2),
      (3, 'Restless and Wild', 2),
      (4, 'Let There Be Rock', 1),
      (5, 'Big Ones', 3);

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

  INSERT INTO Track (TrackId, Name, AlbumId, MediaTypeId, GenreId, Composer, Milliseconds, Bytes, UnitPrice) VALUES
      (1, 'For Those About To Rock (We Salute You)', 1, 1, 1, 'Angus Young, Malcolm Young, Brian Johnson', 343719, 11170334, 0.99),
      (2, 'Balls to the Wall', 2, 2, 1, 'U. Dirkschneider, W. Hoffmann, H. Frank, P. Baltes, S. Kaufmann, G. Hoffmann', 342562, 5510424, 0.99),
      (3, 'Fast As a Shark', 3, 2, 1, 'F. Baltes, S. Kaufman, U. Dirkscneider & W. Hoffman', 230619, 3990994, 0.99),
      (4, 'Restless and Wild', 3, 2, 1, 'F. Baltes, R.A. Smith-Diesel, S. Kaufman, U. Dirkscneider & W. Hoffman', 252051, 4331779, 0.99),
      (5, 'Princess of the Dawn', 3, 2, 1, 'Deaffy & R.A. Smith-Diesel', 375418, 6290521, 0.99);
  ```
  
* Exit SQL cli mode by typing `exit;`

## Building Your Main Application Class

Now let's create the Main class to interact with our Chinook database. We'll build the application step by step, explaining each piece along the way.

### Create the Main Class

* Right-click on the `src/main/java` directory
* Select "New" > "Package" and name it `org.example`
* Right-click on the new package and select "New" > "Java Class"
* Name the class "Main"

### Setting Up the Basic Structure

Start with a basic Main class structure:

```java
package org.example;

public class Main {
    public static void main(String[] args) {
        // We'll add our code here
    }
}
```

### Establishing a Connection to the Ignite Cluster

Let's begin by connecting to our Ignite cluster:

> Note: The class imports are included for clarity. Use your IDE to import classes as they are needed.

```java
import org.apache.ignite.client.IgniteClient;

// Inside main method
IgniteClient client = IgniteClient.builder()
        .addresses("localhost:10800", "localhost:10801", "localhost:10802")
        .build();

System.out.println("Connected to the cluster: " + client.connections());
```

This code creates an Ignite client that connects to the three nodes we set up with Docker. Here's what it does:

* `IgniteClient.builder()` - Creates a builder for the Ignite client configuration
* `.addresses("localhost:10800", "localhost:10801", "localhost:10802")` - Specifies the addresses and ports of the Ignite nodes to connect to
* `.build()` - Builds the client with the specified configuration

The ports (10800, 10801, 10802) match the ports we exposed in our Docker Compose file. The client uses these to establish connections to the Ignite cluster nodes.

### Querying the Artist Table

Now let's query the "Artist" table we created during the cluster setup:

```java
System.out.println("\n--- Artists ---");
client.sql().execute(null, "SELECT * FROM Artist")
        .forEachRemaining(row -> 
            System.out.println("Artist ID: " + row.intValue("ArtistId") + 
                               ", Name: " + row.stringValue("Name")));
```

Let's understand what this code does:

* `client.sql()` - Gets the SQL interface of the client
* `.execute(null, "SELECT * FROM Artist")` - Executes a SQL query against the cluster
  * The first parameter (`null`) is for transactions - we're not using one here
  * The second parameter is the SQL query string
* `.forEachRemaining(row -> ...)` - Processes each row in the result set
  * `row.intValue("ArtistId")` - Gets the integer value of the "ArtistId" column
  * `row.stringValue("Name")` - Gets the string value of the "Name" column

This code will print out all artists in the table along with their IDs.

### Adding a New Artist Using SQL

Let's add a new artist to the database using SQL:

```java
System.out.println("\n--- Adding new artist via SQL ---");
client.sql().execute(null, "INSERT INTO Artist (ArtistId, Name) VALUES (6, 'Queen')");
System.out.println("Added artist: Queen");

// Verify the new artist was added
client.sql().execute(null, "SELECT * FROM Artist WHERE ArtistId = 6")
        .forEachRemaining(row -> 
            System.out.println("New artist added - ID: " + row.intValue("ArtistId") + 
                               ", Name: " + row.stringValue("Name")));
```

This code:

* Executes an SQL INSERT statement to add a new artist with ID 6 and name "Queen"
* Verifies the insertion by querying for the artist with ID 6

### Creating a New Model Class for Albums

To work with albums as Java objects, let's create a POJO (Plain Old Java Object) class:

```java
public static class Album {
    public Album() { }

    public Album(Integer albumId, String title, Integer artistId) {
        this.albumId = albumId;
        this.title = title;
        this.artistId = artistId;
    }

    Integer albumId;
    String title;
    Integer artistId;
}
```

This class represents an album with three fields:

* `albumId` - The album's ID
* `title` - The album's title
* `artistId` - The ID of the artist who created the album

### Getting Access to the Album Table

Now let's get the Album table for our Java operations:

```java
import org.apache.ignite.table.Table;

// Inside main method
Table albumTable = client.tables().table("Album");
System.out.println("\nRetrieved Album table: " + albumTable.name());
```

This code:

* Uses the `tables()` method to get the table management interface
* Calls `table("Album")` to get a reference to the "Album" table

### Adding a New Album Using RecordView with a POJO

Now let's add a new album using the RecordView with our Album POJO:

```java
import org.apache.ignite.table.RecordView;

// Inside main method
System.out.println("\n--- Adding new album using RecordView with POJO ---");
RecordView<Album> albumView = albumTable.recordView(Album.class);

Album newAlbum = new Album(6, "A Night at the Opera", 6);
albumView.upsert(null, newAlbum);
System.out.println("Added album: " + newAlbum.title);
```

Here's what's happening:

* `albumTable.recordView(Album.class)` - Gets a RecordView that can work with our Album class
* `new Album(6, "A Night at the Opera", 6)` - Creates a new Album object
* `albumView.upsert(null, newAlbum)` - Inserts the album into the table
  * The first parameter (`null`) is for transactions - we're not using one here
  * The second parameter is our Album object

### Adding Another Album Using RecordView with Tuples

Let's also add an album using Tuples, which is another way to interact with the data:

```java
import org.apache.ignite.table.Tuple;

// Inside main method
System.out.println("\n--- Adding new album using RecordView with Tuples ---");
RecordView<Tuple> tupleAlbumView = albumTable.recordView();

Tuple albumTuple = Tuple.create()
        .set("AlbumId", 7)
        .set("Title", "News of the World")
        .set("ArtistId", 6);
        
tupleAlbumView.upsert(null, albumTuple);
System.out.println("Added album: " + albumTuple.stringValue("Title"));
```

This code:

* Gets a generic RecordView for the Album table
* Creates a Tuple (a generic record) with the album data
* Inserts the Tuple into the table

Tuples are useful when you don't want to create a dedicated class for your data. They're more flexible but less type-safe than POJOs.

### Querying for Albums by a Specific Artist

Now let's find all albums by our new artist:

```java
System.out.println("\n--- Finding albums by artist ---");
client.sql().execute(null, 
        "SELECT a.Title, ar.Name as ArtistName " +
        "FROM Album a JOIN Artist ar ON a.ArtistId = ar.ArtistId " +
        "WHERE ar.Name = 'Queen'")
        .forEachRemaining(row -> 
            System.out.println("Album: " + row.stringValue("Title") + 
                               " by " + row.stringValue("ArtistName")));
```

This code:

* Executes a SQL JOIN query to find all albums by the artist "Queen"
* Prints the title of each album along with the artist name

### Adding Tracks Using KeyValueView

Let's add tracks for one of our new albums:

```java
import org.apache.ignite.table.KeyValueView;
import java.math.BigDecimal;

// Inside main method
System.out.println("\n--- Adding tracks using KeyValueView ---");
Table trackTable = client.tables().table("Track");
KeyValueView<Tuple, Tuple> trackView = trackTable.keyValueView();

// Add tracks for "A Night at the Opera"
Tuple track1Key = Tuple.create().set("TrackId", 6).set("AlbumId", 6);
Tuple track1Value = Tuple.create()
        .set("Name", "Bohemian Rhapsody")
        .set("MediaTypeId", 1)
        .set("GenreId", 1)
        .set("Composer", "Freddie Mercury")
        .set("Milliseconds", 354947)
        .set("Bytes", 5733664)
        .set("UnitPrice", new BigDecimal("0.99"));
        
trackView.put(null, track1Key, track1Value);
System.out.println("Added track: " + track1Value.stringValue("Name"));

Tuple track2Key = Tuple.create().set("TrackId", 7).set("AlbumId", 6);
Tuple track2Value = Tuple.create()
        .set("Name", "You're My Best Friend")
        .set("MediaTypeId", 1)
        .set("GenreId", 1)
        .set("Composer", "John Deacon")
        .set("Milliseconds", 175733)
        .set("Bytes", 2875239)
        .set("UnitPrice", new BigDecimal("0.99"));
        
trackView.put(null, track2Key, track2Value);
System.out.println("Added track: " + track2Value.stringValue("Name"));
```

This code:

* Gets the "Track" table
* Creates a KeyValueView, which treats the table as a key-value store
* Creates keys (TrackId + AlbumId) and values (all other track attributes)
* Uses `put()` to insert the tracks into the table

KeyValueView is useful when you have a clear distinction between key and value parts of your data. In this case, the composite key is TrackId + AlbumId.

### Querying Tracks with Joins

Let's query for tracks with album and artist information:

```java
System.out.println("\n--- Querying tracks with album and artist info ---");
client.sql().execute(null, 
        "SELECT t.Name as Track, t.Composer, a.Title as Album, ar.Name as Artist " +
        "FROM Track t " +
        "JOIN Album a ON t.AlbumId = a.AlbumId " +
        "JOIN Artist ar ON a.ArtistId = ar.ArtistId " +
        "WHERE ar.Name = 'Queen'")
        .forEachRemaining(row -> 
            System.out.println("Track: " + row.stringValue("Track") + 
                               ", Composer: " + row.stringValue("Composer") +
                               ", Album: " + row.stringValue("Album") +
                               ", Artist: " + row.stringValue("Artist")));
```

This SQL query:

* Joins three tables: Track, Album, and Artist
* Filters for tracks by the artist "Queen"
* Shows how to perform complex queries with Ignite SQL

### Using a Transaction

Finally, let's use a transaction to make sure our operations are atomic:

```java
System.out.println("\n--- Using a transaction ---");
client.transactions().runInTransaction(tx -> {
    // Add a new artist
    client.sql().execute(tx, "INSERT INTO Artist (ArtistId, Name) VALUES (7, 'Pink Floyd')");

    // Add a new album for this artist
    Tuple albumTuple2 = Tuple.create()
            .set("AlbumId", 8)
            .set("Title", "The Dark Side of the Moon")
            .set("ArtistId", 7);

    tupleAlbumView.upsert(tx, albumTuple2);

    System.out.println("Transaction committed successfully");
});

// Verify the transaction results
System.out.println("\n--- Verifying transaction results ---");
client.sql().execute(null,
                "SELECT a.Title, ar.Name as ArtistName " +
                        "FROM Album a JOIN Artist ar ON a.ArtistId = ar.ArtistId " +
                        "WHERE ar.Name = 'Pink Floyd'")
        .forEachRemaining(row ->
                System.out.println("Album: " + row.stringValue("Title") +
                        " by " + row.stringValue("ArtistName")));
```

This code:

* Begins a transaction using `client.transactions().begin()`
* Performs multiple operations within the transaction:
  * Adds a new artist via SQL
  * Adds a new album via RecordView
* Commits the transaction with `tx.commit()`
* Verifies the transaction results by querying for the new data

Transactions ensure that either all operations succeed or none of them do, which helps maintain data integrity.

### Closing the Client

Always remember to close your client when you're done:

```java
client.close();
```

This releases resources and closes the connection to the cluster.

### Complete Main.java File

Here's the complete `Main.java` file that puts everything together:

```java
package org.example;

import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.table.KeyValueView;
import org.apache.ignite.table.RecordView;
import org.apache.ignite.table.Table;
import org.apache.ignite.table.Tuple;

import java.math.BigDecimal;

public class Main {
    public static void main(String[] args) {
        // Connect to the Ignite cluster
        IgniteClient client = IgniteClient.builder()
                .addresses("localhost:10800", "localhost:10801", "localhost:10802")
                .build();

        System.out.println("Connected to the cluster: " + client.connections());

        // Query artists
        System.out.println("\n--- Artists ---");
        client.sql().execute(null, "SELECT * FROM Artist")
                .forEachRemaining(row ->
                        System.out.println("Artist ID: " + row.intValue("ArtistId") +
                                ", Name: " + row.stringValue("Name")));

        // Add a new artist using SQL
        System.out.println("\n--- Adding new artist via SQL ---");
        client.sql().execute(null, "INSERT INTO Artist (ArtistId, Name) VALUES (6, 'Queen')");
        System.out.println("Added artist: Queen");

        // Verify the new artist was added
        client.sql().execute(null, "SELECT * FROM Artist WHERE ArtistId = 6")
                .forEachRemaining(row ->
                        System.out.println("New artist added - ID: " + row.intValue("ArtistId") +
                                ", Name: " + row.stringValue("Name")));

        // Get the Album table
        Table albumTable = client.tables().table("Album");
        System.out.println("\nRetrieved Album table: " + albumTable.name());

        // Add a new album using RecordView with POJO
        System.out.println("\n--- Adding new album using RecordView with POJO ---");
        RecordView<Album> albumView = albumTable.recordView(Album.class);

        Album newAlbum = new Album(6, "A Night at the Opera", 6);
        albumView.upsert(null, newAlbum);
        System.out.println("Added album: " + newAlbum.title);

        // Add another album using RecordView with Tuples
        System.out.println("\n--- Adding new album using RecordView with Tuples ---");
        RecordView<Tuple> tupleAlbumView = albumTable.recordView();

        Tuple albumTuple = Tuple.create()
                .set("AlbumId", 7)
                .set("Title", "News of the World")
                .set("ArtistId", 6);

        tupleAlbumView.upsert(null, albumTuple);
        System.out.println("Added album: " + albumTuple.stringValue("Title"));

        // Query for albums by Queen
        System.out.println("\n--- Finding albums by artist ---");
        client.sql().execute(null,
                        "SELECT a.Title, ar.Name as ArtistName " +
                                "FROM Album a JOIN Artist ar ON a.ArtistId = ar.ArtistId " +
                                "WHERE ar.Name = 'Queen'")
                .forEachRemaining(row ->
                        System.out.println("Album: " + row.stringValue("Title") +
                                " by " + row.stringValue("ArtistName")));

        // Add tracks using KeyValueView
        System.out.println("\n--- Adding tracks using KeyValueView ---");
        Table trackTable = client.tables().table("Track");
        KeyValueView<Tuple, Tuple> trackView = trackTable.keyValueView();

        // Add tracks for "A Night at the Opera"
        // NOTE: Using BigDecimal for UnitPrice instead of Double
        Tuple track1Key = Tuple.create().set("TrackId", 6).set("AlbumId", 6);
        Tuple track1Value = Tuple.create()
                .set("Name", "Bohemian Rhapsody")
                .set("MediaTypeId", 1)
                .set("GenreId", 1)
                .set("Composer", "Freddie Mercury")
                .set("Milliseconds", 354947)
                .set("Bytes", 5733664)
                .set("UnitPrice", new BigDecimal("0.99"));  // Changed to BigDecimal

        trackView.put(null, track1Key, track1Value);
        System.out.println("Added track: " + track1Value.stringValue("Name"));

        Tuple track2Key = Tuple.create().set("TrackId", 7).set("AlbumId", 6);
        Tuple track2Value = Tuple.create()
                .set("Name", "You're My Best Friend")
                .set("MediaTypeId", 1)
                .set("GenreId", 1)
                .set("Composer", "John Deacon")
                .set("Milliseconds", 175733)
                .set("Bytes", 2875239)
                .set("UnitPrice", new BigDecimal("0.99"));  // Changed to BigDecimal

        trackView.put(null, track2Key, track2Value);
        System.out.println("Added track: " + track2Value.stringValue("Name"));

        // Query tracks with album and artist info
        System.out.println("\n--- Querying tracks with album and artist info ---");
        client.sql().execute(null,
                        "SELECT t.Name as Track, t.Composer, a.Title as Album, ar.Name as Artist " +
                                "FROM Track t " +
                                "JOIN Album a ON t.AlbumId = a.AlbumId " +
                                "JOIN Artist ar ON a.ArtistId = ar.ArtistId " +
                                "WHERE ar.Name = 'Queen'")
                .forEachRemaining(row ->
                        System.out.println("Track: " + row.stringValue("Track") +
                                ", Composer: " + row.stringValue("Composer") +
                                ", Album: " + row.stringValue("Album") +
                                ", Artist: " + row.stringValue("Artist")));

        // Using a transaction
        System.out.println("\n--- Using a transaction ---");
        client.transactions().runInTransaction(tx -> {
            // Add a new artist
            client.sql().execute(tx, "INSERT INTO Artist (ArtistId, Name) VALUES (7, 'Pink Floyd')");

            // Add a new album for this artist
            Tuple albumTuple2 = Tuple.create()
                    .set("AlbumId", 8)
                    .set("Title", "The Dark Side of the Moon")
                    .set("ArtistId", 7);

            tupleAlbumView.upsert(tx, albumTuple2);

            System.out.println("Transaction committed successfully");
        });

        // Verify the transaction results
        System.out.println("\n--- Verifying transaction results ---");
        client.sql().execute(null,
                        "SELECT a.Title, ar.Name as ArtistName " +
                                "FROM Album a JOIN Artist ar ON a.ArtistId = ar.ArtistId " +
                                "WHERE ar.Name = 'Pink Floyd'")
                .forEachRemaining(row ->
                        System.out.println("Album: " + row.stringValue("Title") +
                                " by " + row.stringValue("ArtistName")));

        // Close the client
        client.close();
    }

    public static class Album {
        public Album() { }

        public Album(Integer albumId, String title, Integer artistId) {
            this.albumId = albumId;
            this.title = title;
            this.artistId = artistId;
        }

        Integer albumId;
        String title;
        Integer artistId;
    }
}
```

## Running Your Application

To run your application in IntelliJ IDEA:

* Make sure your Ignite cluster is running (check with `docker compose ps`)
* Click the green "Run" button next to the `main` method in your IntelliJ IDEA

If you get error messages about "Table not found" or if the connection fails, make sure:

* Your Docker containers are running properly
* You've run the SQL commands to create the Chinook database tables
* The port mapping in your docker-compose file matches what you're using in the Java code

## Stopping the Ignite Cluster

When you're done with your application, you should stop the Ignite cluster:

* Exit completely from the Ignite 3 CLI and close the terminal window
* In the terminal window that you used to launch the cluster, use Ctrl+C to exit log view
* Stop the cluster with `docker compose down`

```shell
docker compose down

[+] Running 4/4
 ✔ Container ignite3-node2-1  Removed
 ✔ Container ignite3-node1-1  Removed
 ✔ Container ignite3-node3-1  Removed
 ✔ Network ignite3_default    Removed
```

## Understanding Key Concepts

### Different Ways to Work with Tables

Ignite 3 offers several approaches to work with tables:

**SQL Approach**
The SQL approach provides a familiar way to interact with your data using standard SQL syntax. It's great for complex queries, especially when joining multiple tables.

```java
client.sql().execute(null, "SELECT * FROM Artist");
```

**RecordView Approach**
RecordView lets you work with entire records at once. You can use it with:

* POJOs (Plain Old Java Objects) - For type safety and code clarity
* Tuples - For flexibility when you don't want to create dedicated classes

```java
// With POJOs:
RecordView<Album> albumView = albumTable.recordView(Album.class);
albumView.upsert(null, new Album(6, "A Night at the Opera", 6));

// With Tuples:
RecordView<Tuple> tupleView = albumTable.recordView();
tupleView.upsert(null, Tuple.create().set("AlbumId", 7).set("Title", "News of the World"));
```

**KeyValueView Approach**
KeyValueView treats tables as key-value stores, similar to a Map. It's useful when you have a clear distinction between key and value parts of your data.

```java
KeyValueView<Tuple, Tuple> trackView = trackTable.keyValueView();
trackView.put(null, keyTuple, valueTuple);
```

### Transactions

Transactions in Ignite ensure that multiple operations either all succeed or all fail together. This maintains data consistency. Use them when:

* You need to perform multiple related operations
* You want to ensure data integrity across operations
* You need to handle concurrent access to data

```java
try (Transaction tx = client.transactions().begin(TransactionOptions.DEFAULT)) {
    // Perform multiple operations
    client.sql().execute(tx, "INSERT INTO Artist VALUES (...)");
    albumView.upsert(tx, newAlbum);
    
    // Commit when all operations are successful
    tx.commit();
}
```

### Java API vs. SQL

Ignite 3 gives you the flexibility to choose between a Java API and SQL:

* **Java API Benefits**:
  * Type safety catches errors at compile time
  * Better integration with your Java code
  * More control over how you interact with data

* **SQL Benefits**:
  * Familiar syntax for database operations
  * Often more concise for complex queries
  * Great for joining multiple tables

The best part is that you can mix and match these approaches in your application, using each where it makes the most sense.

## Expected Output

If everything is set up correctly, you should see output similar to:

```text
Connected to the cluster: Connections{active=1, total=1}

--- Artists ---
Artist ID: 1, Name: AC/DC
Artist ID: 2, Name: Accept
Artist ID: 3, Name: Aerosmith
Artist ID: 4, Name: Alanis Morissette
Artist ID: 5, Name: Alice In Chains

--- Adding new artist via SQL ---
Added artist: Queen
New artist added - ID: 6, Name: Queen

Retrieved Album table: Album

--- Adding new album using RecordView with POJO ---
Added album: A Night at the Opera

--- Adding new album using RecordView with Tuples ---
Added album: News of the World

--- Finding albums by artist ---
Album: A Night at the Opera by Queen
Album: News of the World by Queen

--- Adding tracks using KeyValueView ---
Added track: Bohemian Rhapsody
Added track: You're My Best Friend

--- Querying tracks with album and artist info ---
Track: Bohemian Rhapsody, Composer: Freddie Mercury, Album: A Night at the Opera, Artist: Queen
Track: You're My Best Friend, Composer: John Deacon, Album: A Night at the Opera, Artist: Queen

--- Using a transaction ---
Transaction committed successfully

--- Verifying transaction results ---
Album: The Dark Side of the Moon by Pink Floyd
```

## Troubleshooting

### Connection Issues

If you can't connect to the Ignite cluster, check:

* Docker containers are running (`docker compose ps`)
* Port mapping is correct in docker-compose.yml
* No firewalls blocking connections
* Your Ignite client is using the correct addresses

### Table Not Found

If you get "Table not found" errors:

* Make sure you've run all the SQL commands in the CLI to create the tables
* Check that you're using the correct table names (case sensitivity matters)
* Verify the cluster is properly initialized

### Transaction Errors

If you encounter transaction issues:

* Make sure you're passing the transaction object to all operations within the transaction
* Check that you're calling commit() or rollback() to complete the transaction
* Remember to use try-with-resources or manually close transactions

### Data Type Issues

If you get type conversion errors:

* Make sure your Java types match the SQL column types
* Check for nulls in your data
* Verify that composite keys include all required parts

## Next Steps

Now that you've built a basic Ignite application with the Chinook database, you can:

* Explore the Chinook model further by adding tables for Customers and Invoices
* Create a more complex application that simulates a digital music store
* Implement data analytics on the music catalog data
* Build a web interface to display and manage the music catalog
* Study Ignite's partitioning and distribution capabilities for scalability

### Working with Other Chinook Tables

The full Chinook database includes additional tables like Customer, Employee, Invoice, and InvoiceLine. You could extend this example by:

```java
// Creating a Customer class
public static class Customer {
    public Customer() { }
    
    public Customer(Integer customerId, String firstName, String lastName, String email) {
        this.customerId = customerId;
        this.firstName = firstName;
        this.lastName = lastName;
        this.email = email;
    }
    
    Integer customerId;
    String firstName;
    String lastName;
    String email;
}

// Using it to add and query customers
Table customerTable = client.tables().table("Customer");
RecordView<Customer> customerView = customerTable.recordView(Customer.class);
customerView.upsert(null, new Customer(1, "John", "Doe", "john.doe@example.com"));

// Query for customer purchases (if you have Invoice tables)
client.sql().execute(null, 
    "SELECT c.FirstName, c.LastName, t.Name as Track, i.InvoiceDate " +
    "FROM Customer c " +
    "JOIN Invoice i ON c.CustomerId = i.CustomerId " +
    "JOIN InvoiceLine il ON i.InvoiceId = il.InvoiceId " +
    "JOIN Track t ON il.TrackId = t.TrackId " +
    "WHERE c.LastName = 'Doe'")
    .forEachRemaining(row -> 
        System.out.println(row.stringValue("FirstName") + " " +
                          row.stringValue("LastName") + " purchased " +
                          row.stringValue("Track") + " on " +
                          row.dateValue("InvoiceDate")));
```

For more information, see:

* [Apache Ignite 3 Java API documentation](https://ignite.apache.org/releases/3.0.0/javadoc/index.html)
* [Ignite 3 SQL documentation](https://ignite.apache.org/docs/3.0.0/SQL/sql-overview)
* [Chinook Database schema documentation](https://github.com/lerocha/chinook-database)
