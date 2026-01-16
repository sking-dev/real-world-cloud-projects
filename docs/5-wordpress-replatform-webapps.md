# Project 5: Replatforming WordPress from VMs to Azure Web Apps with IaC

⚙️ Draft version — content under review and subject to updates.

## Context

WordPress sites previously hosted on Linux VMs were proving costly and time‑consuming to maintain, with manual updates, unmanaged scaling, and security patching consuming significant effort. To modernize these workloads, the project replatformed the WordPress stack onto **Azure Web Apps for Linux** using **Infrastructure‑as‑Code (IaC)** to achieve consistency, automation, and easier lifecycle management.

## Requirements

- Replace VM‑hosted WordPress instances with PaaS equivalents.  
- Maintain customer content and media continuity with minimal downtime.  
- Integrate **Azure Database for MySQL Flexible Server** as the managed data layer.  
- Use **Azure Storage** for persistent uploads and **Azure CDN** for cached static content.  
- Enable automation for provisioning, configuration, and DNS registration.  
- Enforce corporate standards for security, tagging, and monitoring.

## Architecture

- **Application Tier:** WordPress deployed to Azure Web Apps for Linux with custom startup scripts.  
- **Data Tier:** MySQL Flexible Server provisioned in the same region with private endpoint connectivity.  
- **Storage:** Azure Storage Account mounted as shared content repository for uploads.  
- **Networking:** VNet integration enabled for database and private service access.  
- **CI/CD:** Azure Pipelines automating application deployment from GitHub repo to Web App.  
- **Monitoring:** Application Insights and Azure Monitor providing performance and availability tracking.  
- **IaC Deployment:** Both Terraform and Bicep templates define App Service, DB, Storage, and monitoring resources.

## Key Decisions

- Selected **Web Apps for Linux** instead of **App Service Containers** for simplified management and built‑in scaling.  
- Used **Flexible Server** for MySQL to gain auto‑patching and high availability.  
- Adopted **Azure Storage + CDN** for offloading large file hosting and improving global performance.  
- Configured **Managed Identity** for secure connections to Key Vault and Storage.  
- Implemented pipeline automation to handle WordPress configuration (domain, SSL binding, environment variables).

## Operations

- IaC templates deployed new staging environments for testing before production cut‑over.  
- Content synchronized using `wp-cli` export/import and Azure Storage copy operations.  
- Traffic switched using DNS update and App Service swap slots for near‑zero downtime.  
- Automated scaling rules based on CPU and memory utilization metrics.  
- Post‑migration audits validated patch compliance and performance improvements.

## Future Enhancements

- Introduce **App Service Environment v3** for isolated, high‑security WordPress hosting.  
- Containerize workloads for portability via **App Service for Containers** or **Azure Kubernetes Service**.  
- Implement **Content Delivery Network Rules Engine** for smarter caching policies.  
- Expand IaC modules into reusable building blocks for other PHP‑based workloads.

## Code References

NOTE: These references are placeholders and should be updated when the `/code` directory structure is finalised.

- `/code/project5-terraform/` — Terraform implementation of Web App, MySQL, and supporting resources.  
- `/code/project5-bicep/` — Bicep templates for equivalent infrastructure.  
- `/docs/common/` — Shared networking, monitoring, and automation standards.
