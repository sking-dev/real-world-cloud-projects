# Project 5: Replatforming WordPress from Virtual Machines to Azure Web Apps using IaC

⚙️ Draft version — content under review and subject to refinement.

## Context

WordPress sites previously hosted on Linux virtual machines had become costly and time‑consuming to maintain, with manual updates, unmanaged scaling, and security patching consuming significant operational effort.

To modernise these workloads, the project replatformed the WordPress stack onto Azure Web Apps for Linux using Infrastructure as Code (IaC) to achieve greater consistency, automation, and simplified lifecycle management.

## Requirements

- Replace virtual machine‑hosted WordPress instances with platform‑as‑a‑service (PaaS) equivalents.
- Maintain continuity of customer content and media with minimal downtime during migration.
- Integrate Azure Database for MySQL Flexible Server as the managed data layer.
- Use Azure Storage for persistent media and file uploads.
- Enable automation for provisioning, configuration, and DNS registration to reduce manual administration.
- Enforce corporate standards for security, tagging, and monitoring across all environments.

## Architecture

- **Application Tier:** WordPress deployed to Azure Web Apps for Linux with custom start‑up scripts to handle environment‑specific configuration.
- **Data Tier:** MySQL Flexible Server provisioned in the same region with private endpoint connectivity for secure access.
- **Storage:** Azure Storage account mounted as a shared content repository for WordPress uploads.
- **Networking:** Virtual network integration enabled to secure database and other private service access.
- **IaC Deployment:** Terraform modules defining App Service, database, storage, and monitoring resources per environment.
- **CI/CD:** Azure Pipelines automating infrastructure deployment from private Azure Repos to dedicated Azure subscriptions.
- **Monitoring:** Application Insights and Azure Monitor providing performance, availability, and health tracking.

NOTE: A separate source code repository and Azure Pipelines configuration were also created as a proof of concept to deploy WordPress source code to each Web App, demonstrating how manual site administration could be reduced and paving the way for future standardised release processes.

## Key Decisions

- Selected Web Apps for Linux instead of App Service for Containers to simplify management and leverage built‑in scaling.
- Used Azure Database for MySQL Flexible Server to gain automated patching and high availability.  
- Adopted Azure Storage with the option to integrate Azure CDN to offload large file hosting and improve global performance as the platform matures.
- Configured managed identities for secure, passwordless connections to Azure Key Vault and Azure Storage.
- Implemented Azure DevOps pipeline automation to handle Web App and WordPress‑related configuration, including custom domains, SSL bindings, and environment variables such as database connection settings and site URLs.

## Operations

- IaC templates deployed new staging environments for testing and validation prior to production cut‑over.
- Switched traffic using DNS updates and App Service deployment slots to achieve near‑zero downtime cut‑over.
- Configured automated scaling rules based on CPU and memory utilisation metrics.  
- Conducted post‑migration audits to validate patch compliance, security posture, and performance improvements.

## Future Enhancements

- Introduce App Service Environment v3 for isolated, high‑security WordPress hosting in scenarios requiring stricter network isolation and compliance.
- Containerise WordPress workloads for greater portability using App Service for Containers or Azure Kubernetes Service (AKS).
- Implement Azure CDN to serve cached static content and further improve site performance.
- Implement Content Delivery Network rules engine capabilities to support smarter caching and routing policies within the chosen Azure CDN offering.

## Code References

NOTE: These references are placeholders and will be updated when the `/code` directory structure is finalised.

- `/code/project5-terraform/` — Terraform implementation of Web App, MySQL, and supporting resources.
- `/docs/common/` — Shared networking, monitoring, and automation standards.
