# 03 · Full design review

**Phase:** 1 · Design
**Result:** ✅ Every layer of the design decided and recorded in the [design plan](../docs/design-plan.md), with the alternative each choice beat and the traps it avoids

## What I decided

| Layer | Decision |
|---|---|
| Compute | EC2 Auto Scaling for the EHR; interface engine active/passive behind an internal NLB; golden AMIs from EC2 Image Builder; Session Manager only; EDR on every instance |
| Database | Aurora PostgreSQL writer and reader, CMK encryption, Secrets Manager rotation, Vault Lock backups, pgAudit |
| Storage and imaging | SSE-KMS everywhere, account-wide Block Public Access, Object Lock (governance for records, compliance for logs), HealthImaging with a replicated S3 archive, OHIF viewer, Macie |
| Identity | Entra ID federated to Identity Center, just-in-time Prod admin, alarmed break-glass, root credentials removed from member accounts, ABAC on PHI |
| Monitoring | CloudTrail data events on PHI, full network and app logging, GuardDuty, Security Hub, Config HIPAA conformance pack, Security Lake feeding an MDR-run SIEM, automated quarantine |
| Shared responsibility | Mapped per service type and extended to the EHR vendor, MDR provider, and clinic hardware, with a BAA inventory |
| HA and DR | Recovery tiers; pilot light in us-east-1 with Aurora Global Database; static stability; quarterly fault-injection tests |
| Cost | 1-year commitments on the baseline only, scheduled non-prod, network processing reviews, security costs shown on their own line |
| Migration | Discovery first, then five waves from documents to EHR to clinics, with validation, a 30-day rollback window, and NIST 800-88 decommissioning |
| IaC and deploy | Terraform with `default_tags`, scanners in GitHub Actions, and a no-NAT deploy slice that proves the private-origin and tagging designs |

## Corrections I made along the way

| Earlier assumption | Correction |
|---|---|
| Security Hub has a HIPAA standard | It doesn't; HIPAA mapping lives in Config conformance packs and Audit Manager |
| Cognito for patient logins | The vendor portal brings its own patient identity |
| `terraform plan` for every environment | `plan` needs real accounts; non-deployed environments are validated and scanned |
| Backup-and-restore DR | Too slow for the EHR; replaced with pilot light |

## What I learned

- HL7 over MLLP is raw TCP, so it needs a Network Load Balancer, and active/passive keeps messages in order
- CloudTrail doesn't record data access unless data events are turned on
- Static stability means pre-provisioning so an AZ loss doesn't depend on scaling during the outage
- The HIPAA conduit exception covers carriers, but anyone who can see PHI, including a security provider, needs a BAA

## Skills

Cloud architecture · Disaster recovery planning · Identity federation · Security operations design · Cost optimization · Migration planning
