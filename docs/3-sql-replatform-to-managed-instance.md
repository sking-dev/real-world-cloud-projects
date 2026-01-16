# Project 3: Replatforming SQL from IaaS VMs to Azure SQL Managed Instance

⚙️ Draft version — content under review and subject to updates.

## Context

Following an initial lift‑and‑shift migration from an on‑premises data centre to Azure, several SQL Server workloads continued to run on IaaS VMs. While functional, this approach incurred high operational overhead and limited resilience. The goal of this project was to replatform the SQL workloads to **Azure SQL Managed Instance (MI)** — reducing maintenance effort, improving availability, and aligning with the organisation’s move toward PaaS services within existing landing‑zone subscriptions.

## Requirements

- Decommission SQL Server on IaaS VMs while maintaining data integrity and minimal downtime.  
- Implement **Managed Instance** within the same landing‑zone spoke subscription, connected to the existing hub via VNet peering.  
- Ensure compatibility with legacy authentication (AD‑joined domains) and connectivity from dependent applications.  
- Enable automated provisioning and configuration through Infrastructure‑as‑Code (Terraform and Bicep).  
- Provide robust backup, failover, and monitoring aligned with enterprise standards.  
- Optimise networking and NSG configurations to restrict surface area and preserve low‑latency access.

## Architecture

- **Landing Zone:** Existing hub‑and‑spoke VNet model; MI deployed in the same spoke as the previous SQL VMs.  
- **Connectivity:** Private endpoint access only; hub firewall permitting communication from app subnets.  
- **Automation:** Terraform and Bicep templates provisioned Managed Instance, associated subnets, route tables, and parameter configurations.  
- **Authentication:** Integrated Azure AD authentication plus SQL Auth for legacy compatibility.  
- **Monitoring:** Azure Monitor metrics and diagnostic logs routed to Log Analytics.  
- **Backup/DR:** Built‑in PITR backups; optional read‑only replica in paired region under evaluation.

## Key Decisions

- Chose **Managed Instance** over single‑database Azure SQL DB to retain near full SQL Server compatibility (e.g. cross‑database queries, SQL Agent).  
- Retained existing **VNet peering topology** for simplicity and consistent latency.  
- Used **Terraform** for environment orchestration and **Bicep** for quick remediation templates.  
- Adopted **Azure Key Vault** for credential storage and pipeline integration.  
- Configured **Network Security Groups** to allow only required source subnets (application tiers and jump hosts).  

## Operations

- Legacy SQL VMs placed in read‑only mode during testing and migrated off sequentially.  
- Automated deployments validated against non‑prod environments before production rollout.  
- Performance and consumption metrics compared before and after migration to confirm sizing accuracy.  
- Backup and monitoring configurations validated through disaster‑recovery tabletop tests.  
- Compliance reporting handled through Azure Policy to ensure resources met naming and tagging standards.

## Future Enhancements

- Evaluate **auto‑failover groups** for regional redundancy.  
- Integrate **Azure Automation Runbooks** or **Functions** for scheduled maintenance tasks.  
- Consider **Azure Defender for SQL** integration for continuous vulnerability scanning.  
- Refactor IaC templates into shared modules for consistent MI provisioning across workloads.

## Code References

NOTE: These references are placeholders and should be updated when the `/code` directory structure is finalised.

- `/code/project3-terraform/` — Terraform deployment and parameter files.  
- `/code/project3-bicep/` — Bicep equivalent templates for Managed Instance and networking.  
- `/docs/common/` — Shared standards, governance, and IaC reference patterns.
