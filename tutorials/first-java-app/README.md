# Your First Ignite App with Java: Public Transit Monitoring System

## Overview

This guide walks you through building a real-time transit monitoring system using Apache Ignite 3. By the end, you'll have a functioning application that ingests live transit data, stores it in Ignite, and provides both query capabilities and continuous monitoring for service disruptions.

The tutorial is designed to be completed in approximately 40 minutes and includes complete, working code examples that you can copy and adapt.

## What You'll Learn

- Setting up a local Ignite 3 cluster using Docker
- Designing a schema for transit data using Ignite's Catalog API
- Ingesting real-time GTFS transit data into your Ignite cluster
- Writing SQL queries to analyze vehicle positions and monitor service status
- Building a simple monitoring dashboard for your transit data

Let's begin with the [Introduction](01-introduction.md).

## Table of Contents

1. **[Introduction](01-introduction.md)**  
   Introduces the transit monitoring system project, explaining its purpose, components, and learning objectives. This module establishes the foundation for understanding how Apache Ignite 3 can power real-time data applications and outlines the prerequisites for completing the tutorial.

2. **[Project Setup and Configuration](02-project-setup.md)**  
   Guides you through creating the project structure, configuring dependencies, and establishing a connection to an Apache Ignite 3 cluster running in Docker. This module ensures your development environment is properly configured before implementing the core functionality.

3. **[Understanding GTFS Data and Creating the Transit Schema](03-understanding-gtfs.md)**  
   Explores the General Transit Feed Specification (GTFS) format, which serves as the data source for our application. This module demonstrates how to model transit data in Java and create an appropriate schema in Ignite for storing vehicle positions.

4. **[Building and Testing the GTFS Client](04-gtfs-client.md)**  
   Implements a client that communicates with GTFS-realtime feeds to fetch transit vehicle positions. This module shows how to parse external data formats and prepare them for storage in Ignite, with thorough testing to ensure reliability.

5. **[Building the Data Ingestion Service](05-data-ingestion.md)**  
   Creates a robust service that periodically fetches transit data and efficiently stores it in Apache Ignite. This module demonstrates how to implement scheduled tasks, batch processing, and proper error handling for resilient data pipelines.

6. **[Exploring Transit Data with Apache Ignite SQL](06-implementing-queries.md)**  
   Showcases Ignite's powerful SQL capabilities through practical queries that extract actionable insights from transit data. This module presents patterns for finding vehicles on specific routes, locating nearest vehicles, and analyzing route coverage.

7. **[Adding a Service Monitor](07-continuous-query.md)**  
   Implements a monitoring service that detects potential transit service disruptions by identifying vehicles stopped for extended periods. This module demonstrates how to use SQL-based polling to enable real-time operational insights.

8. **[Putting It All Together](08-putting-together.md)**  
   Orchestrates all the components into a cohesive application with a main class and console dashboard. This module also explores how to test and verify the system is working correctly with Ignite SQL, providing useful troubleshooting guidance.

## Prerequisites

- Java 11 or later
- Maven (version 3.6+) or Gradle
- Docker and Docker Compose
- Basic familiarity with SQL
- A free API key from a GTFS provider (instructions included)

This tutorial is ideal for:

- Staff engineers building large-scale distributed systems
- Technical product owners evaluating data technologies
- Solution architects designing high-performance data infrastructure
- Project team leads exploring Apache Ignite for enterprise adoption

Ready to get started? Begin with the [Introduction](01-introduction.md).
