# Real World Cloud Projects

A collection of real‑world Azure engineering case studies — projects I’ve built, design decisions explored, trade‑offs weighed, and lessons learned. Each follows a consistent structure to highlight context, technical reasoning, and practical outcomes.

🔧 **Work in progress:** Case studies are currently in draft form and will be updated shortly.

🤖 **AI assistance:** Parts of this content were drafted and refined with the help of AI tools, alongside a manual review process.

## Featured Projects

| # | Case Study | Focus Area |
| --- | ------------ | ----------- |
| 1 | [Data Centre to Azure: Lift‑and‑Shift Migration with Landing Zone Foundations](docs/1-data-centre-to-azure-lift-and-shift.md) | Initial cloud migration to IaaS using Landing Zones |
| 2 | [Adopting GitOps for Azure: From Click‑Ops to Pipeline‑Driven Deployments](docs/2-gitops-azure-deployments.md) | Infrastructure‑as‑Code standardisation with Azure DevOps pipelines |
| 3 | [Replatforming SQL from IaaS VMs to Azure SQL Managed Instance](docs/3-sql-replatform-to-managed-instance.md) | Database modernisation post‑migration |
| 4 | [Automating TLS Certificates with ACME for Azure Resources](docs/4-acme-tls-automation.md) | Certificate lifecycle automation via ACME and IaC |
| 5 | [Replatforming WordPress from VMs to Azure Web Apps with IaC](docs/5-wordpress-replatform-webapps.md) | Application modernisation using repeatable multi‑environment IaC patterns |
| 6 | [Azure Policy Implementation for Landing Zone Governance](docs/6-azure-policy-landing-zone.md) | Hub-and-spoke landing zone governance using IaC-controlled Azure Policy |

## Repository Structure

```plaintext
real-world-cloud-projects/
├── README.md # Project overview and navigation
├── docs/ # Detailed case studies
│ ├── README.md # Case study index
│ ├── 1-data-centre-to-azure-lift-and-shift.md
│ ├── 2-gitops-azure-deployments.md
│ ├── 3-sql-replatform-to-managed-instance.md
│ ├── 4-acme-tls-automation.md
│ └── 5-wordpress-replatform-webapps.md
├── code/ # Generic IaC and pipeline examples
│ ├── terraform/
│ ├── bicep/
│ └── pipelines/
├── .gitignore # Terraform template + extras
└── LICENSE # (optional MIT/Apache 2.0)
```

## How to Use

- **Portfolio**: Each case study demonstrates real-world problem solving across migration, process, modernisation, security, and application patterns.
- **Technical reference**: `code/` contains parameterised, production-pattern examples safe for reuse or learning.
- **Learning resource**: Consistent structure shows context → decisions → trade-offs → outcomes for common cloud engineering challenges.

## Contributing

Open to feedback on structure, clarity, or additional projects. Snippets follow "structure only" principle — no org-specific IDs, IPs, or secrets.
