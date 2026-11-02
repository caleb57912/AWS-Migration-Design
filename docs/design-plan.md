# Design Plan

The master plan for the Bayou Clinic Partners migration. Every foundation in the design is listed here with the reason it exists. Deeper reasoning for the biggest choices lives in [`adr/`](adr). The clinical workflow these choices support is in the [healthcare data primer](healthcare-data-primer.md).

**Status:** ✅ All layers decided (layers 1–5.1 chosen option by option; later layers adopted from recommendations)

## 1. Scenario and assumptions ✅

| Item | Assumption |
|---|---|
| Organization | Bayou Clinic Partners (fictional), 8 outpatient clinics, about 400 staff |
| Flagship clinic | One clinic has the imaging suite and produces most X-ray and ultrasound studies |
| Workloads | Licensed vendor EHR (certified on PostgreSQL) with its patient portal and radiology (RIS) module, HL7 interface engine, document storage, medical imaging |
| Users | Clinic staff during business hours (7 AM–7 PM), remote staff and radiologists, patients on the portal at any hour |
| Data | PHI (protected health information) in the database, documents, HL7 messages, DICOM images, and some logs |
| Compliance | HIPAA; a BAA (business associate agreement) is signed with AWS before any PHI moves. Card payments for copays bring PCI DSS into scope for billing |
| Clinic sites | Each clinic keeps its imaging devices, a DICOM router, and a firewall; everything else moves to AWS |
| Workforce | Clinic runs Microsoft 365, so Microsoft Entra ID is the identity provider |
| On-prem database | Already PostgreSQL, so the database move is homogeneous |

### Recovery targets ✅

RTO (recovery time objective) is how long a system can be down. RPO (recovery point objective) is how much data can be lost, measured in time. Full tiers are in [section 13](#13-high-availability-scaling-and-dr-).

| Failure | RTO | RPO | How |
|---|---|---|---|
| Single server | Minutes | None | Auto Scaling replaces it behind the load balancer |
| Availability Zone | Minutes | Near zero | Every tier runs in three AZs with static stability |
| Whole region (EHR) | 4 hours | 1 minute | Pilot light in us-east-1 with Aurora Global Database |
| Whole region (imaging) | 24 hours | 15 minutes | Re-import from the replicated S3 archive |

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

## 7. Compute ✅

### What runs, and where

| Workload | Choice | Why |
|---|---|---|
| EHR and patient portal | The clinic's licensed vendor EHR, replatformed: app servers to EC2, database to RDS; the portal is the EHR's built-in module | Vendor software can't be rewritten; managed services go around it. A SaaS EHR was rejected because it leaves little control over PHI hosting and integration |
| RIS and modality worklist | The EHR's radiology module | Outpatient X-ray and ultrasound don't need a separate RIS; fewer systems means fewer interfaces to secure. HealthImaging stores images but doesn't schedule exams |
| Interface engine | Integration tier | Routes HL7 to labs, billing, and partners; isolated because it can read every message |
| DICOM ingest | Store-and-forward router at each clinic, sending STOW-RS straight to HealthImaging over Direct Connect or VPN | A broken link delays images instead of stopping exams; unencrypted classic DICOM never leaves the clinic LAN |

### How it runs ✅

| Foundation | Choice | Why | Alternative rejected |
|---|---|---|---|
| EHR app tier | EC2 Auto Scaling group across three AZs behind the private ALB | Vendor EHRs need a full OS and certified server specs | ECS/Fargate containers, Lambda |
| Interface engine | Two EC2 nodes, active/passive across AZs, behind an internal NLB on port 2575 | HL7 over MLLP is raw TCP, which an ALB can't carry; active/passive keeps message order, which matters for patient safety | One self-healing instance |
| Instance family | x86 general purpose (`m7i`) | Clinical vendors certify on x86 | Graviton (ARM) |
| Server images | Golden AMI built monthly by EC2 Image Builder from a CIS-hardened baseline | Every server starts from the same tested, hardened image | Hand-built servers |
| Patching | App tier is immutable (new AMI, then instance refresh); interface engine patched in place with Patch Manager, passive node first | Stateless servers are safe to replace; the engine holds queued messages | Patching everything in place |
| Server access | Systems Manager Session Manager only; sessions logged to Log Archive | No open admin ports, no SSH keys, full command audit trail | Bastion host with SSH |
| Disk encryption | EBS encryption on by default at the account level | No unencrypted disk can be created, even by mistake | Per-volume encryption |
| Server protection | EDR agent on every instance plus GuardDuty Runtime Monitoring | The OS is ours to protect under shared responsibility | Inspector alone |

## 8. Database ✅

| Foundation | Choice | Why | Alternative rejected |
|---|---|---|---|
| Engine | Aurora PostgreSQL; the vendor EHR is assumed certified on PostgreSQL | Storage keeps six copies across three AZs; failover typically under a minute | RDS PostgreSQL Multi-AZ, self-managed on EC2 |
| Topology | One writer and one reader in different AZs | The reader serves reports and is the failover target | Writer only |
| Encryption | KMS customer managed key per environment, set at creation; TLS required (`rds.force_ssl`) | At rest and in transit; Prod's key can't decrypt Dev's data | AWS-managed default key |
| Credentials | Secrets Manager with automatic rotation | No passwords in code, config, or AMIs | Credentials in config files |
| Placement | Data tier only; no public access; port 5432 from app and integration SGs only; deletion protection | Defense in depth around the PHI store | Defaults |
| Backups | 35-day automated backups, AWS Backup with Vault Lock, copy to us-east-1 | Point-in-time restore; backups attackers can't delete; DR copy | Automated backups only |
| Query auditing | pgAudit to CloudWatch, shipped to Log Archive | Proves who queried which patient records | No query auditing |

## 9. Storage and imaging ✅

| Foundation | Choice | Why | Alternative rejected |
|---|---|---|---|
| Documents | S3 with SSE-KMS (per-environment key), Bucket Keys, versioning | Every access is key-controlled and logged; Bucket Keys cut KMS cost | SSE-S3 |
| Public access | Block Public Access at the account level; bucket policies deny non-TLS requests and non-KMS uploads | Nothing can be made public by mistake; encryption enforced by policy | Per-bucket settings |
| Clinical record retention | Object Lock, governance mode, retention per record type under state law | Records can't be altered early, but a wrong retention can be corrected by a tightly controlled admin | Compliance mode |
| Audit log retention | Object Lock, compliance mode, 6 years, in Log Archive | Logs are evidence; even a compromised admin can't erase them | Governance mode |
| Document lifecycle | S3 Intelligent-Tiering | Access to old records is unpredictable; no retrieval surprises | Fixed lifecycle to Glacier |
| Imaging store | One HealthImaging data store per environment, CMK-encrypted, automatic archive tiering | Managed, DICOM-native, HIPAA-eligible; old studies cost less but stay instant | PACS software on EC2 with S3 |
| Imaging archive copy | Clinic routers also write each study to an S3 archive bucket, replicated to us-east-1 (Glacier Deep Archive) | Vendor-neutral copy and the imaging DR source | Relying on single-region storage |
| Image viewing | OHIF web viewer in the app tier behind the private ALB, launched from the EHR, reading over DICOMweb | Nothing to install; staff-only through clinics or Verified Access | Vendor PACS viewer |
| PHI discovery | Amazon Macie scheduled discovery on all buckets | Verifies the `DataClass` labels | Trusting labels |
| Migration staging | Temporary bucket for imaging import, deleted afterward | No lingering copies of PHI | Keeping the staging copy |

## 10. Identity and access ✅

| Foundation | Choice | Why | Alternative rejected |
|---|---|---|---|
| Workforce identity | Microsoft Entra ID federated to IAM Identity Center (SAML + SCIM) | Clinics already run Microsoft 365; one identity and one offboarding switch for email, EHR, AWS, and Verified Access | Identity Center's built-in directory |
| EHR staff login | Same Entra SSO with MFA | MFA everywhere PHI lives | Separate EHR accounts |
| Admin roles | Permission sets: Network Admin, DBA, Security Auditor (read-only), App Operator, Billing | Separation of duties | One shared admin set |
| Prod admin access | Just-in-time elevation with approval and expiry | No standing admin rights to steal | Permanent admin roles |
| Emergency access | Two break-glass users in Management, hardware MFA, alarm on any use | SSO outages happen; emergency access must be loud | No break-glass, or a quiet one |
| Root user | Centralized root access management; root credentials removed from member accounts | Root can't be limited by policy, so it shouldn't exist where it isn't needed | MFA on every root user |
| Workload identity | IAM roles for every workload; permissions boundaries on team-created roles | No access keys; no privilege escalation through role creation | IAM users with keys |
| PHI access | ABAC: Entra department and role flow into session tags checked against `DataClass` | Minimum necessary, enforced by labels | Per-resource allow lists |
| Patient identity | The EHR portal's built-in sign-in with MFA, behind WAF login rate limits | The portal is the vendor's module and brings its own identity | Amazon Cognito (the choice for a custom-built portal) |
| Access review | IAM Access Analyzer org-wide: external and unused access | Catches accidental sharing and unused permissions | Manual reviews |

## 11. Security monitoring and response ✅

| Foundation | Choice | Why | Alternative rejected |
|---|---|---|---|
| API audit | Organization CloudTrail: management events everywhere, data events on PHI buckets and HealthImaging, to Log Archive | Proves who accessed PHI, not just who changed infrastructure | Management events only |
| Network logs | VPC Flow Logs, Network Firewall logs, Route 53 Resolver query logs, WAF logs | Who connected, what was blocked, what was looked up, what attacked the front door | Firewall logs only |
| App logs | Load balancer and CloudFront access logs, pgAudit, OS logs; all `restricted` | URLs can carry accession numbers, so logs inherit PHI classification | Treating logs as internal |
| Threat detection | GuardDuty org-wide from Audit: S3, RDS, Runtime, and Malware Protection | Compromised credentials, crypto mining, database brute force | Per-account setup |
| Posture | Security Hub from Audit: AWS Foundational Security Best Practices, CIS, NIST 800-53, PCI DSS | One prioritized finding list across eight accounts | Service-by-service consoles |
| HIPAA evidence | AWS Config HIPAA conformance pack + Audit Manager HIPAA framework | Continuous evidence instead of audit-time spreadsheets. Security Hub has no HIPAA standard | Manual evidence |
| SIEM and SOC | Security Lake (OCSF) in Log Archive feeding a SIEM, watched 24/7 by an MDR provider | A small IT team can't staff nights; OCSF keeps the SIEM swappable | Native consoles only, or an in-house SOC |
| Automated response | EventBridge + Lambda: page on-call, quarantine a compromised instance by swapping its security group, disable a leaked key | Containment in seconds | Alerts only |
| Vulnerabilities | Inspector org-wide, tied to Patch Manager compliance | Find, fix, and prove closure | Annual scans |

## 12. Shared Responsibility Model ✅

| Responsibility | EC2 (EHR, interface engine) | Aurora | S3 · HealthImaging | Verified Access · CloudFront · WAF |
|---|---|---|---|---|
| Physical facilities, hardware, network | AWS | AWS | AWS | AWS |
| Hypervisor / host OS | AWS | AWS | AWS | AWS |
| Guest OS patching | **BCP** | AWS | AWS | AWS |
| Database engine patching | n/a | AWS (BCP picks the window) | n/a | n/a |
| Application software | **EHR vendor** writes patches, **BCP** applies them | n/a | n/a | n/a |
| Network rules | **BCP** | **BCP** | **BCP** (bucket and endpoint policies) | **BCP** |
| Identity and access | **BCP** | **BCP** | **BCP** | **BCP** |
| Encryption settings and keys | **BCP** | **BCP** | **BCP** | **BCP** |
| Data and its classification | **BCP** | **BCP** | **BCP** | **BCP** |

Outside AWS: clinic routers, firewalls, workstations, and imaging devices belong to **BCP**; 24/7 monitoring belongs to the **MDR provider** under contract; carriers are conduits, and encryption over their circuits is **BCP's** job through the VPNs. AWS's side is evidenced with its SOC 2 and ISO reports from AWS Artifact.

### Business associate agreements

| Party | BAA needed? | Why |
|---|---|---|
| AWS | Yes | Stores and processes PHI |
| EHR vendor | Yes | Remote support access to the system holding PHI |
| MDR provider | Yes | Sees logs containing PHI |
| SIEM vendor (if SaaS) | Yes | Stores those logs |
| DICOM router vendor (if remotely managed) | Yes | Can access images in transit |
| Carriers | No | HIPAA conduit exception; traffic is encrypted |

## 13. High availability, scaling, and DR ✅

### Recovery tiers and targets

| Tier | Systems | AZ loss | Region loss RTO | Region loss RPO |
|---|---|---|---|---|
| 1 | EHR, database, interface engine | Automatic, minutes | 4 hours | 1 minute |
| 2 | Imaging archive | Automatic, minutes | 24 hours | 15 minutes |
| 3 | Reporting | Automatic, minutes | Best effort | Best effort |

### Foundations

| Foundation | Choice | Why | Alternative rejected |
|---|---|---|---|
| DR strategy | Pilot light in us-east-1 | Meets Tier 1 targets at a fraction of warm standby's cost | Backup and restore (too slow for the EHR), warm standby (double compute) |
| Database DR | Aurora Global Database secondary in us-east-1 | About one second of replication lag; promoted in minutes | Snapshot copies |
| App DR | Golden AMIs copied to us-east-1; Terraform builds the app tier on demand | Servers exist only when needed | Always-on standby servers |
| Network DR | Standby Transit Gateway; clinic firewalls pre-configured with standby VPN tunnels; Route 53 failover records | Paths already exist when disaster strikes | Building networking during the disaster |
| Imaging DR | Replicated S3 archive re-imported into a us-east-1 HealthImaging data store; clinic routers queue new studies meanwhile | Design doesn't depend on unconfirmed backup support for HealthImaging | Single-region durability |
| Static stability | App tier minimum one instance per AZ; any two AZs carry full clinic-hours load | Surviving an AZ loss doesn't depend on winning a scaling race | Scale up during the outage |
| Scaling | Target tracking on requests per instance; scheduled scale-up 6:30 AM, down 7:30 PM; Aurora reader auto-scaling; interface engine sized up, not out | Each tier scales the way its software allows | CPU-only scaling |
| Testing | AWS Fault Injection Service AZ experiments in Staging quarterly; full regional DR drill twice a year | An untested plan is a hope | Never running the runbook |

## 14. Cost ✅

| Foundation | Choice | Why | Alternative rejected |
|---|---|---|---|
| Commitments | 1-year no-upfront Compute Savings Plan for the always-on baseline; 1-year reservation for the Aurora writer and reader; on-demand above baseline | Commit only to what never turns off, after one year of real usage data | 3-year commitments |
| Non-prod | Dev scheduled off nights and weekends with Aurora Serverless v2; Staging smaller and run during test windows | Recovers much of the three-AZ cost | 24/7 full-size non-prod |
| Network charges | S3 gateway endpoints; imaging uploads exempt from deep inspection; monthly review of NAT, Transit Gateway, and firewall processing | Data processing is this design's most likely surprise cost | Ignoring data charges |
| Storage | Intelligent-Tiering, HealthImaging archive tier, Deep Archive for DR copies, short CloudWatch retention with long-term logs in S3 | Rarely touched data costs less automatically | Everything hot |
| Guardrails | Budgets per account (80% and 100%), Cost Anomaly Detection, showback by `CostCenter` and `Application`, monthly Compute Optimizer and Trusted Advisor review | Spend visible early, per clinic and system | Finding out from the invoice |
| Cost of security | Network Firewall, Verified Access, GuardDuty, CloudTrail data events, and MDR shown as their own line | Shows what protection costs; healthcare has had the highest average breach cost of any industry for over a decade | Burying it in the total |
| Presentation | Monthly and annual estimates per account from the Pricing Calculator, plus a qualitative TCO comparison against an on-prem refresh | Stakeholders compare against the alternative, not zero | One total |

## 15. Migration ✅

| Wave | What moves | Tool | Why this order |
|---|---|---|---|
| Assess | Every on-prem server and dependency mapped | AWS Application Discovery Service | The interface engine touches everything; forgotten dependencies break workflows |
| 0 · Foundation | Landing zone, network, Direct Connect and VPNs, DICOM routers at every clinic | Control Tower, Terraform | Destination and paths exist before anything moves |
| 1 · Documents | File shares to S3 | DataSync | Lowest risk; proves tooling, encryption, and Object Lock on real data |
| 2 · Imaging | New studies to HealthImaging and the S3 archive from day one; historical archive backfilled over the flagship's Direct Connect, then imported | Clinic routers, DataSync, HealthImaging import jobs | New images never wait on old ones |
| 3 · EHR | App servers, then rebuilt on the golden AMI; database with ongoing replication; interface engine rebuilt with channels re-imported; weekend-night cutover on downtime procedures | AWS Application Migration Service, AWS DMS with CDC | Replication keeps downtime to the final sync |
| 4 · Clinics | Flagship switches first, then the other seven in two groups | | Problems surface at the best-connected site |

| Control | Choice | Why |
|---|---|---|
| Assumption | On-prem database is already PostgreSQL, so the move is homogeneous | No schema conversion; stated openly |
| Validation | DMS row-level validation, DataSync checksums, per-patient image counts against the old PACS, clinician test scripts | Proof no patient data was lost or changed |
| Rollback | On-prem kept intact and read-only for 30 days; written go/no-go criteria; DMS reverse replication available | A way back if clinical workflows break |
| Decommission | Storage wiped to NIST 800-88 with certificates of destruction | Retired disks full of PHI are a breach waiting to happen |

## 16. Environments ✅

| Environment | Purpose | Data | Differences |
|---|---|---|---|
| **Prod** | Patient-facing | Real PHI | Full size, commitments |
| **Staging** | Dress rehearsal; same shape as Prod | De-identified (all 18 identifiers removed) | Smaller instances, runs during test windows |
| **Dev** | Building and testing | Synthetic only | Aurora Serverless v2, nights-and-weekends schedule |

Every environment uses the same Terraform modules with a small per-environment settings file, and changes flow Dev → Staging → Prod.

## 17. Infrastructure as code ✅

| Foundation | Choice | Why | Alternative rejected |
|---|---|---|---|
| Primary IaC | Terraform | Most requested in job postings; builds the design repeatably | CloudFormation, CDK |
| Scope | Workload account stack and Network-account hub as modules; Control Tower documented, not coded | Control Tower has its own setup flow; coding eight real accounts is beyond the project | Coding the whole landing zone |
| Validation | Prod, Staging, and Dev checked with `terraform validate` and scanners; only the slice runs `plan` and `apply` | `plan` needs real accounts to compare against | A `plan` gate for accounts that don't exist |
| State | S3 backend with native state locking, encrypted, versioned, public access blocked, created by `bootstrap/` | State can hold secrets and never goes in Git | Local state |
| Tagging | `default_tags` in the AWS provider applies all eight tags | The tagging standard enforced by the code itself | Tagging by hand |
| Scanning | `terraform fmt`/`validate`, TFLint, Checkov; `cfn-lint`; `cdk synth` | Errors and insecure settings caught before deploy | Finding mistakes in AWS |
| Comparison | CloudFormation and CDK (Python) for the network layer, written but not deployed | The class covers both; the same build three ways supports the alternatives discussion | Terraform only |
| CI | GitHub Actions runs every scanner on each push, with no AWS credentials | Validated code, visibly, without cloud access in CI | No CI |
| Deploy credentials | IAM Identity Center in the personal lab account, `aws sso login` | No long-lived access keys, even in the lab | IAM user with access keys |

## 18. Live deploy slice ✅

Deployed in us-west-2 from the Terraform for a few hours, verified, screenshotted, and destroyed. Budget alerts at $10, hard limit $20.

| Built | Proves |
|---|---|
| Workload VPC: three AZs, app, integration, and data subnets, no internet gateway, no NAT | No internet door where PHI lives |
| VPC endpoints (Systems Manager, CloudWatch Logs, Secrets Manager) and S3 gateway endpoint | Servers run and patch with no internet path |
| CloudFront (VPC origin) and WAF in front of a private ALB and an Auto Scaling group (minimum 3 × t3.micro) | The load balancer has no public address |
| Aurora PostgreSQL writer and reader, CMK-encrypted | Multi-AZ failover |
| S3 bucket with KMS, versioning, Object Lock (governance), Block Public Access | Encryption and immutability enforced |
| CloudTrail, GuardDuty, AWS Config required-tags rule, budget alarms | Detection and tagging enforcement |

| Left out | Why |
|---|---|
| Control Tower, extra accounts | Account-level; documented instead |
| Direct Connect, VPN, Verified Access | Need clinic hardware or an identity provider |
| Network Firewall, Transit Gateway | Cost and multi-account scope |
| HealthImaging, interface engine | Not needed to prove network, security, and HA; engine licensing |

**Proof points:** app loads through CloudFront while the ALB shows scheme internal · terminated instance replaced by Auto Scaling · Aurora failover with the app still working · unencrypted upload and public-access change both denied · hand-made untagged resource flagged by Config · CloudTrail shows every test action · GuardDuty sample findings · `terraform destroy` and a teardown check showing nothing billable remains.

## 19. Architecture decision records

| ADR | Decision | Alternative compared |
|---|---|---|
| 001 | Replatform the vendor EHR onto EC2 and Aurora | SaaS EHR |
| 002 | Aurora PostgreSQL | RDS PostgreSQL Multi-AZ, self-managed on EC2 |
| 003 | AWS HealthImaging | PACS software on EC2 with S3 |
| 004 | Multi-account landing zone with Control Tower | Single account |
| 005 | Pilot light DR in us-east-1 | Backup and restore, warm standby |
| 006 | Hybrid Direct Connect + VPN | VPN only, Direct Connect everywhere |
| 007 | Terraform as primary IaC | CloudFormation, AWS CDK |
| 008 | AWS Verified Access for remote staff | AWS Client VPN |
| 009 | Centralized egress with Network Firewall | NAT gateways in every VPC |
| 010 | us-west-2 primary, us-east-1 DR | us-east-1 primary |
| 011 | Interface engine active/passive behind an NLB | Single self-healing instance |
| 012 | Entra ID federated to Identity Center | Identity Center directory |
| 013 | MDR provider with Security Lake and a SIEM | Native AWS tools only |

## 20. Rubric coverage

| Rubric area | Points | Covered by |
|---|---|---|
| Architecture design | 25 | Sections 2–9, 16 |
| Visual diagram | 25 | [`diagrams/`](../diagrams) |
| Security | 18 | Sections 3, 5, 6, 10–12 |
| High availability and scalability | 18 | Sections 5, 13 |
| Cost optimization | 11 | Section 14 |
| Justification | 18 | Section 19 and the ADRs |
| Presentation and delivery | 30 | [`presentation/`](../presentation) |

## 21. Schedule

| Week | Dates | Work |
|---|---|---|
| 1 | Oct 26 – Nov 1 | Design review ✅ |
| 2 | Nov 2 – Nov 8 | ADRs, cost estimate, draw.io diagram |
| 3 | Nov 9 – Nov 15 | Terraform: bootstrap, network, security, identity |
| 4 | Nov 16 – Nov 22 | Terraform: compute, database, storage; CloudFormation and CDK network; CI |
| 5 | Nov 23 – Nov 29 | Live deploy, verify, destroy (Thanksgiving week, light load) |
| 6 | Nov 30 – Dec 5 | Slide deck, rehearsal, recorded video, submit |

## 22. Traps and wrong answers

The mistakes this design deliberately avoids, by layer. Useful for presentation questions.

| Layer | Wrong answer | Why it's wrong |
|---|---|---|
| Governance | "Attach an SCP to give a team access" | SCPs only cap permissions; IAM policies grant them |
| Governance | "Separate VPCs are as good as separate accounts" | VPCs in one account share one set of IAM permissions |
| Classification | "The bucket is tagged internal, so the data is internal" | Classification follows the data; Macie verifies |
| Classification | "Put the patient name in a tag for tracking" | Tags appear in billing and CloudTrail; that's a breach |
| Regions | "HIPAA requires US data residency" | HIPAA has no residency rule; it's a contract and policy decision |
| Regions | "Block every region except primary and DR" | Global services and CloudFront certificates need us-east-1 |
| Network | "Public subnet is a setting" | It's purely the route table |
| Network | "NAT is a firewall" | NAT blocks inbound only; exfiltration needs egress filtering |
| Network | "Direct Connect is private, so it's encrypted" | It isn't; a VPN over it provides encryption |
| Network | "NACLs work like security groups" | NACLs are stateless; forgetting ephemeral ports drops every reply |
| Edge | "CloudFront and WAF protect a public ALB" | Attackers can hit the ALB directly; VPC origins remove the public address |
| Compute | "Put the interface engine behind the ALB" | HL7 over MLLP is raw TCP; it needs an NLB |
| Compute | "AWS patches EC2" | AWS patches managed engines, not your EC2 operating system |
| Database | "Turn on encryption later" | An unencrypted database can't be encrypted in place |
| Database | "A read replica is a backup" | Replicas copy deletions and ransomware instantly |
| Storage | "Compliance-mode Object Lock everywhere is safest" | A wrong retention can never be undone |
| Storage | "SSE-S3 and SSE-KMS are the same" | Only KMS controls and logs who can decrypt |
| Identity | "IAM users with MFA are fine for admins" | Long-lived credentials are the top source of AWS breaches |
| Identity | "Break-glass accounts should be quiet" | Their use must page people immediately |
| Monitoring | "CloudTrail logs everything" | Data events, the record of PHI access, are off by default |
| Monitoring | "Security Hub has a HIPAA standard" | HIPAA mapping lives in Config conformance packs and Audit Manager |
| Monitoring | "GuardDuty blocks attacks" | It detects; response must be wired up |
| Shared responsibility | "AWS is HIPAA compliant, so we are" | AWS offers eligible services and a BAA; compliance is how you use them |
| Shared responsibility | "We need a BAA with the internet provider" | Conduit exception; but the MDR provider seeing logs needs one |
| HA and DR | "Multi-AZ is our DR" | Multi-AZ dies with the region |
| HA and DR | "Active/active for the EHR" | Vendor EHRs rarely support two writable regions |
| Cost | "The cloud is always cheaper" | Lift-and-shift on-demand 24/7 often costs more than on-prem |
| Cost | "Compute is the bill" | Data processing through TGW, NAT, and the firewall can rival compute |
| Migration | "MGN moves the database to Aurora" | MGN copies servers; moving onto Aurora is DMS's job |
| Migration | "Migration ends at cutover" | Validation, rollback windows, and secure decommissioning are part of it |
| Environments | "Fake names make test data de-identified" | All 18 identifiers must go, including dates and MRNs |
| IaC | "Run `terraform plan` for every environment" | `plan` needs the real accounts to exist |
