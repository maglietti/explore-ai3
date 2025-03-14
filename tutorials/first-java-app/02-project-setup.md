# Project Setup and Configuration

First, let's set up our project structure. You can either create it manually or clone our starter repository:

```
transit-monitoring/
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── gridgain/
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

    <groupId>com.gridgain</groupId>
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
            <artifactId>ignite-core</artifactId>
            <version>${ignite.version}</version>
        </dependency>
        <dependency>
            <groupId>org.apache.ignite</groupId>
            <artifactId>ignite-distribution</artifactId>
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
                                    <mainClass>com.gridgain.transit.TransitMonitoringApp</mainClass>
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

## Connecting to Ignite

Instead of repeating ourselves, we'll reuse the connection logic from the previous guide. Create a class `IgniteConnection.java`:

```java
package com.gridgain.transit;

import org.apache.ignite.client.ClientConfiguration;
import org.apache.ignite.client.IgniteClient;
import org.apache.ignite.client.Ignition;

public class IgniteConnection {
    private static IgniteClient igniteClient;
    
    public static IgniteClient getClient() {
        if (igniteClient == null) {
            try {
                ClientConfiguration cfg = new ClientConfiguration()
                    .setAddresses("127.0.0.1:10800");
                igniteClient = Ignition.startClient(cfg);
            } catch (Exception e) {
                System.err.println("Failed to connect to Ignite cluster: " + e.getMessage());
                throw new RuntimeException(e);
            }
        }
        return igniteClient;
    }
}
```

This class implements a simple singleton pattern to maintain a single connection to the Ignite cluster throughout our application's lifecycle.
