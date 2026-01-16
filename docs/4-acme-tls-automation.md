# Project 4: Automating TLS Certificates with ACME for Azure Resources

⚙️ Draft version — content under review and subject to updates.

## Context

During internal security reviews, several public‑facing workloads were found to rely on manually issued TLS certificates managed through the Azure Portal. This introduced administrative overhead, inconsistent renewals, and risk of service interruption. The aim of this project was to automate certificate issuance and renewal using **the ACME protocol** (as implemented by Let’s Encrypt) and integrate it with **Azure App Service**, **Application Gateway**, and **Key Vault‑based endpoints**.

## Requirements

- Remove manual certificate management from operational workflows.  
- Automate issuance, renewal, and binding of certificates using ACME‑compatible tooling.  
- Support **Azure App Service** custom domains and **Application Gateway** listeners.  
- Store and manage certificates in **Azure Key Vault** for centralized lifecycle control.  
- Integrate with IaC pipelines (Terraform / Bicep) to ensure repeatable provisioning.  
- Conform to corporate security policies for key size, expiration, and renewal intervals.

## Architecture

- **Certificate Issuer:** Let’s Encrypt configured via ACME client automation (Certbot / acme‑sh / Posh‑ACME).  
- **Storage:** Certificates and keys stored securely in Azure Key Vault with RBAC‑scoped access.  
- **Integration:**  
  - Event‑based automation via **Azure Functions** triggers renewal workflows before expiry.  
  - Updated certificates automatically re‑bound to App Service and Application Gateway.  
- **IaC:** Terraform and Bicep templates create service principal, Function resources, and Key Vault policies.  
- **Monitoring:** Azure Monitor alerts on near‑expiry certificates and renewal failures.

## Key Decisions

- Standardized on **Azure Key Vault** as the single source of truth for all TLS materials.  
- Chose **Azure Functions (Python/PowerShell runtime)** to run renewal jobs for flexibility and lightweight runtime.  
- Used **Managed Identity** for secure authentication between Function, Key Vault, and network endpoints — no stored credentials.  
- Integrated ACME configuration values as pipeline variables for reusability across environments.  
- Applied **Azure Policy** to enforce TLS certificate rotation and HTTPS‑only endpoints.

## Operations

- Renewal pipeline triggers automatically ~14 days before certificate expiry.  
- Azure Functions handle renewals and binding with minimal downtime.  
- Key Vault notifications integrated with Microsoft Defender for Cloud for compliance monitoring.  
- Operations team alerted via Teams webhook on renewal success/failure events.  
- Manual fail‑safe procedure documented for break‑glass certificate uploads.

## Future Enhancements

- Extend automation to cover internal‑only endpoints issued by a private CA via ACMESharp / step‑ca.  
- Consolidate renewal telemetry into a central **Azure Workbook** dashboard for visibility.  
- Explore integration with **DNS‑01 challenge automation** for wildcard certificates.  
- Convert Function logic into a reusable module deployable across landing zones.

## Code References

NOTE: These references are placeholders and should be updated when the `/code` directory structure is finalised.

- `/code/project4-terraform/` — Terraform templates for Function App, Key Vault, and policy.  
- `/code/project4-bicep/` — Bicep equivalents demonstrating ACME automation workflows.  
- `/docs/common/` — Shared governance, naming, and policy enforcement examples.
