# Your First Ignite App with Java: Public Transit Monitoring System

## Introduction

In this hands-on tutorial, you'll build a real-time transit monitoring system that demonstrates Apache Ignite 3's distributed data capabilities. Through this project, you'll experience firsthand how Ignite enables rapid development of applications that require high throughput, low latency, and resilient data processing.

Transit data provides an ideal context for learning Ignite because it combines several challenging characteristics found in modern applications:

- **Real-time data streams** that must be continuously processed
- **Time-series data** requiring efficient storage and retrieval
- **Geospatial components** for tracking vehicle locations
- **Complex queries** for analyzing system performance
- **Continuous monitoring** for detecting service anomalies

By completing this tutorial, you'll have:

- A functional transit monitoring application with source code
- A running Ignite cluster with populated data
- A collection of reusable code components for working with Ignite
- Practical experience with Ignite's core features
- Knowledge to build your own distributed data applications

## What You'll Learn

Throughout this tutorial, you'll gain hands-on experience with key Apache Ignite 3 features:

### Data Modeling and Storage

- Creating tables using Ignite's Java API
- Defining appropriate schemas for time-series data
- Managing primary keys and indices for optimal performance

### Data Ingestion

- Building data pipelines with proper error handling
- Implementing efficient batch processing for high-throughput scenarios
- Using scheduled execution for continuous data updates

### Querying and Analysis

- Writing SQL queries against distributed data
- Using temporal functions for time-series analysis
- Implementing complex joins and aggregations for operational insights

### Monitoring and Alerting

- Creating monitoring systems using SQL-based polling
- Detecting anomalies in real-time data streams
- Building simple visualization components for system status

## Prerequisites

Before starting this tutorial, please ensure you have:

- **Java 11 or later** installed and properly configured
  - Verify with `java --version` in your terminal
  - JDK 17 is recommended for best compatibility
- **Maven 3.6+** for dependency management
  - Verify with `mvn --version`
- **Docker 20.10+** and Docker Compose for running the Ignite 3 cluster
  - Verify with `docker --version` and `docker-compose --version`
- **IDE** such as IntelliJ IDEA or VS Code with Java extensions
- **Basic Java knowledge**, including familiarity with classes, interfaces, and collections
- **Some SQL experience** for understanding the query examples
- **Completed the "Use the Java API" How-To guide** (recommended but not required)

## Tutorial Flow

This tutorial is designed as a progressive journey through building a complete application:

```mermaid
graph LR
    A[Project Setup] --> B[Understanding GTFS Data]
    B --> C[Schema Creation]
    C --> D[GTFS Client Implementation]
    D --> E[Data Ingestion Service]
    E --> F[SQL Querying]
    F --> G[Service Monitoring]
    G --> H[Application Integration]
```

Each module builds on the previous ones, introducing new concepts while reinforcing what you've already learned. The code examples are designed to work together as a cohesive application, but each component also illustrates standalone concepts that can be applied to other projects.

> **Next Steps:** Continue to [Module 2: Project Setup and Configuration](02-project-setup.md) to set up our project structure and configure our Ignite cluster!
