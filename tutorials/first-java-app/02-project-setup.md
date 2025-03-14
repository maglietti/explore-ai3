# Project Setup and Configuration

First, let's set up our project structure. You can either create it manually or clone our starter repository:

```text
transit-monitoring/
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── example/
│   │   │           └── transit/
│   │   │               └── ...
│   │   └── resources/
│   │       └── sample-vehicle-positions.pb
```

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

Now let's create a Docker Compose file inside our project to set up a local three-node Ignite 3 cluster:

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

### Starting the Ignite Cluster

* Open a terminal in the directory containing your `docker-compose.yml` file
* Run: `docker compose up -d && docker compose logs -f`
* Check the status with: `docker compose ps`

## Connecting to Ignite

Now let's create a class to connect to our Ignite 3 cluster. Create a file named `IgniteConnection.java`:

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.network.ClusterNode;
import java.util.List;

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
                    // Configure the addresses of Ignite server nodes
                    .addresses("127.0.0.1:10800")
                    // Set connection timeout to 10 seconds
                    .connectTimeout(10_000)
                    // Set retry policy for read operations
                    // RetryReadPolicy is the default and will retry read-only operations
                    // .retryPolicy(new RetryReadPolicy())
                    // Build the client instance
                    .build();
                
                System.out.println("Successfully connected to Ignite cluster");
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

This class implements a simple singleton pattern to maintain a single connection to the Ignite cluster throughout our application's lifecycle.

## Initializing the Cluster

Let's create a class to programmatically initialize our Ignite cluster:

```java
package com.example.transit;

import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.network.ClusterNode;

import java.util.Arrays;
import java.util.List;

/**
 * Utility class for initializing and testing an Ignite 3 cluster.
 * This class demonstrates how to connect to a cluster, initialize it,
 * and perform basic operations.
 */
public class IgniteClusterInitializer {

    public static void main(String[] args) {
        // Connect to Ignite cluster
        IgniteClient client = null;
        
        try {
            // Get client connection
            System.out.println("Connecting to Ignite cluster...");
            client = IgniteConnection.getClient();
            
            // Initialize the cluster
            initializeCluster(client);
            
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
                System.out.println("Disconnecting from Ignite cluster...");
                IgniteConnection.close();
            }
        }
    }
    
    /**
     * Initializes the Ignite cluster if it hasn't been initialized yet.
     * This method creates a new cluster with the specified name and
     * configures the metastorage group with the provided node names.
     * 
     * @param client The IgniteClient instance
     */
    private static void initializeCluster(IgniteClient client) {
        try {
            System.out.println("Initializing Ignite cluster...");
            
            // Define cluster initialization parameters
            List<String> metastorageNodes = Arrays.asList("node1", "node2", "node3");
            
            // Initialize the cluster
            client.admin().cluster().init("ignite3", metastorageNodes);
            
            System.out.println("Cluster initialized successfully");
        } catch (Exception e) {
            // If the cluster is already initialized, we'll get an exception
            if (e.getMessage().contains("already initialized")) {
                System.out.println("Cluster is already initialized");
            } else {
                System.err.println("Error initializing cluster: " + e.getMessage());
                throw e;
            }
        }
    }
    
    /**
     * Tests the connection to the Ignite cluster by retrieving and
     * displaying information about the connected cluster nodes.
     * 
     * @param client The IgniteClient instance
     */
    private static void testConnection(IgniteClient client) {
        // Get list of active connections (cluster nodes)
        List<ClusterNode> nodes = client.connections();
        
        // Print information about connected nodes
        System.out.println("Connected to " + nodes.size() + " cluster node(s):");
        for (int i = 0; i < nodes.size(); i++) {
            ClusterNode node = nodes.get(i);
            System.out.println("  Node " + (i + 1) + ": " + node.consistentId());
        }
        
        // Display client configuration information
        System.out.println("Client configuration:");
        System.out.println("  Connection timeout: " + client.configuration().connectTimeout() + "ms");
        System.out.println("  Operation timeout: " + client.configuration().operationTimeout() + "ms");
        System.out.println("  Heartbeat interval: " + client.configuration().heartbeatInterval() + "ms");
    }
}
```

This class programmatically initialize an Ignite 3 cluster and verify the connection by retrieving and displaying information about the connected nodes.

**Note:** The exact API for cluster initialization may vary based on your specific version of Ignite 3. The example above shows a simplified approach - you may need to adjust the parameters based on your cluster requirements.

You can run this application to initialize your Ignite cluster and test the connection:

```bash
mvn clean package
java -cp target/transit-monitoring-1.0.jar com.example.transit.IgniteClusterInitializer
```
