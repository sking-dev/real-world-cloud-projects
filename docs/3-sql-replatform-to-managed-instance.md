# Project 3: Replatforming SQL from IaaS VMs to Azure SQL Managed Instance

⚙️ Draft version — content under review and subject to updates.

## Context

Following an initial lift‑and‑shift migration from an on‑premises data centre to Azure, several SQL Server workloads continued to run on IaaS VMs.  While functional, this approach incurred high operational overhead and limited resilience.

The goal of this project was to replatform the SQL workloads to **Azure SQL Managed Instance (MI)** — reducing maintenance effort, improving availability, and aligning with the organisation’s move toward PaaS services within existing landing zone subscriptions.

## Requirements

- Decommission SQL Server on IaaS VMs while maintaining data integrity and minimal downtime.
- Implement **Managed Instance** within the same landing zone spoke subscription, isolated on a dedicated Virtual Network peered to the existing hub.  
- Include supporting services (Azure Data Factory) within the same isolated VNet.
- Ensure compatibility with legacy authentication (AD‑joined domains) and connectivity from dependent applications.  
- Enable automated provisioning and configuration through Infrastructure‑as‑Code (Terraform).  
- Provide robust backup, failover, and monitoring aligned with enterprise standards.  
- Optimise networking and NSG configurations to restrict surface area and preserve low‑latency access.

## Architecture

- **Landing Zone:** Existing hub‑and‑spoke VNet model; MI deployed in the same spoke subscription as the previous SQL VMs.
- **Connectivity:** Private endpoint access only; NSGs on application subnets and Managed Instance subnet filter traffic across VNet peering (hub Azure Firewall provides perimeter protection).  
- **Automation:** Terraform provisioned Managed Instance, associated subnets, route tables, and parameter configurations.  
- **Authentication:** Integrated Azure AD authentication plus SQL Auth for legacy compatibility.  
- **Monitoring:** Azure Monitor metrics and diagnostic logs routed to Log Analytics.  
- **Backup/DR:** Built‑in PITR backups; optional read‑only replica in paired region under evaluation.

## Key Decisions

- Managed Instance chosen over Azure SQL Database (single DB) to preserve full SQL Server compatibility including cross-database queries and SQL Agent jobs.
- Retain existing **VNet peering topology** for simplicity and consistent latency.
- Use **Terraform** with modular design for flexible environment orchestration.
- **Azure Key Vault** adopted for secure credential storage and service connection integration with pipelines.
- Configure **Network Security Groups** to allow only required source subnets (application tiers and jump hosts).

## Operations

- Legacy SQL VMs placed into read-only mode during cutover testing, with sequential migration to Managed Instance to maintain application availability.
- Automated deployments validated against non‑prod environments before production rollout.  
- Performance and consumption metrics compared before and after migration confirming appropriate sizing with no performance regression observed.
- Backup and monitoring configurations validated through disaster‑recovery tabletop tests.  
- Compliance reporting handled through Azure Policy to ensure resources met naming and tagging standards.

## Future Enhancements

- Implement auto-failover groups for active geo-replication across paired regions.
- Integrate **Azure Automation Runbooks** for database index maintenance, query performance alerting, and compliance reporting.  
- Enable Microsoft Defender for SQL for continuous vulnerability assessment and threat detection.

## Code References

NOTE: These references are placeholders and should be updated when the `/code` directory structure is finalised.

- `/code/project3-terraform/` — Terraform deployment and parameter files.  
- `/code/project3-bicep/` — Bicep equivalent templates for Managed Instance and networking.  
- `/docs/common/` — Shared standards, governance, and IaC reference patterns.
