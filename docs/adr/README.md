# Architecture decision records

One file per major decision: the context, the options, what I chose, and why. Copy [`template.md`](template.md) to start a new one.

| ADR | Decision | Alternative compared | Status |
|---|---|---|---|
| 001 | Replatform the vendor EHR onto EC2 and RDS | SaaS EHR | 🔜 |
| 002 | RDS for PostgreSQL | Self-managed database on EC2 | 🔜 |
| 003 | AWS HealthImaging | PACS software on EC2 with S3 | 🔜 |
| 004 | Multi-account landing zone with Control Tower | Single account | 🔜 |
| 005 | DR strategy | Pilot light / warm standby | 🔜 |
| 006 | Hybrid Direct Connect + VPN | VPN only, Direct Connect everywhere | 🔜 |
| 007 | Terraform as primary IaC | CloudFormation, AWS CDK | 🔜 |
| 008 | AWS Verified Access for remote staff | AWS Client VPN | 🔜 |
| 009 | Centralized egress with Network Firewall | NAT gateways in every VPC | 🔜 |
| 010 | us-west-2 primary, us-east-1 DR | us-east-1 primary | 🔜 |
