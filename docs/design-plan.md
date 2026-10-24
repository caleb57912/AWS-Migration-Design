# Design Plan

The master plan for the Bayou Clinic Partners migration. Every foundation in the design is listed here with the reason it exists. Deeper reasoning for the biggest choices lives in [`adr/`](adr).

## 1. Scenario and assumptions

| Item | Assumption |
|---|---|
| Organization | Bayou Clinic Partners (fictional), 8 outpatient clinics, about 400 staff |
| Workloads | EHR (electronic health record) web app, patient portal, document storage, medical imaging (X-ray and ultrasound) |
| Users | Clinic staff during business hours (7 AM–7 PM), patients on the portal at any hour |
| Data | PHI (protected health information) in the database, documents, and DICOM images |
| Compliance | HIPAA; a BAA (business associate agreement) is signed with AWS before any PHI moves |
| Clinic sites | Each clinic keeps its imaging devices and a small network edge; everything else moves to AWS |

### Recovery targets

RTO (recovery time objective) is how long a system can be down. RPO (recovery point objective) is how much data can be lost, measured in time.

| Failure | RTO | RPO | How |
|---|---|---|---|
| Single server | Minutes | None | Auto Scaling replaces it behind the load balancer |
| Availability Zone | Minutes | Near zero | Multi-AZ RDS failover, app tier in two AZs |
| Whole region | 24 hours | 1 hour | Backup and restore into us-west-2 |

## 2. Foundations

### Account structure and governance

| Foundation | Choice | Why |
|---|---|---|
| Accounts | AWS Organizations with **Prod**, **Dev**, and **Security** accounts | Separates environments so a mistake in Dev can't touch patient data; the Security account holds logs no workload admin can delete |
| Guardrails | Service control policies (SCPs) | Organization-wide limits, such as blocking regions we don't use and blocking anyone from turning off CloudTrail |
| BAA | Accepted in AWS Artifact | HIPAA requires it before PHI is stored in AWS |
| HIPAA-eligible services only | Every PHI-touching service checked against AWS's eligible list | A non-eligible service handling PHI breaks compliance even if it's configured well |
| Tagging | `Environment`, `Owner`, `CostCenter`, `DataClass` on every resource | Drives cost reports per clinic and lets policies target PHI resources |

### Regions

| Foundation | Choice | Why |
|---|---|---|
| Primary | us-east-1 | Every service in the design is available there, including HealthImaging |
| Disaster recovery | us-west-2 | Far enough away that one regional event doesn't take out both; also supports HealthImaging |

### Network

| Foundation | Choice | Why |
|---|---|---|
| VPC | One VPC per environment, `/16` range that doesn't overlap clinic networks | Overlapping ranges break VPN routing; `/16` leaves room to grow |
| Availability Zones | Two | Survives a full AZ outage; a third adds cost without changing the recovery targets |
| Subnet tiers | Public (load balancer, NAT), private app (EC2), isolated data (RDS) | Nothing holding PHI has a route to or from the internet |
| Outbound internet | One NAT gateway per AZ in Prod, one total in Dev | Per-AZ NAT avoids a cross-AZ single point of failure; Dev trades that for cost |
| Private service access | VPC endpoints for S3, HealthImaging, Secrets Manager, and Systems Manager | AWS API traffic stays on the AWS network instead of crossing the internet |
| Security groups | Tier-to-tier only: ALB → app on 443, app → RDS on 5432 | Least privilege at the network layer; a compromised web server can't reach anything else |
| Clinic connectivity | Site-to-Site VPN from each clinic to a virtual private gateway | Encrypted links using the clinics' existing internet; Transit Gateway is the growth path past 10 sites |

### Edge

| Foundation | Choice | Why |
|---|---|---|
| DNS | Route 53 | Health-checked DNS that can fail over to the DR region |
| CDN | CloudFront | Caches portal static content close to patients and shields the origin |
| Web firewall | AWS WAF with AWS managed rule sets | Blocks common attacks (SQL injection, cross-site scripting) before they reach the app |
| DDoS | AWS Shield Standard | Free and automatic for CloudFront and Route 53 |
| TLS certificates | AWS Certificate Manager | Free certificates that renew themselves, so encryption in transit never lapses |

### Compute

| Foundation | Choice | Why |
|---|---|---|
| App tier | EC2 in an Auto Scaling group across both AZs | The EHR vendor's software needs a full OS; Auto Scaling replaces failed instances and adds capacity |
| Load balancing | Application Load Balancer | HTTPS termination, health checks, and spreading traffic across AZs |
| Server access | Systems Manager Session Manager, no SSH | No inbound port 22, no keys to lose, every session logged |
| Patching | Systems Manager Patch Manager | Scheduled, reported patching; we own the OS under shared responsibility |
| Images | Hardened AMI built once and reused | Every instance starts from the same known-good baseline |

### Database

| Foundation | Choice | Why |
|---|---|---|
| Engine | Amazon RDS for PostgreSQL | Managed backups, patching, and failover; no SQL Server licensing cost |
| Availability | Multi-AZ | Synchronous standby in the second AZ with automatic failover |
| Encryption | KMS customer managed key | At-rest encryption with a key we control and can audit |
| Credentials | Secrets Manager with rotation | No passwords in code or config files |
| Backups | Automated backups, replicated to us-west-2 | Point-in-time restore locally and in the DR region |

### Storage and imaging

| Foundation | Choice | Why |
|---|---|---|
| Documents | S3 with SSE-KMS, versioning, Block Public Access | Durable, encrypted, protected from accidental deletion and exposure |
| Retention | S3 Object Lock on records with legal retention periods | Records can't be altered or deleted before their retention date, even by admins |
| Document lifecycle | Move to Glacier Instant Retrieval after 90 days | Older documents are rarely opened but must stay available |
| Imaging store | **AWS HealthImaging** | Managed, DICOM-native, HIPAA-eligible; no PACS servers to patch (ADR) |
| Imaging ingest | DICOM router at each clinic: receives from devices, forwards to HealthImaging with DICOMweb STOW-RS over the VPN and TLS | Devices only speak classic DICOM, which is unencrypted; the router upgrades it to encrypted transport |
| Image viewing | Web viewer pulling over DICOMweb | Clinicians view images in a browser with nothing to install |
| Interoperability | HL7/FHIR noted, out of scope | Real EHRs exchange data this way, but it adds nothing to the rubric |

### Identity and access

| Foundation | Choice | Why |
|---|---|---|
| Admin access | IAM Identity Center with MFA, permission sets per role | One login for admins across accounts, short-lived credentials, no IAM users |
| Roles | Separate permission sets: Admin, Network, DBA, Read-only auditor | Separation of duties; no one person can change and approve |
| Workload identity | IAM roles on EC2 (instance profiles) | Apps get temporary credentials; no access keys on servers |
| Patient identity | Amazon Cognito for the portal | Patient sign-up, sign-in, and MFA without building it ourselves |
| Root user | MFA, no access keys, locked away | The root user can't be restricted by policy, so it's never used day to day |

### Security monitoring and detection

| Foundation | Choice | Why |
|---|---|---|
| Audit trail | Organization CloudTrail to the Security account | Every API call recorded where workload admins can't delete it |
| Threat detection | GuardDuty | Flags compromised credentials, crypto mining, and unusual access |
| Posture | Security Hub with the HIPAA and AWS Foundational standards | One score and finding list across every account |
| Configuration | AWS Config with a HIPAA conformance pack | Detects drift, such as a bucket going public or encryption being disabled |
| Vulnerabilities | Amazon Inspector | Scans EC2 instances for known CVEs |
| PHI discovery | Amazon Macie on S3 | Finds PHI sitting somewhere it shouldn't be |
| Alerting | CloudWatch alarms → SNS email | The IT team hears about problems without watching a console |

### Shared Responsibility Model

| Layer | AWS | Bayou Clinic Partners |
|---|---|---|
| Physical data centers, hardware, network backbone | ✅ | |
| Hypervisor and managed service infrastructure | ✅ | |
| RDS engine patching, HealthImaging platform | ✅ | |
| EC2 operating system and app patching | | ✅ |
| IAM users, roles, and permissions | | ✅ |
| Security groups, network design | | ✅ |
| Encryption settings and key policies | | ✅ |
| Data classification and PHI handling | | ✅ |

The line moves with the service: on EC2 we patch the OS, on RDS AWS does, and on HealthImaging AWS runs the whole platform. That shift is one reason the design prefers managed services.

### High availability and scaling

| Foundation | Choice | Why |
|---|---|---|
| App scaling | Target tracking on ALB requests per instance | Adds instances as clinic traffic rises, removes them when it falls |
| Scheduled scaling | Scale up at 6:30 AM, down at 7:30 PM | Clinic hours are predictable, so capacity is ready before the rush |
| Health checks | ALB health checks feed Auto Scaling | A failed instance is replaced, not just routed around |
| Database reads | RDS read replica if reporting load grows | Keeps reports from slowing down clinicians |
| DR | AWS Backup cross-region copies, Route 53 failover | Restores in us-west-2 within the recovery targets |

### Cost

| Foundation | Choice | Why |
|---|---|---|
| Estimate | AWS Pricing Calculator, saved in [`cost/`](cost) | Gives stakeholders a monthly number before anything is built |
| Baseline compute | Compute Savings Plan for the always-on minimum | Up to about two thirds off on-demand for capacity we'll always use |
| Right-sizing | Compute Optimizer reviewed monthly | Catches oversized instances |
| Dev environment | Scheduled off nights and weekends | Dev doesn't need to run when nobody is working |
| Storage tiers | S3 lifecycle; HealthImaging's automatic archive tier | Old documents and images cost less without anyone moving them |
| Monitoring | AWS Budgets alerts, Cost Explorer, cost allocation tags | Spend is visible per clinic, with alerts before it overruns |

### Migration

| Workload | Strategy | Tool | Why |
|---|---|---|---|
| EHR app servers | Replatform onto EC2 Auto Scaling | AWS Application Migration Service, then rebuild on the hardened AMI | Moves fast, then gains scaling and HA |
| EHR database | Replatform to RDS | AWS DMS (Database Migration Service) with ongoing replication | Keeps the source live until cutover, keeping downtime short |
| File shares | Rehost to S3 | AWS DataSync | Scheduled, verified, encrypted transfer |
| Imaging archive | Bulk import | DataSync to S3, then HealthImaging import jobs | Images move once in bulk; the clinic routers handle new ones |
| Cutover | One pilot clinic, then the remaining seven in waves | | Problems surface at one site, not eight |

## 3. Environments

| Environment | Purpose | Differences from Prod |
|---|---|---|
| **Prod** | Patient-facing | Full HA, per-AZ NAT, Multi-AZ RDS, Savings Plan |
| **Dev** | Testing changes | Single NAT, single-AZ RDS, scheduled off, synthetic data only |
| **Security** | Logs and security tooling | No workloads; CloudTrail, Config, and Security Hub aggregation |

## 4. Infrastructure as code

| Foundation | Choice | Why |
|---|---|---|
| Primary IaC | Terraform | Most requested in job postings, and builds the full design repeatably |
| State | Remote S3 backend, encrypted, with locking | State holds resource details and can hold secrets; it never goes in Git |
| Comparison | CloudFormation and AWS CDK for the network layer | Shows the same build three ways for the alternatives slide |
| Security scanning | Checkov on all IaC | Catches misconfigurations, such as an unencrypted bucket, before deploy |

## 5. Live deploy slice

Built from the Terraform, verified, screenshotted, destroyed. Capped at $20.

| In the slice | Left out | Why left out |
|---|---|---|
| VPC, three subnet tiers, two AZs, one NAT | Organizations, VPN, Route 53, CloudFront | Account-level or need a domain and clinic hardware |
| ALB + Auto Scaling group (t3.micro) | HealthImaging | No sample imaging pipeline needed to prove the network and HA |
| RDS PostgreSQL, Multi-AZ, encrypted | Macie, Inspector, Security Hub | Costs add up quickly; covered in the design |
| S3 with KMS, versioning, Block Public Access | | |
| CloudTrail, GuardDuty, billing alarm | | |

**Proof points:** load the app through the ALB, terminate an instance and watch Auto Scaling replace it, force an RDS failover, show S3 encryption and blocked public access, show CloudTrail recording the test.

## 6. Architecture decision records

| ADR | Decision | Alternative compared |
|---|---|---|
| 001 | EC2 Auto Scaling for the app tier | AWS Lambda (serverless) |
| 002 | RDS for PostgreSQL | Self-managed database on EC2 |
| 003 | AWS HealthImaging for imaging | PACS software on EC2 with S3 |
| 004 | Multi-account with Organizations | Single account |
| 005 | Backup-and-restore DR | Pilot light / warm standby |
| 006 | Site-to-Site VPN | AWS Direct Connect |
| 007 | Terraform as primary IaC | CloudFormation, AWS CDK |

## 7. Rubric coverage

| Rubric area | Points | Covered by |
|---|---|---|
| Architecture design | 25 | Sections 2–3 |
| Visual diagram | 25 | [`diagrams/`](../diagrams) |
| Security | 18 | Identity, monitoring, shared responsibility |
| High availability and scalability | 18 | HA and scaling, recovery targets |
| Cost optimization | 11 | Cost |
| Justification | 18 | ADRs, Section 6 |
| Presentation and delivery | 30 | [`presentation/`](../presentation) |

## 8. Schedule

| Week | Dates | Work |
|---|---|---|
| 1 | Oct 26 – Nov 1 | Requirements, shared responsibility map, cost estimate |
| 2 | Nov 2 – Nov 8 | ADRs, draw.io diagram |
| 3 | Nov 9 – Nov 15 | Terraform: network, security, identity |
| 4 | Nov 16 – Nov 22 | Terraform: compute, database, storage; CloudFormation and CDK network |
| 5 | Nov 23 – Nov 29 | Live deploy, verify, destroy (Thanksgiving week, light load) |
| 6 | Nov 30 – Dec 5 | Slide deck, rehearsal, recorded video, submit |
