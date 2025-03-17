# Your First Ignite App with Java: Public Transit Monitoring System

## Introduction

In this hands-on tutorial, you'll build a real-time transit monitoring system that showcases Ignite's powerful distributed data capabilities. By the end of this 40-minute tutorial, you'll have a functional application that:

- Connects to live transit data feeds using industry-standard formats
- Stores and queries vehicle positions in near real-time
- Monitors service disruptions using continuous queries
- Displays a simple dashboard showing transit statistics

This project is a practical demonstration of how Apache Ignite 3 can be used for real-time data processing applications. Transit data is ideal for this demonstration as it combines structured data, time-series elements, and geospatial components - all while providing a tangible, real-world use case.

### What You'll Learn

- How to ingest real-time data streams into Ignite 3
- Working with Ignite's SQL capabilities for querying time-series data
- Using continuous queries to monitor for specific conditions
- Building a simple monitoring dashboard

### Prerequisites

Before starting this tutorial, ensure you have:

- Java 11 or later installed
- Maven or Gradle for dependency management
- Completed the "Use the Java API" How-To guide
- A running Ignite 3 node (even a single node is sufficient) cluster in Docker

Let's get started with building our transit monitoring system!
