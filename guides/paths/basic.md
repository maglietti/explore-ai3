# Onboarding

```mermaid
flowchart LR
    subgraph Core["Core Onboarding"]
        C1[Establish Dev Environment] --> C2
        C2[Understand Development] --> C3
        C3[Application Development] --> C4
        C4[Operations]
    end

    Core --> DataMgmt
    Core --> Dev
    Core --> RefApp
    Core --> Ops

    subgraph DataMgmt["Establish Dev Environment"]
        direction TB
        D1[Docker]
        D2[CLI]
        D3[SQL]
        D4[Data Profiles, Zones, and Colocation]
        D5[Persistent Storage]
    end

    subgraph Dev["Understand Development"]
        A1[Java API]
        A2[Compute Grid]
        A3[Caching]
        A4[Transactions]
        D5[Columnar Storage]
    end
    
    subgraph RefApp["Application Development"]
        direction TB
        R1[Embedded Mode]
        R2[Migration from Apache Ignite 2]  
        R3[Using Apache Ignite 3 as a DB Accelerator/Cache]
        A4[Streaming]
    end

    subgraph Ops["Operations"]
        direction TB
        O1[Monitoring]
        O2[Logs]
        O3[Public Cloud Deployments]
        O4[Kubernetes]
    end

    Core:::core
    DataMgmt:::data
    Dev:::dev
    RefApp:::app
    Ops:::ops
    
    classDef core fill:#d1f0ff,stroke:#0077b6,stroke-width:3px
    classDef data fill:#ffe8d6,stroke:#bc6c25,stroke-width:3px
    classDef dev fill:#d5f5e3,stroke:#27ae60,stroke-width:3px
    classDef app fill:#d8f3dc,stroke:#2d6a4f,stroke-width:3px
    classDef ops fill:#f1faee,stroke:#457b9d,stroke-width:3px

    class C1,C2,C3,C4,C5 core
    class D1,D2,D3,D4,D5 data
    class A1,A2,A3,A4,A5 dev
    class R1,R2,R3,R4,R5 app
    class O1,O2,O3,O4,O5 ops
    ```
