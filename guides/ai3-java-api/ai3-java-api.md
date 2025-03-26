# Getting Started with Apache Ignite 3 Using Java API

This guide walks you through creating a Java application that connects to an Apache Ignite 3 cluster, demonstrating key patterns for working with data using Ignite's Java API.

## Prerequisites

* JDK 17 or later
* Maven
* Docker and Docker Compose

## Setting Up Your Java Project

### Create a Maven Project

First, create a simple Maven project structure:

```
ignite3-java-demo/
├── pom.xml
├── docker-compose.yml
└── src/
    └── main/
        └── java/
            └── com/
                └── example/
                    └── Main.java
```

### Configure Maven Dependencies

Edit your `pom.xml` file to include the Ignite client dependency:

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

## Setting Up an Ignite 3 Cluster

Create a Docker Compose file to run a three-node Ignite cluster:

```yaml
# docker-compose.yml
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
      - "10300:10300"  # REST API port
      - "10800:10800"  # Client port
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

### Starting and Initializing the Cluster

1. Start the cluster:

   ```bash
   docker compose up -d
   ```

2. Run the Ignite CLI and initialize the cluster:

   ```bash
   docker run --rm -it --network=host apacheignite/ignite:3.0.0 cli
   ```

3. Inside the CLI, connect to the cluster:

   ```bash
   connect http://localhost:10300
   ```

4. Initialize the cluster:

   ```bash
   cluster init --name=ignite3 --metastorage-group=node1,node2,node3
   ```

5. Create a test table:

   ```bash
   sql
   CREATE TABLE Person (id INT PRIMARY KEY, name VARCHAR);
   INSERT INTO Person (id, name) VALUES (1, 'John');
   exit;
   ```

## Building Your Java Application

Now, let's create a Java application that connects to our Ignite cluster and performs various data operations.

### Main Application Class

Create a `Main.java` file with the following code:

```java
package com.example;

import org.apache.ignite.catalog.ColumnType;
import org.apache.ignite.catalog.definitions.ColumnDefinition;
import org.apache.ignite.catalog.definitions.TableDefinition;
import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.table.KeyValueView;
import org.apache.ignite.table.RecordView;
import org.apache.ignite.table.Table;
import org.apache.ignite.table.Tuple;

/**
 * This example demonstrates connecting to an Apache Ignite 3 cluster
 * and working with data using different table view patterns.
 */
public class Main {
    public static void main(String[] args) {
        // Create an array of connection addresses for fault tolerance
        String[] addresses = {
                "localhost:10800",
                "localhost:10801",
                "localhost:10802"
        };
        
        // Connect to the Ignite cluster using the client builder pattern
        try (IgniteClient client = IgniteClient.builder()
                .addresses(addresses)
                .build()) {
            
            System.out.println("Connected to the cluster: " + client.connections());
            
            // Demonstrate querying existing data using SQL API
            queryExistingTable(client);
            
            // Create a new table using Java API
            Table table = createTable(client);
            
            // Demonstrate different ways to interact with tables
            populateTableWithDifferentViews(table);
            
            // Query the new table using SQL API
            queryNewTable(client);
        }
    }
    
    /**
     * Queries the pre-created Person table using SQL
     */
    private static void queryExistingTable(IgniteClient client) {
        System.out.println("\n--- Querying Person table ---");
        client.sql().execute(null, "SELECT * FROM Person")
                .forEachRemaining(row -> System.out.println("Person: " + row.stringValue("name")));
    }
    
    /**
     * Creates a new table using the Java API
     */
    private static Table createTable(IgniteClient client) {
        System.out.println("\n--- Creating Person2 table ---");
        return client.catalog().createTable(
                TableDefinition.builder("Person2")
                        .ifNotExists()
                        .columns(
                                ColumnDefinition.column("ID", ColumnType.INT32),
                                ColumnDefinition.column("NAME", ColumnType.VARCHAR))
                        .primaryKey("ID")
                        .build());
    }
    
    /**
     * Demonstrates different ways to interact with tables
     */
    private static void populateTableWithDifferentViews(Table table) {
        System.out.println("\n--- Populating Person2 table using different views ---");
        
        // 1. Using RecordView with Tuples
        RecordView<Tuple> recordView = table.recordView();
        recordView.upsert(null, Tuple.create().set("id", 2).set("name", "Jane"));
        System.out.println("Added record using RecordView with Tuple");
        
        // 2. Using RecordView with POJOs
        RecordView<Person> pojoView = table.recordView(Person.class);
        pojoView.upsert(null, new Person(3, "Jack"));
        System.out.println("Added record using RecordView with POJO");
        
        // 3. Using KeyValueView with Tuples
        KeyValueView<Tuple, Tuple> keyValueView = table.keyValueView();
        keyValueView.put(null, Tuple.create().set("id", 4), Tuple.create().set("name", "Jill"));
        System.out.println("Added record using KeyValueView with Tuples");
        
        // 4. Using KeyValueView with Native Types
        KeyValueView<Integer, String> keyValuePojoView = table.keyValueView(Integer.class, String.class);
        keyValuePojoView.put(null, 5, "Joe");
        System.out.println("Added record using KeyValueView with Native Types");
    }
    
    /**
     * Queries the newly created Person2 table using SQL
     */
    private static void queryNewTable(IgniteClient client) {
        System.out.println("\n--- Querying Person2 table ---");
        client.sql().execute(null, "SELECT * FROM Person2")
                .forEachRemaining(row -> System.out.println("Person2: " + row.stringValue("name")));
    }
    
    /**
     * POJO class representing a Person
     */
    public static class Person {
        // Default constructor required for serialization
        public Person() { }
        
        public Person(Integer id, String name) {
            this.id = id;
            this.name = name;
        }
        
        Integer id;
        String name;
    }
}
```

## Running the Application

To run your application:

1. Make sure your Ignite cluster is up and running
2. Compile and run your Java application:

   ```bash
   mvn compile exec:java -Dexec.mainClass="com.example.Main"
   ```

## Expected Output

You should see output similar to this:

```text
Connected to the cluster: Connections{active=1, total=1}

--- Querying Person table ---
Person: John

--- Creating Person2 table ---

--- Populating Person2 table using different views ---
Added record using RecordView with Tuple
Added record using RecordView with POJO
Added record using KeyValueView with Tuples
Added record using KeyValueView with Native Types

--- Querying Person2 table ---
Person2: Jane
Person2: Jack
Person2: Jill
Person2: Joe
```

## Understanding Table Views in Ignite 3

Ignite 3 provides multiple view patterns for interacting with tables:

### RecordView Pattern

RecordView treats tables as a collection of records, perfect for operations that work with entire rows:

```java
// Get RecordView for Tuple objects (schema-less)
RecordView<Tuple> recordView = table.recordView();
recordView.upsert(null, Tuple.create().set("id", 2).set("name", "Jane"));

// Get RecordView for mapped POJO objects (type-safe)
RecordView<Person> pojoView = table.recordView(Person.class);
pojoView.upsert(null, new Person(3, "Jack"));
```

### KeyValueView Pattern

KeyValueView treats tables as a key-value store, ideal for simple lookups:

```java
// Get KeyValueView for Tuple objects
KeyValueView<Tuple, Tuple> keyValueView = table.keyValueView();
keyValueView.put(null, Tuple.create().set("id", 4), Tuple.create().set("name", "Jill"));

// Get KeyValueView for native Java types
KeyValueView<Integer, String> keyValuePojoView = table.keyValueView(Integer.class, String.class);
keyValuePojoView.put(null, 5, "Joe");
```

## Cleaning Up

To stop your Ignite cluster when you're done:

```bash
docker compose down
```

## Troubleshooting

If you encounter connection issues:

* Verify your Docker containers are running with `docker compose ps`
* Check if the exposed ports match those in your client configuration
* Ensure that the `localhost` interface can access the Docker container network

## Next Steps

Now that you've explored the basics of connecting to Ignite and interacting with data:

* Try implementing transactions
* Experiment with more complex schemas and data types
* Explore data partitioning strategies
* Investigate Ignite's distributed computing capabilities

For more information, consult the [Apache Ignite 3 documentation](https://ignite.apache.org/docs/3.0.0/index).
