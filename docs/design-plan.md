# Design Plan

The master plan for the Bayou Clinic Partners migration. Every foundation in the design is listed here with the reason it exists. Deeper reasoning for the biggest choices lives in [`adr/`](adr). The clinical workflow these choices support is in the [healthcare data primer](healthcare-data-primer.md).

**Status key:** ✅ Decided · 📝 Draft, under review

## 1. Scenario and assumptions ✅

| Item | Assumption |
|---|---|
| Organization | Bayou Clinic Partners (fictional), 8 outpatient clinics, about 400 staff |
| Flagship clinic | One clinic has the imaging suite and produces most X-ray and ultrasound studies |
| Workloads | Licensed vendor EHR with its patient portal and radiology (RIS) module, HL7 interface engine, document storage, medical imaging |
| Users | Clinic staff during business hours (7 AM–7 PM), remote staff and radiologists, patients on the portal at any hour |
| Data | PHI (protected health information) in the database, documents, HL7 messages, DICOM images, and some logs |
| Compliance | HIPAA; a BAA (business associate agreement) is signed with AWS before any PHI moves. Card payments for copays bring PCI DSS into scope for billing |
| Clinic sites | Each clinic keeps its imaging devices, a DICOM router, and a firewall; everything else moves to AWS |

### Recovery targets 📝

RTO (recovery time objective) is how long a system can be down. RPO (recovery point objective) is how much data can be lost, measured in time.

| Failure | RTO | RPO | How |
|---|---|---|---|
| Single server | Minutes | None | Auto Scaling replaces it behind the load balancer |
| Availability Zone | Minutes | Near zero | Every tier runs in three AZs; Multi-AZ RDS fails over automatically |
| Whole region | 24 hours | 1 hour | Restore into us-east-1 |

## 2. Account structure and governance ✅

| Foundation | Choice | Why |
|---|---|---|
| Landing zone | AWS Control Tower, home region us-west-2 | AWS's managed way to build a secure multi-account setup with guardrails and central logging; the home region can't change later |
| Accounts | **Management**, **Log Archive**, **Audit**, **Network**, **Shared Services**, **Prod**, **Staging**, **Dev** | Mirrors AWS's reference structure: each account is a hard boundary for permissions, billing, and blast radius |
| Management account | Billing and organization admin only, no workloads | Service control policies don't apply to it, so nothing runs there |
| Log Archive | Receives CloudTrail, Config, VPC Flow, and firewall logs from every account | Logs live where no workload admin can delete them, which is what makes them audit evidence |
| Audit | Security tooling (Security Hub, GuardDuty administrator) | Security team visibility across every account without workload access |
| Network | Transit Gateway, Direct Connect, VPNs, egress VPC, Network Firewall | One team and one place own connectivity and inspection |
| Shared Services | Centralized VPC interface endpoints, shared DNS resolvers | Shared plumbing paid for once |
| Guardrails | Control Tower controls and service control policies (SCPs) | SCPs cap what any account can do. They never grant permissions |
| Region guardrail | Only us-west-2 and us-east-1 allowed | Keeps PHI in US regions by policy and shrinks the attack surface; us-east-1 stays allowed because global services and CloudFront certificates need it |
| BAA | Accepted in AWS Artifact | HIPAA requires it before PHI is stored in AWS |
| HIPAA-eligible services only | Every PHI-touching service checked against AWS's eligible list | A non-eligible service handling PHI breaks compliance even if it's configured well |

## 3. Data classification and tagging ✅

### Classification

| Tier | What it covers | Examples |
|---|---|---|
| `public` | Meant for anyone | Clinic hours, portal sign-in page |
| `internal` | Business data, no personal records | Network configs, runbooks |
| `confidential` | Sensitive business or staff data | Staff HR records, contracts, financial reports |
| `restricted` | PHI and anything that can contain it | EHR database, DICOM images, HL7 messages, documents, logs and backups of those |

A second tag, `Compliance` (`hipaa`, `pci`, `none`), says which rulebook applies. Sensitivity and regulatory scope are separate questions, so they're separate tags.

### Rules

| Rule | Why |
|---|---|
| **High-water mark**: a resource takes the label of the most sensitive data in it | One PHI table makes the whole database PHI |
| **Copies inherit**: logs, snapshots, and backups take the label of what they record | A backup of PHI is PHI; a URL with an accession number in it makes a log PHI |
| **No PHI in tags**: tags describe categories, never people | Tags appear in billing reports and CloudTrail |
| **Labels are verified, not trusted** | Amazon Macie scans S3 for PHI in places not labeled `restricted` |

### Enforcement: prevent and detect

| Layer | Control | Effect |
|---|---|---|
| Standardize | Organizations tag policy | Only allowed keys and values, so `prod` never becomes `Prod` or `production` |
| Prevent | SCP denies creating data-holding resources without `DataClass` | S3 buckets, RDS, EC2, EBS, KMS keys, and the HealthImaging data store can't exist unlabeled. Scoped to these types because some AWS-created resources can't be tagged at creation |
| Detect | AWS Config required-tags rule | Flags drift and produces audit evidence |
| Control access | ABAC (attribute-based access control) on `restricted` | IAM checks the resource's `DataClass` tag against the person's role, enforcing HIPAA's minimum necessary rule |

### Tag set

| Tag | Example values | Read by |
|---|---|---|
| `Environment` | `prod`, `staging`, `dev` | SCPs and IAM, cost reports |
| `Owner` | `it-infra`, `radiology-apps` | People during incidents and cleanup |
| `CostCenter` | `clinic-flagship`, `clinic-north`, `shared` | Cost per clinic |
| `Application` | `ehr`, `portal`, `imaging`, `interface-engine` | Cost and ownership per system |
| `DataClass` | `public`, `internal`, `confidential`, `restricted` | SCP, IAM ABAC, Config, Macie |
| `Compliance` | `hipaa`, `pci`, `none` | Audit scoping |
| `BackupPolicy` | `daily-35d`, `none` | AWS Backup selects resources by this tag |
| `ManagedBy` | `terraform`, `manual` | Config flags `manual` resources in Prod as undocumented drift |

## 4. Regions ✅

| Foundation | Choice | Why |
|---|---|---|
| Primary | us-west-2 (Oregon) | Historically more stable than us-east-1; has HealthImaging and Control Tower. Trade-off: roughly double the latency from Louisiana, offset by CloudFront for the portal |
| Disaster recovery | us-east-1 (N. Virginia) | The only other US region with HealthImaging, so imaging can be restored in a regional disaster |
| Why not us-east-2 | No HealthImaging | Imaging would have to live in a different region from everything else |

## 5. Network ✅

### VPC foundation

| Foundation | Choice | Why |
|---|---|---|
| IP plan | AWS VPC IPAM with pools per region and environment; clinic range `10.20.0.0/16` reserved | Overlapping ranges break routing and can't be fixed without a rebuild; IPAM makes overlap impossible across accounts |
| Availability Zones | Three, in every environment | Survives an AZ outage and still has redundancy; Staging and Dev behave like Prod, so tests there prove something |
| Workload VPC tiers | **App** · **Integration** · **Data**, one subnet per AZ (9 subnets) | The integration tier fences off the interface engine, which talks to every system and the clinics. No public tier: the load balancer is private and NAT is centralized, so no VPC holding PHI has an internet gateway |
| Egress VPC (Network account) | Public subnets for NAT, firewall subnets for Network Firewall | The only place in the organization with an internet door |

### Connectivity

| Foundation | Choice | Why |
|---|---|---|
| Hub | Transit Gateway in the Network account, shared by AWS RAM; a second Transit Gateway in us-east-1 for DR | Every VPC and clinic connects once; TGW route tables keep Prod, Staging, and Dev unable to see each other |
| Flagship clinic | Direct Connect through a carrier partner, with Site-to-Site VPN running over it, plus an internet VPN as backup | Steady, fast link where the imaging volume is. Direct Connect is private but not encrypted, so the VPN on top supplies encryption; one circuit is a single point of failure, so the internet VPN backs it up |
| Other seven clinics | Site-to-Site VPN (two tunnels each) | Encrypted, uses existing internet, enough for occasional studies. Direct Connect is the upgrade path if a clinic adds CT |
| Internet egress | Centralized egress VPC with three NAT gateways and AWS Network Firewall allowing only approved domains | NAT only blocks inbound connections; the allow-list stops a compromised server from sending PHI to an attacker's site |
| AWS service access | S3 gateway endpoints in every VPC (free); interface endpoints (HealthImaging, Secrets Manager, Systems Manager, and others) centralized in Shared Services with Route 53 Resolver | AWS API traffic, including PHI, never crosses the internet; interface endpoint cost is paid once |

### Traffic filtering

| Foundation | Choice | Why |
|---|---|---|
| Model | Security groups + baseline NACLs + Network Firewall inspection on Transit Gateway traffic | Defense in depth: firewall inspection on clinic → AWS and VPC → VPC paths catches lateral movement; NACLs block a mistaken security group at the subnet edge |
| Inspection exception | Large imaging uploads may bypass deep inspection if cost requires it | A deliberate, documented cost trade-off |
| NACL scope | Tier boundaries only (e.g., data subnets accept only app and integration subnets) | NACLs are stateless; keeping them coarse avoids the dropped-reply outage |
| Security group style | Reference other security groups tier-to-tier; CIDR ranges only for things outside AWS | Rules follow servers as they scale; least privilege |

### Flow matrix

| From | To | Port | Why |
|---|---|---|---|
| CloudFront (VPC origin) | Load balancer SG | 443 | Web traffic only through CloudFront and WAF |
| Verified Access | Load balancer SG | 443 | Remote staff reach the EHR after identity and device checks |
| Load balancer SG | App SG | 443 | EHR and portal |
| Clinic ranges | Integration SG | 2575 (HL7 over TLS) | Clinic systems to the interface engine |
| App SG | Integration SG | 2575 | EHR to interface engine |
| App SG, Integration SG | Data SG | 5432 | PostgreSQL |
| Clinic DICOM routers | HealthImaging endpoint (Shared Services) | 443 | DICOMweb STOW-RS image uploads |
| All private tiers | VPC endpoints | 443 | AWS APIs, privately |
| Clinics or internet | Data tier | None | Never |

## 6. Edge ✅

| Foundation | Choice | Why |
|---|---|---|
| What's public | Patient portal only | The clinical system is never published to the internet |
| Remote staff | AWS Verified Access with IAM Identity Center and device checks | Zero trust: a verified user on a healthy device gets one app, not a network. Client VPN was the alternative |
| DNS | Route 53 public and private hosted zones, health checks, failover routing to us-east-1 | Name resolution that follows the system into the DR region |
| CDN and origin | CloudFront with VPC origins to a private load balancer | The load balancer has no public address, so nothing can go around CloudFront and WAF |
| Web firewall | AWS WAF: managed rule groups, rate limits on the portal login, Bot Control | Credential stuffing on the patient login is the most likely attack |
| Geo-blocking | Not used | Patients travel; blocking abroad cuts them off from their own records |
| DDoS | AWS Shield Standard | Free and automatic. Shield Advanced costs about $36,000 a year, out of proportion for 8 clinics |
| TLS certificates | AWS Certificate Manager, CloudFront certificates in us-east-1 | Free, auto-renewing encryption in transit |

## 7. Compute

### What runs, and where ✅

| Workload | Choice | Why |
|---|---|---|
| EHR and patient portal | The clinic's licensed vendor EHR, replatformed: app servers to EC2, database to RDS; the portal is the EHR's built-in module | Vendor software can't be rewritten; managed services go around it. A SaaS EHR was rejected because it leaves little control over PHI hosting and integration |
| RIS and modality worklist | The EHR's radiology module | Outpatient X-ray and ultrasound don't need a separate RIS; fewer systems means fewer interfaces to secure. HealthImaging stores images but doesn't schedule exams |
| Interface engine | Integration tier | Routes HL7 to labs, billing, and partners; isolated because it can read every message |
| DICOM ingest | Store-and-forward router at each clinic, sending STOW-RS straight to HealthImaging over Direct Connect or VPN | A broken link delays images instead of stopping exams; unencrypted classic DICOM never leaves the clinic LAN |

### How it runs 📝

| Foundation | Choice | Why |
|---|---|---|
| App tier | EC2 in an Auto Scaling group across three AZs | The EHR vendor's software needs a full OS; Auto Scaling replaces failed instances and adds capacity |
| Load balancing | Private Application Load Balancer | HTTPS termination, health checks, and spreading traffic across AZs |
| Server access | Systems Manager Session Manager, no SSH | No inbound port 22, no keys to lose, every session logged |
| Patching | Systems Manager Patch Manager | We own the OS under shared responsibility |
| Images | Hardened AMI built once and reused | Every instance starts from the same known-good baseline |

## 8. Database 📝

| Foundation | Choice | Why |
|---|---|---|
| Engine | Amazon RDS for PostgreSQL | Managed backups, patching, and failover; no SQL Server licensing cost |
| Availability | Multi-AZ | Synchronous standby with automatic failover |
| Encryption | KMS customer managed key | At-rest encryption with a key we control and can audit |
| Credentials | Secrets Manager with rotation | No passwords in code or config files |
| Backups | Automated backups, replicated to us-east-1 | Point-in-time restore locally and in the DR region |

## 9. Storage and imaging 📝

| Foundation | Choice | Why |
|---|---|---|
| Documents | S3 with SSE-KMS, versioning, Block Public Access | Durable, encrypted, protected from accidental deletion and exposure |
| Retention | S3 Object Lock on records with legal retention periods | Records can't be altered or deleted before their retention date |
| Document lifecycle | Glacier Instant Retrieval after 90 days | Older documents are rarely opened but must stay available |
| Imaging store | AWS HealthImaging ✅ | Managed, DICOM-native, HIPAA-eligible; no PACS servers to patch |
| Image viewing | Web viewer pulling over DICOMweb | Clinicians view images in a browser with nothing to install |
| Interoperability | HL7/FHIR beyond the interface engine out of scope | Adds nothing to the rubric |

## 10. Identity and access 📝

| Foundation | Choice | Why |
|---|---|---|
| Admin access | IAM Identity Center with MFA, permission sets per role | One login across accounts, short-lived credentials, no IAM users |
| Roles | Separate permission sets: Admin, Network, DBA, Read-only auditor | Separation of duties |
| Workload identity | IAM roles on EC2 (instance profiles) | Temporary credentials; no access keys on servers |
| Patient identity | Amazon Cognito for the portal | Patient sign-up, sign-in, and MFA without building it |
| Root user | MFA, no access keys, locked away | The root user can't be restricted by policy |

## 11. Security monitoring 📝

| Foundation | Choice | Why |
|---|---|---|
| Audit trail | Organization CloudTrail to Log Archive | Every API call recorded where workload admins can't delete it |
| Threat detection | GuardDuty | Flags compromised credentials, crypto mining, unusual access |
| Posture | Security Hub with HIPAA and AWS Foundational standards | One score and finding list across every account |
| Configuration | AWS Config with a HIPAA conformance pack | Detects drift, such as a bucket going public |
| Vulnerabilities | Amazon Inspector | Scans EC2 instances for known CVEs |
| PHI discovery | Amazon Macie on S3 | Finds PHI where it isn't labeled |
| Alerting | CloudWatch alarms → SNS | The IT team hears about problems without watching a console |

## 12. Shared Responsibility Model 📝

| Layer | AWS | Bayou Clinic Partners |
|---|---|---|
| Physical data centers, hardware, network backbone | ✅ | |
| Hypervisor and managed service infrastructure | ✅ | |
| RDS engine patching, HealthImaging platform | ✅ | |
| EC2 operating system and app patching | | ✅ |
| IAM, security groups, network design | | ✅ |
| Encryption settings and key policies | | ✅ |
| Data classification and PHI handling | | ✅ |
| Clinic DICOM routers and firewalls | | ✅ |

## 13. High availability and scaling 📝

| Foundation | Choice | Why |
|---|---|---|
| App scaling | Target tracking on load balancer requests per instance | Adds instances as traffic rises, removes them as it falls |
| Scheduled scaling | Scale up at 6:30 AM, down at 7:30 PM | Clinic hours are predictable |
| Health checks | Load balancer health checks feed Auto Scaling | A failed instance is replaced, not just routed around |
| Database reads | RDS read replica if reporting load grows | Reports don't slow down clinicians |
| DR | AWS Backup cross-region copies to us-east-1, Route 53 failover | Restores within the recovery targets |

## 14. Cost 📝

| Foundation | Choice | Why |
|---|---|---|
| Estimate | AWS Pricing Calculator, saved in [`cost/`](cost) | A monthly number before anything is built |
| Baseline compute | Compute Savings Plan for the always-on minimum | Large discount for capacity always in use |
| Right-sizing | Compute Optimizer reviewed monthly | Catches oversized instances |
| Non-prod | Dev scheduled off nights and weekends | Recovers part of the three-AZ cost |
| Storage tiers | S3 lifecycle; HealthImaging's automatic archive tier | Old data costs less without anyone moving it |
| Security spend | Network Firewall and Verified Access called out as deliberate costs | Shows what security costs and why it's worth it |
| Monitoring | AWS Budgets alerts, Cost Explorer, cost allocation tags | Spend visible per clinic and application |

## 15. Migration 📝

| Workload | Strategy | Tool | Why |
|---|---|---|---|
| EHR app servers | Replatform onto EC2 Auto Scaling | AWS Application Migration Service, then rebuild on the hardened AMI | Moves fast, then gains scaling and HA |
| EHR database | Replatform to RDS | AWS DMS with ongoing replication | Source stays live until cutover |
| File shares | Rehost to S3 | AWS DataSync | Scheduled, verified, encrypted transfer |
| Imaging archive | Bulk import | DataSync to S3, then HealthImaging import jobs | Images move once in bulk; clinic routers handle new ones |
| Cutover | Flagship clinic first, then the remaining seven in waves | | Problems surface at one site, not eight |

## 16. Environments

| Account | Purpose | Status |
|---|---|---|
| **Prod** | Patient-facing | ✅ |
| **Staging** | Dress rehearsal for changes; same shape as Prod | ✅ |
| **Dev** | Building and testing; synthetic or de-identified data only | ✅ |
| Differences between them | Instance sizes, schedules, Savings Plans | 📝 Decided in the cost layer |

## 17. Infrastructure as code

| Foundation | Choice | Why |
|---|---|---|
| Primary IaC ✅ | Terraform | Most requested in job postings; builds the full design repeatably |
| Comparison ✅ | CloudFormation and AWS CDK for the network layer, written but not deployed | The class covers both; the same build three ways supports the alternatives discussion |
| State 📝 | Remote S3 backend, encrypted, with locking | State holds resource details and can hold secrets; it never goes in Git |
| Security scanning 📝 | Checkov on all IaC | Catches misconfigurations before deploy |

## 18. Live deploy slice 📝

Built from the Terraform in us-west-2, verified, screenshotted, destroyed. Capped at $20.

| In the slice | Left out | Why left out |
|---|---|---|
| VPC with app, integration, and data tiers across three AZs | Control Tower, Direct Connect, VPN, Verified Access | Account-level, need clinic hardware, or cost too much for a slice |
| Private load balancer + Auto Scaling group (t3.micro) | HealthImaging, Network Firewall | Not needed to prove network and HA; Network Firewall alone would exceed the budget |
| RDS PostgreSQL, Multi-AZ, encrypted | Macie, Inspector, Security Hub | Covered in the design |
| S3 with KMS, versioning, Block Public Access | | |
| CloudTrail, GuardDuty, billing alarm | | |

Open question: NAT for the slice (three per-AZ NAT gateways vs. one shared, as a documented exception).

**Proof points:** reach the app through the load balancer, terminate an instance and watch Auto Scaling replace it, force an RDS failover, show S3 encryption and blocked public access, show CloudTrail recording the test.

## 19. Architecture decision records

| ADR | Decision | Alternative compared | Status |
|---|---|---|---|
| 001 | Replatform the vendor EHR onto EC2 and RDS | SaaS EHR | ✅ |
| 002 | RDS for PostgreSQL | Self-managed database on EC2 | 📝 |
| 003 | AWS HealthImaging | PACS software on EC2 with S3 | ✅ |
| 004 | Multi-account landing zone with Control Tower | Single account | ✅ |
| 005 | DR strategy | Pilot light / warm standby | 📝 |
| 006 | Hybrid Direct Connect + VPN | VPN only, Direct Connect everywhere | ✅ |
| 007 | Terraform as primary IaC | CloudFormation, AWS CDK | ✅ |
| 008 | AWS Verified Access for remote staff | AWS Client VPN | ✅ |
| 009 | Centralized egress with Network Firewall | NAT gateways in every VPC | ✅ |
| 010 | us-west-2 primary, us-east-1 DR | us-east-1 primary | ✅ |

## 20. Rubric coverage

| Rubric area | Points | Covered by |
|---|---|---|
| Architecture design | 25 | Sections 2–9, 16 |
| Visual diagram | 25 | [`diagrams/`](../diagrams) |
| Security | 18 | Sections 3, 5, 6, 10–12 |
| High availability and scalability | 18 | Sections 1, 5, 13 |
| Cost optimization | 11 | Section 14 |
| Justification | 18 | Section 19 and the ADRs |
| Presentation and delivery | 30 | [`presentation/`](../presentation) |

## 21. Schedule 📝

| Week | Dates | Work |
|---|---|---|
| 1 | Oct 26 – Nov 1 | Design review, shared responsibility map, cost estimate |
| 2 | Nov 2 – Nov 8 | ADRs, draw.io diagram |
| 3 | Nov 9 – Nov 15 | Terraform: network, security, identity |
| 4 | Nov 16 – Nov 22 | Terraform: compute, database, storage; CloudFormation and CDK network |
| 5 | Nov 23 – Nov 29 | Live deploy, verify, destroy (Thanksgiving week, light load) |
| 6 | Nov 30 – Dec 5 | Slide deck, rehearsal, recorded video, submit |
