<div align="center">

# 🏥 Bayou Clinic Partners: AWS Migration Design

**Final report · INTE 3600 · Cloud architecture recommendation for a HIPAA-regulated clinic network**

<img src="https://img.shields.io/badge/Status-Draft_v0.1-F2A900?style=for-the-badge">
<img src="https://img.shields.io/badge/Primary-us--west--2-232F3E?style=for-the-badge&logo=amazonwebservices&logoColor=white">
<img src="https://img.shields.io/badge/DR-us--east--1-232F3E?style=for-the-badge">
<img src="https://img.shields.io/badge/Run_cost-%246.6K%2Fmo-0A7E8C?style=for-the-badge">

**Prepared by Caleb Santora · November 2026**

</div>

---

## Contents

1. [Executive summary](#1-executive-summary)
2. [The organization today](#2-the-organization-today)
3. [Requirements](#3-requirements)
4. [Solution overview](#4-solution-overview)
5. [Account structure and governance](#5-account-structure-and-governance)
6. [Network](#6-network)
7. [Edge and remote access](#7-edge-and-remote-access)
8. [Application, data, and imaging](#8-application-data-and-imaging)
9. [Identity and access](#9-identity-and-access)
10. [Security monitoring and compliance](#10-security-monitoring-and-compliance)
11. [Shared Responsibility Model](#11-shared-responsibility-model)
12. [High availability and disaster recovery](#12-high-availability-and-disaster-recovery)
13. [Cost](#13-cost)
14. [Migration plan](#14-migration-plan)
15. [Design decisions and alternatives](#15-design-decisions-and-alternatives)
16. [Risks and mitigations](#16-risks-and-mitigations)
17. [Implementation roadmap](#17-implementation-roadmap)
18. [Conclusion](#18-conclusion)
19. [Appendices](#appendices)

---

## 1. Executive summary

**Bayou Clinic Partners** (fictional) runs eight outpatient clinics with about 400 staff. Its electronic health record (EHR), patient portal, documents, and medical imaging run on aging servers at one flagship clinic. One hardware failure there takes every clinic offline, backups are manual, and audit evidence is slow to produce.

This report recommends migrating to AWS with a design built around three outcomes:

| Outcome | How the design delivers it |
|---|---|
| 🔐 **Patient data stays protected** | Eight-account landing zone, data classification enforced at creation, no internet door into any network holding PHI, inspected egress, zero-trust remote access, encryption everywhere, and continuous HIPAA evidence |
| 🟢 **Clinics stay online** | Every tier across three Availability Zones; the EHR recovers in another region within **4 hours with about 1 minute of data loss** |
| 💲 **Spend stays visible** | **$6,645/month (~$79,700/year)** steady state, tracked per clinic and per application through mandatory tags |

**Recommendation:** approve the landing zone and network build (Wave 0), then migrate in five waves over roughly six months, starting with documents and ending with the flagship-first clinic cutover.

---

## 2. The organization today

| Area | Current state | Problem |
|---|---|---|
| EHR and patient portal | Single server at the flagship clinic | One failure stops all eight clinics |
| Documents | Local file server | Running out of space; manual backups |
| Imaging | Aging on-prem PACS | Images stuck at one site, no off-site copy |
| Connectivity | Clinics connect to the flagship over the WAN | The flagship is a single point of failure |
| Operations | Small IT team patches and audits by hand | Compliance evidence is slow and incomplete |

**Clinical workflow in scope:** registration and orders in the EHR, HL7 messaging through an interface engine, X-ray and ultrasound imaging (DICOM), radiology reporting through the EHR's radiology module, and a patient portal. See the [healthcare data primer](healthcare-data-primer.md) for how data moves through a visit.

---

## 3. Requirements

| # | Requirement | Type |
|---|---|---|
| R1 | Protect PHI under HIPAA; sign a BAA with AWS before any PHI moves | Compliance |
| R2 | Survive the loss of a server or an entire data center without manual action | Availability |
| R3 | Recover the EHR in another region within 4 hours, losing no more than 1 minute of data | Disaster recovery |
| R4 | Keep imaging working at clinics even when a network link drops | Clinical continuity |
| R5 | Give remote staff and radiologists secure EHR access without exposing it to the internet | Security |
| R6 | Produce audit evidence continuously, not at audit time | Compliance |
| R7 | Show monthly cost per clinic and per application | Financial |
| R8 | Keep real PHI out of test environments | Compliance |

**Key assumptions:** the vendor EHR runs on Linux and is certified on PostgreSQL; the clinic uses Microsoft 365; one flagship clinic produces most imaging studies. Full assumptions are in the [design plan](design-plan.md) and the [cost estimate](cost/README.md#-assumptions).

---

## 4. Solution overview

> 🗺️ The full draw.io diagram with AWS icons is in [`diagrams/`](../diagrams).

```
        Patients                                   Remote staff
           │                                            │
     Route 53 (DNS)                              Verified Access
           │                                  (identity + device check)
   CloudFront + AWS WAF                                 │
           │ VPC origin                                 │
┌──────────┴────────── Prod VPC · us-west-2 · 3 AZs ────┴─────────┐
│                                                                 │
│  App           Private ALB ──► EHR + portal (EC2 Auto Scaling)  │
│  Integration   HL7 interface engine (active/passive, NLB)       │
│  Data          Aurora PostgreSQL (writer + reader · KMS)        │
│                                                                 │
│  No internet gateway in any VPC that holds PHI                  │
└────────────────────────────────┬────────────────────────────────┘
                                 │
┌──────────────────────── Network account ────────────────────────┐
│  Transit Gateway ── Network Firewall ── Egress VPC (NAT)        │
└──────────┬──────────────────────────────────────────┬───────────┘
           │ Direct Connect + VPN                     │ Site-to-Site VPN
     Flagship clinic                            7 other clinics
           └──── DICOM routers (store-and-forward) ───┐
                                                      │ DICOMweb STOW-RS
              Shared Services endpoints ──► AWS HealthImaging · S3

        DR: pilot light in us-east-1 (Aurora Global, standby TGW, AMIs)
```

### How a request flows

| Who | Path |
|---|---|
| Patient | Route 53 → CloudFront + WAF → private ALB → EHR portal → Aurora / S3 |
| Remote staff | Verified Access → private ALB → EHR → Aurora |
| Clinic staff | Direct Connect or VPN → Transit Gateway → Network Firewall → EHR |
| Imaging device | DICOM router → Direct Connect or VPN → HealthImaging → OHIF web viewer |

---

## 5. Account structure and governance

The organization runs on an **AWS Control Tower** landing zone with eight accounts. Each account is a hard boundary for permissions, billing, and blast radius.

| Account | Purpose |
|---|---|
| Management | Billing and organization admin only; no workloads |
| Log Archive | Every log from every account, where workload admins can't delete it |
| Audit | Security tooling across all accounts |
| Network | Transit Gateway, VPNs, Direct Connect, egress, Network Firewall |
| Shared Services | Centralized VPC endpoints and DNS resolvers |
| Prod | Patient-facing systems |
| Staging | Dress rehearsal for changes, same shape as Prod |
| Dev | Building and testing with synthetic data |

### Guardrails

| Guardrail | Effect |
|---|---|
| Region deny | Only us-west-2 and us-east-1 can be used |
| Tag policy | Standard tag keys and values everywhere |
| Deny untagged data resources | S3, RDS, EC2, EBS, KMS keys, and HealthImaging can't be created without a `DataClass` tag |
| Protect logging | Nobody can disable CloudTrail or Config |

### Data classification

| Tier | Covers |
|---|---|
| `public` | Clinic hours, portal sign-in page |
| `internal` | Network configs, runbooks |
| `confidential` | Staff records, contracts, financials |
| `restricted` | PHI and anything that can contain it, including its logs and backups |

A separate `Compliance` tag (`hipaa`, `pci`, `none`) records which rulebook applies. Eight tags are mandatory on every resource: `Environment`, `Owner`, `CostCenter`, `Application`, `DataClass`, `Compliance`, `BackupPolicy`, `ManagedBy`.

---

## 6. Network

| Element | Design | Why |
|---|---|---|
| Availability Zones | Three in every environment | Losing one zone still leaves redundancy |
| IP plan | VPC IPAM; clinic range reserved | Overlapping ranges can't be fixed without a rebuild |
| Workload tiers | App · Integration · Data | The interface engine reads every HL7 message, so it gets its own fenced tier |
| Internet doors | **None** in workload VPCs | All inbound comes through CloudFront; all outbound through the inspected egress VPC |
| Hub | Transit Gateway in the Network account | One connection per VPC and clinic; route tables keep Prod, Staging, and Dev apart |
| Flagship clinic | Direct Connect with VPN running over it, plus an internet VPN backup | Fast, steady link where imaging volume is; VPN supplies encryption that Direct Connect lacks |
| Other clinics | Site-to-Site VPN | Encrypted over existing internet; enough for occasional studies |
| Egress | Centralized NAT behind **AWS Network Firewall** with a domain allow-list | A compromised server can't send PHI to an attacker's site |
| AWS APIs | VPC endpoints | AWS service traffic, including PHI, never crosses the internet |

### Defense in depth: one attack, four stops

A clinic workstation is phished. To reach patient data the attacker must get past:

1. **Network Firewall** inspecting clinic-to-AWS traffic
2. **NACLs** at the data-tier boundary
3. **Security groups** that only allow the app and integration tiers to reach the database
4. **Encryption** with keys the attacker's identity can't use

---

## 7. Edge and remote access

| Element | Design | Why |
|---|---|---|
| What's public | Patient portal only | The clinical system is never on the internet |
| CDN and origin | CloudFront with **VPC origins** to a **private** load balancer | Nothing to go around; the load balancer has no public address |
| Web firewall | AWS WAF: managed rules, login rate limits, Bot Control | Credential stuffing on the patient login is the most likely attack |
| Geo-blocking | Not used | Patients travel and need their records |
| DDoS | Shield Standard | Free and automatic; Advanced (~$36K/year) is out of proportion |
| Remote staff | **AWS Verified Access** | A stolen laptop gets nothing without the user's MFA and a healthy device; a VPN would hand it the whole network |

---

## 8. Application, data, and imaging

### Application

| Component | Design |
|---|---|
| EHR and portal | Licensed vendor EHR replatformed onto EC2 Auto Scaling across three AZs |
| Radiology workflow | The EHR's radiology module (orders, worklist, reports) |
| Interface engine | Two nodes, active/passive, behind an internal Network Load Balancer on port 2575 (HL7 over MLLP is raw TCP) |
| Server images | Golden AMIs built monthly by EC2 Image Builder from a CIS-hardened baseline |
| Server access | Systems Manager Session Manager only; no SSH, every session logged |
| Patching | App tier replaced with new images; interface engine patched in place, passive node first |

### Data

| Component | Design |
|---|---|
| Database | Aurora PostgreSQL, writer and reader in separate AZs, storage replicated six ways across three AZs |
| Encryption | Customer managed KMS key per environment; TLS required |
| Credentials | Secrets Manager with automatic rotation |
| Backups | 35-day point-in-time restore; AWS Backup with Vault Lock |
| Auditing | pgAudit records who queried which records |

### Imaging

| Component | Design |
|---|---|
| Image store | **AWS HealthImaging**: managed, DICOM-native, HIPAA-eligible, automatic archive tiering |
| Ingest | Store-and-forward DICOM router at each clinic converts classic DICOM to encrypted DICOMweb (STOW-RS) |
| Viewing | OHIF web viewer launched from the EHR |
| Archive copy | Routers also write each study to S3, replicated to us-east-1 Deep Archive for DR |

### Documents

S3 with SSE-KMS, account-wide Block Public Access, Intelligent-Tiering, and Object Lock: governance mode on clinical records, compliance mode (6 years) on audit logs.

---

## 9. Identity and access

| Element | Design |
|---|---|
| Workforce identity | Microsoft Entra ID federated to IAM Identity Center; one login and one offboarding switch |
| MFA | Required for every staff and admin login |
| Admin roles | Permission sets per job: Network Admin, DBA, Security Auditor, App Operator, Billing |
| Prod admin | Just-in-time elevation with approval and expiry; no standing admin rights |
| Emergency access | Two break-glass users with hardware keys; any use pages the team |
| Root user | Root credentials removed from member accounts |
| Workloads | IAM roles only; no access keys anywhere |
| PHI access | Attribute-based access control: job attributes from Entra checked against `DataClass` |
| Patients | The vendor portal's built-in sign-in with MFA, behind WAF rate limits |

---

## 10. Security monitoring and compliance

| Capability | Service | Notes |
|---|---|---|
| API audit trail | CloudTrail (org trail, data events on PHI) | Proves who **accessed** PHI, not only who changed settings |
| Threat detection | GuardDuty (both regions) | Credentials, crypto mining, database brute force, runtime |
| Posture | Security Hub | Foundational, CIS, NIST 800-53, PCI DSS standards |
| HIPAA evidence | AWS Config conformance pack + Audit Manager | Security Hub has no HIPAA standard; these provide the mapping |
| Vulnerabilities | Inspector | Tied to Patch Manager reporting |
| PHI discovery | Macie | Finds PHI where it isn't labeled |
| SIEM and 24/7 SOC | Security Lake (OCSF) feeding an MDR-run SIEM | A small IT team can't staff nights |
| Automated response | EventBridge + Lambda | Quarantines a compromised instance in seconds |

All logs are classified `restricted`, because URLs and error messages can carry patient identifiers.

---

## 11. Shared Responsibility Model

| Responsibility | EC2 (EHR, engine) | Aurora | S3 · HealthImaging | Edge services |
|---|---|---|---|---|
| Facilities, hardware, network | AWS | AWS | AWS | AWS |
| Hypervisor / host | AWS | AWS | AWS | AWS |
| Guest OS patching | **Bayou** | AWS | AWS | AWS |
| Database engine patching | — | AWS (Bayou picks the window) | — | — |
| Application patches | **EHR vendor** writes, **Bayou** applies | — | — | — |
| Network rules | **Bayou** | **Bayou** | **Bayou** | **Bayou** |
| Identity and access | **Bayou** | **Bayou** | **Bayou** | **Bayou** |
| Encryption and keys | **Bayou** | **Bayou** | **Bayou** | **Bayou** |
| Data and classification | **Bayou** | **Bayou** | **Bayou** | **Bayou** |

Outside AWS, Bayou owns clinic routers, firewalls, and workstations; the MDR provider owns 24/7 monitoring under contract.

**Business associate agreements:** AWS, the EHR vendor, the MDR provider, the SIEM vendor, and the DICOM router vendor (if remotely managed). Carriers fall under HIPAA's conduit exception.

---

## 12. High availability and disaster recovery

### Recovery targets

| Tier | Systems | AZ loss | Region loss RTO | Region loss RPO |
|---|---|---|---|---|
| 1 | EHR, database, interface engine | Automatic, minutes | **4 hours** | **1 minute** |
| 2 | Imaging archive | Automatic, minutes | 24 hours | 15 minutes |
| 3 | Reporting | Automatic, minutes | Best effort | Best effort |

### How it works

| Failure | What happens |
|---|---|
| Server | Auto Scaling replaces it behind the load balancer |
| Availability Zone | Remaining zones already carry full load (**static stability**); Aurora fails over in under a minute |
| Clinic link | DICOM routers queue images locally; the flagship falls back from Direct Connect to internet VPN |
| Region | **Pilot light** in us-east-1: Aurora Global secondary (about 1 second behind) is promoted, Terraform builds the app tier from copied AMIs, clinic VPNs come up on the standby Transit Gateway, Route 53 fails over |

### Scaling

Target tracking on requests per instance, plus scheduled scale-up at 6:30 AM and down at 7:30 PM. Aurora reader capacity scales for reports.

### Testing

Fault Injection Service AZ experiments in Staging every quarter; a full regional DR drill twice a year.

---

## 13. Cost

> Full detail: [Cost Estimate](cost/README.md)

| | Monthly | Annual |
|---|---:|---:|
| AWS Pricing Calculator | $6,348.00 | $76,176 |
| Documented adjustments | +$297.20 | +$3,566 |
| **Adjusted run cost** | **$6,645.20** | **~$79,742** |

| Purpose | Monthly | Share |
|---|---:|---:|
| Security & compliance | $2,614 | 39% |
| Connectivity | $1,711 | 26% |
| Production workload | $1,598 | 24% |
| Staging & Dev | $442 | 7% |
| Disaster recovery | $280 | 4% |

### Cost decisions

| Decision | Effect |
|---|---|
| 1-year Compute Savings Plan on the always-on baseline only | ~27% off; still covers servers rebuilt in DR |
| Staging and Dev on business hours | Non-prod costs ~28% of Prod despite the same 3-AZ shape |
| Headless Aurora secondary in DR | Data current in DR for storage cost only |
| Weekly DR backup copies | ~$316/month less than daily |
| NAT behind Network Firewall | NAT charges waived (−$121/month) |

### Monitoring

AWS Budgets per account at 80% and 100%, Cost Anomaly Detection, showback by `CostCenter` and `Application`, and monthly Compute Optimizer reviews.

**Outside the AWS bill:** carrier circuit to Houston, MDR and SIEM contracts, EDR licenses, the EHR license, and clinic DICOM routers.

---

## 14. Migration plan

| Wave | What moves | Tools | Why this order |
|---|---|---|---|
| Assess | Every server and dependency mapped | Application Discovery Service | The interface engine touches everything |
| 0 · Foundation | Landing zone, network, Direct Connect, VPNs, clinic routers | Control Tower, Terraform | Destination exists first |
| 1 · Documents | File shares to S3 | DataSync | Lowest risk; proves encryption and Object Lock |
| 2 · Imaging | New studies to HealthImaging from day one; history backfilled over Direct Connect | Routers, DataSync, import jobs | New images never wait on old ones |
| 3 · EHR | App servers, database with live replication, interface engine rebuilt; weekend-night cutover | MGN, DMS with CDC | Downtime limited to the final sync |
| 4 · Clinics | Flagship first, then the other seven in two groups | — | Problems surface at the best-connected site |

**Controls:** row-level DMS validation, DataSync checksums, per-patient image counts against the old PACS, clinician test scripts, a 30-day read-only rollback window, and NIST 800-88 wiping of retired storage.

---

## 15. Design decisions and alternatives

| # | Decision | Alternative compared | Why this choice |
|---|---|---|---|
| 001 | Replatform the vendor EHR onto EC2 and Aurora | SaaS EHR | Keeps control of PHI hosting and integration |
| 002 | Aurora PostgreSQL | RDS Multi-AZ, self-managed on EC2 | Storage across three AZs, sub-minute failover |
| 003 | AWS HealthImaging | PACS software on EC2 with S3 | No PACS servers to run or patch |
| 004 | Control Tower multi-account | Single account | Hard boundaries and tamper-resistant logs |
| 005 | Pilot light DR | Backup-and-restore, warm standby | Meets a 4-hour RTO at a fraction of warm standby |
| 006 | Hybrid Direct Connect + VPN | VPN only, Direct Connect everywhere | Spends where imaging volume is |
| 007 | Terraform as primary IaC | CloudFormation, AWS CDK | Repeatable builds; widely used |
| 008 | Verified Access | Client VPN | Per-app zero trust instead of network access |
| 009 | Centralized egress with Network Firewall | NAT in every VPC | Stops exfiltration; one place to inspect |
| 010 | us-west-2 primary, us-east-1 DR | us-east-1 primary | Stability; HealthImaging in both |
| 011 | Interface engine active/passive behind an NLB | Single self-healing instance | Message order preserved through failures |
| 012 | Entra ID federated to Identity Center | Identity Center directory | One identity, one offboarding switch |
| 013 | MDR provider with Security Lake and a SIEM | Native AWS tools only | 24/7 coverage a small team can't staff |

Each decision has a full record in [`adr/`](adr).

---

## 16. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Phished clinic workstation | High | High | Firewall inspection, tiered network, MDR, automated quarantine |
| Ransomware | Medium | High | Vault Lock backups, Object Lock, point-in-time restore |
| Regional outage | Low | High | Pilot light in us-east-1, tested twice a year |
| Cost overrun from data processing | Medium | Medium | Budgets, anomaly detection, imaging inspection bypass lever |
| Vendor EHR doesn't support a planned feature | Medium | Medium | Replatform keeps vendor-certified OS and engine |
| Clinic link failure during imaging | Medium | Low | Store-and-forward routers; VPN backup at the flagship |
| Migration data loss | Low | High | DMS validation, checksums, 30-day rollback window |
| Misconfiguration drift | Medium | Medium | Config rules, `ManagedBy` tag, IaC-only changes |

---

## 17. Implementation roadmap

| Phase | Timing | Milestone |
|---|---|---|
| Approve design and BAA | Month 0 | BAA accepted in AWS Artifact |
| Wave 0 · Foundation | Months 1–2 | Landing zone, network, and clinic connectivity live |
| Waves 1–2 · Documents and imaging | Months 2–3 | Documents in S3; new imaging in HealthImaging |
| Wave 3 · EHR | Months 4–5 | Weekend cutover with rollback window |
| Wave 4 · Clinics | Months 5–6 | All eight clinics on AWS |
| Optimize | Month 7+ | First DR drill; commitment review |

---

## 18. Conclusion

Moving Bayou Clinic Partners to AWS removes the single point of failure that can stop all eight clinics today, replaces manual backups and audits with continuous protection and evidence, and gives leadership a monthly bill they can break down by clinic. The design spends most of its budget on protecting patient data and connecting the clinics, which is where a healthcare organization's risk actually sits.

---

## Appendices

| Appendix | Document |
|---|---|
| A · Full design with every foundation and its reason | [Design Plan](design-plan.md) |
| B · Cost estimate, assumptions, and calculator exports | [Cost Estimate](cost/README.md) |
| C · Clinical data flow (HL7, DICOM, PACS) | [Healthcare Data Primer](healthcare-data-primer.md) |
| D · Architecture decision records | [ADRs](adr) |
| E · Architecture diagram | [Diagrams](../diagrams) |
| F · Build log | [00-START-HERE](../00-START-HERE) |
