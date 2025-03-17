# Your First Ignite App with Java: Public Transit Monitoring System

## Overview

This guide walks you through building a real-time transit monitoring system using Apache Ignite 3.0. By the end, you'll have a functioning application that ingests live transit data, stores it in Ignite, and provides both query capabilities and continuous monitoring for service disruptions.

The guide is designed to be completed in approximately 40 minutes and includes complete, working code examples that you can copy and adapt.

Let's begin with the [Introduction](01-introduction.md).

## Table of Contents

1. [Introduction](01-introduction.md)
   - What we're building
   - What you'll learn
   - Prerequisites

2. [Project Setup and Configuration](02-project-setup.md)
   - Project structure
   - Maven dependencies
   - Connecting to Ignite

3. [Understanding GTFS Data](03-understanding-gtfs.md)
   - Introduction to GTFS-realtime format
   - Vehicle position data model
   - Implementing the VehiclePosition class

4. [Creating the Transit Schema](04-creating-schema.md)
   - Designing the table structure
   - Implementing the schema in Ignite
   - Understanding the primary key design

5. [Implementing the GTFS Client](05-gtfs-client.md)
   - Working with the OneBusAway library
   - Fetching live transit data
   - Implementing the fallback mechanism

6. [Testing the GTFS Connection](06-testing-gtfs.md)
   - Verifying data source connectivity
   - Analyzing sample data
   - Validating the data model

7. [Building the Data Ingestion Service](07-data-ingestion.md)
   - Creating a scheduled service
   - Storing data in Ignite
   - Error handling and retries

8. [Verifying Data in Ignite](08-data-verification.md)
   - Checking table contents
   - Examining sample records
   - Validating data integrity

9. [Implementing Basic Queries](09-implementing-queries.md)
   - Finding vehicles by route
   - Finding nearest vehicles to a location
   - Getting vehicle counts by route

10. [Adding a Continuous Query](10-continuous-query.md)
    - Monitoring for service disruptions
    - Setting up a continuous query listener
    - Alerting on detected conditions

11. [Putting It All Together](11-putting-together.md)
    - Creating the main application
    - Building a simple console dashboard
    - Running the complete system

12. [Testing with Ignite SQL](12-testing-with-ignite.md)
    - Running SQL queries against your data
    - Useful verification queries
    - Analyzing the results

13. [Conclusion and Next Steps](13-conclusion.md)
    - What you've learned
    - Ways to extend your application
    - Resources and further reading
