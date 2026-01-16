# Data Centre to Azure: Lift‑and‑Shift Migration with Landing Zone Foundations

⚙️ Draft version — content under review and subject to updates.

## Context and Objective

The organisation operated workloads in a long-term physical data centre on ageing hardware that had reached, or was fast approaching, end‑of‑life. The infrastructure was costly to maintain, capacity‑limited, and lacked the flexibility for new service deployments.  
The goal was to migrate existing virtual machines and supporting infrastructure into Microsoft Azure using a **lift‑and‑shift** model, applying **Azure Landing Zone** principles to ensure future scalability, governance, and security.  

## Requirements and Constraints

- **Time‑bound migration window** driven by a data centre contract renewal deadline  
- **Minimal architectural change** — priority on rehosting to IaaS for speed and a shallower learning curve
- **Regulatory compliance** with internal security baselines  
- **Identity federation** to integrate existing Active Directory with Azure AD
- **Low disruption** to business operations during phased cutover with non-production environments going over first

## High‑Level Architecture

The target architecture applied the **Azure Landing Zone** design pattern with a **hub‑and‑spoke topology**:  

- **Hub network** — shared services, connectivity, monitoring, and security controls
- **Spoke networks** — segregated by application tier (Web, Database, etc.) and environment
- **Hybrid connectivity** — VPN gateway for initial connectivity (with potential to replace later with ExpressRoute)
- **Identity** — Azure AD Connect for directory synchronization and SSO
- **Management and governance** — Azure Policy, Resource Tags, and Log Analytics workspace
- **Tools used** — Azure Migrate for assessment and migration, Azure Backup, and Automation Accounts for task scheduling

## Design Decisions and Trade‑offs

- **Rehost vs. Refactor:** A rehost approach met the timeline but sacrificed some modernization opportunities. The team documented future replatforming candidates early.  
- **Hub‑and‑Spoke Topology:** Provided isolation and governance but required careful planning for shared routing and role‑based access.  
- **IaC evolution:** Started with **ARM templates** as preferred native tooling for IaC, then transitioned to **Terraform** for better state management, modularity, and team collaboration as GitOps practices matured. Foundational components (landing zones, networking) used IaC; workload migration leveraged Azure Migrate tooling for speed.  
- **Security controls:** Network security groups (NSGs) and Azure Firewall in the hub ensured compliance but added configuration overhead during pilot testing.  

## Operations, Reliability, and Lessons Learned

- **Reliability and monitoring:** Azure Monitor and Log Analytics captured performance data both pre‑ and post‑migration, helping tune VM sizes and storage tiers.  
- **Cutover hiccups:** DNS dependencies between legacy services caused delays during testing, which highlighted the need for better application dependency mapping.  
- **Post‑migration optimization:** Rightsizing exercises reduced compute costs by ~20%.  
- **Knowledge capture:** A migration runbook and service catalogue were documented to guide future phases.  

## Future Enhancements

- Transition selected VMs to **PaaS** services (App Service, Azure SQL Managed Instance).  
- Introduce **Azure Automation + Terraform pipelines** for full IaC reproducibility.  
- Enhance **backup and DR posture** with geo‑redundant vaults.  
- Evaluate **cost management** via Azure Advisor and budgets.  

## Code Examples

Generic examples in both IaC formats:

```markdown
code/
├── terraform/landing-zone/ # Hub-spoke network + shared services
├── bicep/landing-zone/ # Equivalent Bicep patterns
└── pipelines/tf-plan-apply.yml # Generic Azure DevOps pipeline
```

Each snippet shows **structure and variables only**, never organization‑specific IDs, IPs, or names.
