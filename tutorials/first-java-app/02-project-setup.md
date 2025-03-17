# Project Setup and Configuration

First, let's set up our project structure. You can either create it manually or clone our starter [repository](#).

We'll start by creating a Maven `pom.xml` file with our dependencies:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>transit-monitoring</artifactId>
    <version>1.0</version>

    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <ignite.version>3.0.0</ignite.version>
    </properties>

    <dependencies>
        <!-- Apache Ignite dependencies -->
        <dependency>
            <groupId>org.apache.ignite</groupId>
            <artifactId>ignite-client</artifactId>
            <version>${ignite.version}</version>
        </dependency>
        
        <!-- GTFS-realtime library -->
        <dependency>
            <groupId>org.onebusaway</groupId>
            <artifactId>onebusaway-gtfs-realtime-api</artifactId>
            <version>1.2.0</version>
        </dependency>
        
        <!-- Logging -->
        <dependency>
            <groupId>ch.qos.logback</groupId>
            <artifactId>logback-classic</artifactId>
            <version>1.2.11</version>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-shade-plugin</artifactId>
                <version>3.2.4</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                        <configuration>
                            <transformers>
                                <transformer implementation="org.apache.maven.plugins.shade.resource.ManifestResourceTransformer">
                                    <mainClass>com.example.transit.TransitMonitoringApp</mainClass>
                                </transformer>
                            </transformers>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
```

## Starting your Ignite cluster

Let's create a Docker Compose file inside our project to set up a local three-node Ignite 3 cluster:

* Create a file named `docker-compose.yml` in the root directory of your project
* Add the following content:

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

### Starting an Ignite 3 Cluster

* Open a terminal in the directory containing your `docker-compose.yml` file
* Run: `docker compose up -d`
* Open a second terminal in the directory containing your `docker-compose.yml` file
* Check the status with: `docker compose ps`

If everything is set up correctly, you should see three Apache Ignite containers running and exposing ports to the host network.

### Initializing the Cluster

Start the Ignite 3 CLI in Docker:

  ```bash
  docker run --rm -it --network=host -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 apacheignite/ignite:3.0.0 cli
  ```

* Connect to the default node by selecting Yes or type `connect http://localhost:10300`
* Inside the CLI, initialize the cluster:

  ```shell
  cluster init --name=ignite3 --metastorage-group=node1,node2,node3
  ```

## Connecting to Ignite

Now let's create a class to connect to our Ignite 3 cluster. Create a file named `IgniteConnection.java` in your project:

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.client.RetryReadPolicy;

/**
 * Singleton class that manages the connection to the Ignite cluster.
 * This class uses the Ignite 3 client API to establish and maintain
 * a connection to the cluster throughout our application's lifecycle.
 */
public class IgniteConnection {
    private static IgniteClient igniteClient;

    /**
     * Gets a singleton instance of IgniteClient.
     * The client connects to a local Ignite 3 cluster running on the default port.
     *
     * @return An initialized IgniteClient instance
     */
    public static synchronized IgniteClient getClient() {
        if (igniteClient == null) {
            try {
                // Using the builder pattern introduced in Ignite 3
                igniteClient = IgniteClient.builder()
                        // Configure the addresses of all three Ignite server nodes
                        // This provides redundancy and failover capabilities
                        .addresses(
                                "127.0.0.1:10800",  // Node 1
                                "127.0.0.1:10801",  // Node 2
                                "127.0.0.1:10802"   // Node 3
                        )
                        // Set connection timeout to 10 seconds
                        .connectTimeout(10_000)
                        // RetryReadPolicy allows read operations to be retried automatically on connection issues
                        .retryPolicy(new RetryReadPolicy())
                        // Build the client instance
                        .build();

                System.out.println("Successfully connected to Ignite cluster" + igniteClient.connections());
            } catch (Exception e) {
                System.err.println("Failed to connect to Ignite cluster: " + e.getMessage());
                throw new RuntimeException("Ignite connection failure", e);
            }
        }
        return igniteClient;
    }

    /**
     * Closes the connection to the Ignite cluster.
     * Call this method when shutting down your application to release resources.
     */
    public static void close() {
        if (igniteClient != null) {
            try {
                igniteClient.close();
                igniteClient = null;
                System.out.println("Ignite client connection closed");
            } catch (Exception e) {
                System.err.println("Error closing Ignite client: " + e.getMessage());
            }
        }
    }
}
```

## Testing the Connection

Now let's create a class to test our connection to the Ignite cluster:

```java
package com.example.transit;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.client.RetryLimitPolicy;
import org.apache.ignite.network.ClusterNode;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Test class for verifying connection to an Ignite 3 cluster.
 * This class demonstrates how to connect to a cluster and retrieve information.
 */
public class IgniteClusterTest {

    public static void main(String[] args) {
        // Configure logging to be quiet before any other operations
        configureLogging();

        // Connect to Ignite cluster
        IgniteClient client = null;

        try {
            // Get client connection
            System.out.println("--- Connecting to Ignite cluster...");
            client = IgniteConnection.getClient();

            // Test the connection by retrieving cluster nodes
            System.out.println("Testing connection by retrieving cluster nodes...");
            testConnection(client);

            System.out.println("Ignite cluster operations completed successfully");

        } catch (Exception e) {
            System.err.println("Error during Ignite operations: " + e.getMessage());
            e.printStackTrace();
        } finally {
            // Always properly disconnect from the cluster
            if (client != null) {
                System.out.println("--- Disconnecting from Ignite cluster...");
                IgniteConnection.close();
            }
        }
    }

    /**
     * Configure logging to completely suppress all log messages.
     */
    private static void configureLogging() {
        // Get the Logback root logger and set it to OFF
        Logger root = (Logger) LoggerFactory.getLogger(Logger.ROOT_LOGGER_NAME);
        root.setLevel(Level.OFF);

        // Specifically set Netty logger to OFF as well
        Logger nettyLogger = (Logger) LoggerFactory.getLogger("io.netty");
        nettyLogger.setLevel(Level.OFF);
    }

    /**
     * Tests the connection to the Ignite cluster and displays useful information
     *
     * @param client The IgniteClient instance
     */
    private static void testConnection(IgniteClient client) {
        System.out.println("\n========== IGNITE CLUSTER OVERVIEW ==========");

        // Get list of active connections (cluster nodes)
        List<ClusterNode> clusterNnodes = client.connections();

        // 1. Cluster Topology Information
        System.out.println("\nCLUSTER TOPOLOGY:");
        try {
            // Get complete cluster topology
            List<ClusterNode> allNodes = client.clusterNodes().stream().collect(Collectors.toList());

            System.out.println("  • Total cluster nodes: " + allNodes.size());

            // Display simple list of nodes
            for (int i = 0; i < allNodes.size(); i++) {
                ClusterNode node = allNodes.get(i);
                System.out.println("    - Node " + (i + 1) + ": " + node.name() +
                        " (ID: " + node.id() + ", Address: " + node.address() + ")");
            }

            // Also show which node(s) the client is currently connected to
            List<ClusterNode> connectedNodes = client.connections();
            System.out.println("  • Currently connected to: " +
                    (connectedNodes.isEmpty() ? "None" : connectedNodes.get(0).name()));
        } catch (Exception e) {
            System.out.println("  • Could not retrieve full cluster topology: " + e.getMessage());

            // Fall back to showing just the connected nodes
            List<ClusterNode> currentNodes = client.connections();
            System.out.println("  • Connected nodes: " + currentNodes.size());
            for (int i = 0; i < currentNodes.size(); i++) {
                ClusterNode node = currentNodes.get(i);
                System.out.println("    - Node " + (i + 1) + ": " + node.name() +
                        " (ID: " + node.id() + ", Address: " + node.address() + ")");
            }
        }

        // 2. Connection Details
        System.out.println("\nCONNECTION DETAILS:");
        System.out.println("  • Connection timeout: " + client.configuration().connectTimeout() + "ms");
        System.out.println("  • Operation timeout: " +
                (client.configuration().operationTimeout() > 0 ?
                        client.configuration().operationTimeout() + "ms" : "No timeout (unlimited)"));
        System.out.println("  • Heartbeat interval: " + client.configuration().heartbeatInterval() + "ms");

        // 3. Available Resources - Tables
        try {
            List<String> tables = client.tables().tables().stream()
                    .map(table -> table.name())
                    .collect(Collectors.toList());

            System.out.println("\nAVAILABLE TABLES:");
            if (tables.isEmpty()) {
                System.out.println("  • No tables found. Your cluster is ready for you to create tables.");
                System.out.println("  • Tip: Use client.tables().createTable(...) to create your first table.");
            } else {
                System.out.println("  • Found " + tables.size() + " table(s):");
                for (String tableName : tables) {
                    System.out.println("    - " + tableName);
                }
                System.out.println("  • Tip: Access a table with client.tables().table(\"" +
                        (tables.isEmpty() ? "table_name" : tables.get(0)) + "\")");
            }
        } catch (Exception e) {
            System.out.println("\nAVAILABLE TABLES:");
            System.out.println("  • Could not retrieve tables: " + e.getMessage());
            System.out.println("  • Tip: You may need additional permissions to view tables");
        }

        // 4. Client Retry Policy
        System.out.println("\nRETRY POLICY:");
        if (client.configuration().retryPolicy() != null) {
            System.out.println("  • Type: " + client.configuration().retryPolicy().getClass().getSimpleName());
            if (client.configuration().retryPolicy() instanceof RetryLimitPolicy) {
                RetryLimitPolicy policy = (RetryLimitPolicy) client.configuration().retryPolicy();
                System.out.println("  • Retry limit: " + policy.retryLimit());
            }
            System.out.println("  • Tip: The retry policy helps maintain connection during network issues");
        } else {
            System.out.println("  • No retry policy configured");
            System.out.println("  • Tip: Consider adding a RetryReadPolicy for better resilience");
        }

        // 5. Security Status
        System.out.println("\nSECURITY STATUS:");
        if (client.configuration().authenticator() != null) {
            System.out.println("  • Authentication: Enabled");
            System.out.println("  • Type: " + client.configuration().authenticator().type());
        } else {
            System.out.println("  • Authentication: Not configured");
        }

        if (client.configuration().ssl() != null && client.configuration().ssl().enabled()) {
            System.out.println("  • SSL/TLS: Enabled");
        } else {
            System.out.println("  • SSL/TLS: Disabled");
            System.out.println("  • Tip: Consider enabling SSL for secure communication");
        }

        System.out.println("\nCONNECTION SUCCESSFUL! You are now ready to use Ignite.");
        System.out.println("========== END OF CLUSTER OVERVIEW ==========\n");
    }
}
```

## Setting Up the Project in IntelliJ IDEA

To create this project in IntelliJ IDEA:

1. Open IntelliJ IDEA
2. Select **File > New > Project**
3. Choose **Maven** as the project type
4. Enter the group id as `com.example`, artifact id as `transit-monitoring`
5. Click **Finish**
6. Replace the contents of the generated `pom.xml` with our configuration
7. Create the package structure by right-clicking on `src/main/java` and selecting **New > Package** and entering `com.example.transit`
8. Create the Java classes in this package
9. Create the `docker-compose.yml` file in the project root

## Running the Application via Command Line

To run the application:

1. Start the Ignite cluster using Docker Compose:

   ```bash
   docker compose up -d
   ```

2. Initialize the cluster using the Ignite CLI as described [above](#initializing-the-cluster)

3. Compile and run the test application:

   ```bash
   mvn clean package
   java -cp target/transit-monitoring-1.0.jar com.example.transit.IgniteClusterTest
   ```

If everything is set up correctly, you should see output confirming a successful connection to the Ignite cluster, along with information about the connected nodes and client configuration.
