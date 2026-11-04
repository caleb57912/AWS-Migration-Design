# Architecture decision records

One file per major decision: the context, the options, what I chose, and why. Copy [`template.md`](template.md) to start a new one.

✅ accepted · 📝 draft under review · 🔜 not started

| ADR | Decision | Alternative compared | Status |
|---|---|---|---|
| 001 | Replatform the vendor EHR onto EC2 and Aurora | SaaS EHR | 🔜 |
| [002](002-aurora-postgresql.md) | Aurora PostgreSQL | RDS PostgreSQL Multi-AZ, self-managed on EC2 | 📝 draft |
| 003 | AWS HealthImaging | PACS software on EC2 with S3 | 🔜 |
| [004](004-multi-account-landing-zone.md) | Multi-account landing zone with Control Tower | Single account | ✅ |
| 005 | Pilot light DR in us-east-1 | Backup and restore, warm standby | 🔜 |
| 006 | Hybrid Direct Connect + VPN | VPN only, Direct Connect everywhere | 🔜 |
| [007](007-terraform-primary-iac.md) | Terraform as primary IaC | CloudFormation, AWS CDK | 📝 draft |
| [008](008-verified-access-remote-staff.md) | AWS Verified Access for remote staff | AWS Client VPN | 📝 draft |
| 009 | Centralized egress with Network Firewall | NAT gateways in every VPC | 🔜 |
| [010](010-region-selection.md) | us-west-2 primary, us-east-1 DR | us-east-1 primary | 📝 draft |
| [011](011-interface-engine-active-passive.md) | Interface engine active/passive behind an NLB | Single self-healing instance | 📝 draft |
| [012](012-entra-id-identity-center.md) | Entra ID federated to Identity Center | Identity Center directory | 📝 draft |
| [013](013-mdr-security-lake-siem.md) | MDR provider with Security Lake and a SIEM | Native AWS tools only | 📝 draft |
