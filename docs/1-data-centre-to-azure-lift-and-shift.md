# Data Centre to Azure: Lift‑and‑Shift Migration with Landing Zone Foundations

⚙️ Draft version — content under review and subject to updates.

## Context

The organisation ran core workloads in a long‑standing physical data centre on ageing hardware that was at or nearing end‑of‑life.

The infrastructure was costly to maintain, capacity‑limited, and lacked the flexibility for new service deployments.

The goal was to migrate existing virtual machines and supporting infrastructure into Microsoft Azure using a **lift‑and‑shift** model, applying **Azure Landing Zone** principles to ensure future scalability, governance, and security.  

## Requirements

- **Time‑bound migration window** driven by a data centre contract renewal deadline  
- **Minimal architectural change** — priority on rehosting to IaaS for speed and a shallower learning curve
- **Regulatory compliance** with internal security baselines
  - Although the organisation did not formally adopt an external regulatory framework (such as ISO 27001 or PCI DSS) at the time, the migration was expected to meet internal security standards and audit requirements
- **Identity federation** to integrate existing Active Directory with Azure AD
  - On‑premises AD had already been integrated with Azure AD during a prior migration from Exchange Server to Exchange Online, so this project focused on extending that integration to additional workloads and administration
- **Low disruption** to business operations during phased cutover with non-production environments going over first

## Architecture

The target architecture applied the **Azure Landing Zone** design pattern with a **hub‑and‑spoke topology**:  

- **Hub network** — shared services, connectivity, monitoring, and security controls
- **Spoke networks** — segregated by application tier (Web, Database, etc.) and environment
- **Hybrid connectivity** — VPN gateway for initial connectivity (with potential to replace later with ExpressRoute)
- **Identity** — Azure AD Connect for directory synchronization and SSO
  - Azure AD Connect for directory synchronisation and SSO for Azure portal, ARM, and Microsoft 365 access
- **Management and governance** — Azure Policy, Resource Tags, and Log Analytics workspace
- **Tools used** — Azure Migrate for assessment and migration, Azure Backup, and Automation Accounts for task scheduling
  - Azure Migrate for discovery, assessment, and migration, Azure Backup for data protection, and Automation Accounts for scheduled operational tasks

## Key Decisions

- **Rehost vs. Refactor:** A rehost approach met the contractual timeline but deferred some modernisation.
  - Future replatforming candidates were identified and documented early in the migration.
- **Hub‑and‑Spoke Topology:** Provided isolation and governance but required careful planning for shared routing and role‑based access.  
- **IaC evolution:** Started with **ARM templates** as preferred native tooling for IaC, then transitioned to **Terraform** for better state management, modularity, and team collaboration as GitOps practices matured. Foundational components (landing zones, networking) used IaC; workload migration leveraged Azure Migrate tooling for speed.  
- **Security controls:** Network security groups (NSGs) at the subnet level and Azure Firewall in the hub ensured compliance but added configuration overhead during pilot testing.  

## Operations

- **Reliability and monitoring:** Azure Monitor and Log Analytics captured performance data both pre‑ and post‑migration, helping tune VM sizes and storage tiers.  
- **Cutover hiccups:** DNS dependencies between legacy services caused delays during testing, which highlighted the need for better application dependency mapping.  
- **Post‑migration optimization:** Initial ad‑hoc rightsizing of a subset of workloads indicated potential compute cost savings of around 20%, which informed a more systematic optimisation plan.
- **Knowledge capture:**  A migration runbook, a self‑documenting IaC codebase, and an Azure DevOps project Wiki were used to capture decisions, patterns, and operational procedures for future phases.

## Future Enhancements

- Transition selected VMs to PaaS services (App Service, Azure SQL Managed Instance), based on replatforming candidates identified during migration planning.
- Introduce Azure Automation + Terraform pipelines for full IaC reproducibility and environment‑consistent deployments.
- Enhance backup and DR posture with geo‑redundant Recovery Services vaults and regular restore testing.
- Implement a structured rightsizing and cost optimisation programme, using Azure Advisor recommendations and budgets to govern spend.

## Code References

Generic examples in multiple IaC formats:

```plaintext
code/
├── terraform/landing-zone/      # Hub-spoke network and shared services
├── bicep/landing-zone/          # Equivalent Bicep patterns
└── pipelines/tf-plan-apply.yml  # Generic Azure DevOps pipeline for Terraform

```

Each snippet to show structure and variables only, never organisation‑specific IDs, IPs, DNS names, or internal hostnames.
