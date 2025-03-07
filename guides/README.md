# Apache Ignite 3 Guides

This directory contains tutorials and guides for working with Apache Ignite 3, a distributed database and computing platform. These guides will help you learn how to work with Ignite 3 using different APIs and approaches.

## Guide Structure

Each guide typically includes:

1. **Prerequisites** - Software requirements and setup instructions
2. **Cluster Setup** - How to create and configure an Ignite 3 cluster using Docker
3. **Core Concepts** - Explanation of key Ignite concepts relevant to the guide
4. **Hands-on Examples** - Step-by-step instructions with code samples
5. **Best Practices** - Recommendations for production use
6. **Troubleshooting** - Common issues and their solutions

## Getting Started

To begin with any guide:

1. Make sure you have Docker and Docker Compose installed on your system
2. At least 8GB of available RAM is recommended for running the Ignite containers
3. Clone this repository to your local machine
4. Navigate to the specific guide directory
5. Follow the step-by-step instructions

## Docker Compose Files

Each guide includes a Docker Compose file that sets up a three-node Ignite cluster. You can start the cluster with:

```bash
docker compose up -d
```

And stop it with:

```bash
docker compose down
```

## Common Resources

The repository also includes SQL scripts and other resources that are used when developing the guides:

- `/sql` directory contains SQL queries for various operations
- Sample data files for the Chinook database
