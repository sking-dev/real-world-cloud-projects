# Code Examples

Generic, parameterised IaC and pipeline snippets referenced by case studies. **Structure only** — no organisation-specific IDs, IPs, secrets, or production values.

## IaC Tools

- **terraform/**: Primary tool used across projects
- **bicep/**: Comparative examples showing equivalent patterns (versatility option)

## Usage

- Review alongside relevant case study for context
- Parameterise variables before local testing
- Compare `terraform/` vs `bicep/` for same resources to see IaC trade-offs

## Structure

```plaintext
code/
├── terraform/ # Landing zones, networking, PaaS (primary)
│ ├── landing-zone/
│ ├── sql-mi/
│ └── web-app/
├── bicep/ # Equivalent patterns (comparative)
│ ├── landing-zone/
│ ├── sql-mi/
│ └── web-app/
└── pipelines/ # Azure DevOps YAML examples
```
