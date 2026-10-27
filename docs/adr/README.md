# Architecture decision records

One file per major decision: the context, the options, what I chose, and why. Copy [`template.md`](template.md) to start a new one.

| ADR | Decision | Alternative compared | Status |
|---|---|---|---|
| 001 | EC2 Auto Scaling for the app tier | AWS Lambda | 🔜 |
| 002 | RDS for PostgreSQL | Self-managed database on EC2 | 🔜 |
| 003 | AWS HealthImaging | PACS software on EC2 with S3 | 🔜 |
| 004 | Multi-account with Organizations | Single account | 🔜 |
| 005 | Backup-and-restore DR | Pilot light / warm standby | 🔜 |
| 006 | Site-to-Site VPN | AWS Direct Connect | 🔜 |
| 007 | Terraform as primary IaC | CloudFormation, AWS CDK | 🔜 |
