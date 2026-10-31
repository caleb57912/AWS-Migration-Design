<div align="center">

# ☁️ AWS Migration Design

**Migrating a regional healthcare clinic network from on-premises servers to a secure, highly available AWS architecture.**

<img src="https://img.shields.io/badge/Status-Phase_1:_Design-F2A900?style=for-the-badge">
<img src="https://img.shields.io/badge/Cloud-AWS-232F3E?style=for-the-badge&logo=amazonwebservices&logoColor=white">
<img src="https://img.shields.io/badge/IaC-Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white">
<img src="https://img.shields.io/badge/HIPAA-Aligned_Design-0A7E8C?style=for-the-badge">

</div>

---

> ### 👋 Start here: [**00-START-HERE →**](00-START-HERE/)
> The project in 60 seconds, what to read in order, and the build log: every step I've completed, with the decisions, issues and fixes behind each one.
>
> - **Phase 1 Design 🔄** accounts, data classification, regions, network, edge, and workload placement decided; remaining layers in review

## 🎯 Mission

Design, codify, and prove a migration to AWS for **Bayou Clinic Partners**, a fictional network of 8 outpatient clinics and about 400 staff, so patient data stays protected, clinics stay online through failures, and cloud spend stays visible and controlled.

This is my final project for INTE 3600. The brief asks for a conceptual design, a diagram, and a stakeholder presentation. I'm also building the design in code and deploying a working slice of it to prove it holds up.

## 💡 Why this project

| | |
|---|---|
| 🔐 **Security first** | HIPAA-aligned design with the Shared Responsibility Model mapped to every service I chose |
| 🏗️ **Built, not just drawn** | Terraform defines the whole design; a slice is deployed, verified, and torn down |
| 🔁 **Three IaC approaches** | The same network layer written in Terraform, CloudFormation, and AWS CDK, compared side by side |
| 🧾 **Decisions on record** | Every major choice has an architecture decision record (ADR): context, options, choice, and why |
| 💲 **Cost-aware** | Priced in the AWS Pricing Calculator; the live deploy is capped at $20 behind a billing alarm |

## 🏥 The scenario

| Today (on-premises) | Problem |
|---|---|
| EHR and patient portal on a single server in the main clinic | One hardware failure takes every clinic offline |
| Documents on a local file server | Storage is running out and backups are manual |
| X-ray and ultrasound images on an aging on-prem PACS | Images are stuck at one site with no off-site copy |
| Clinics connect to the flagship clinic over the WAN | The flagship site is a single point of failure for all eight clinics |
| Patching and audits handled by a small IT team | Compliance evidence is slow to produce |

## 🏗️ Target architecture

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
│  Integration   HL7 interface engine                             │
│  Data          RDS PostgreSQL (Multi-AZ · KMS)                  │
│                                                                 │
│  No internet gateway in any VPC that holds PHI                  │
└────────────────────────────────┬────────────────────────────────┘
                                 │
┌──────────────────────── Network account ────────────────────────┐
│                                                                 │
│  Transit Gateway ── Network Firewall ── Egress VPC (NAT)        │
│                                                                 │
└──────────┬──────────────────────────────────────────┬───────────┘
           │ Direct Connect + VPN                     │ Site-to-Site VPN
     Flagship clinic                            7 other clinics
           │                                          │
           └──── Clinic DICOM routers (store-and-forward) ────┐
                                                              │ STOW-RS
              Shared Services endpoints ──► AWS HealthImaging · S3

        DR: backups, standby Transit Gateway, and restore target in us-east-1
```

Every workload runs in its own account (Prod, Staging, Dev) under an AWS Control Tower landing zone, with logs shipped to a separate Log Archive account. The full draw.io diagram with AWS icons lives in [`diagrams/`](diagrams). Every foundation and the reason behind it is in the [**Design Plan →**](docs/design-plan.md).

### Components

| Tier | Services | Role |
|---|---|---|
| **Governance** | AWS Control Tower, Organizations, SCPs, tag policies, AWS Artifact | Eight-account landing zone; region and tagging guardrails; data classification enforced at creation; the HIPAA BAA |
| **Edge** | Route 53, CloudFront (VPC origins), AWS WAF, Shield Standard | DNS failover, caching, and attack filtering; the load balancer has no public address |
| **Remote access** | AWS Verified Access, IAM Identity Center | Zero-trust access to the EHR for remote staff, checked per request |
| **Network** | Transit Gateway, VPC IPAM, Network Firewall, centralized egress and endpoints | One inspected hub for clinic, inter-VPC, and outbound traffic |
| **Clinic connectivity** | Direct Connect + VPN at the flagship clinic, Site-to-Site VPN at the rest | Encrypted links sized to each clinic's imaging volume |
| **App** | Private Application Load Balancer, EC2 Auto Scaling | The vendor EHR and its patient portal and radiology module across three AZs |
| **Integration** | HL7 interface engine on EC2 | Routes clinical messages; fenced off in its own tier |
| **Data** | Amazon RDS for PostgreSQL (Multi-AZ) | Patient records, encrypted with KMS, with automatic failover |
| **Imaging** | AWS HealthImaging, clinic DICOM routers | Managed DICOM store; routers cache at each clinic and upload over encrypted DICOMweb |
| **Storage** | Amazon S3 | Documents: encrypted, versioned, retention-locked, aged to cheaper tiers |
| **Identity** | IAM Identity Center, IAM roles, Amazon Cognito, ABAC | Admin single sign-on, no long-lived keys, patient portal sign-in, tag-based access to PHI |
| **Security & monitoring** | CloudTrail, GuardDuty, Security Hub, AWS Config, Inspector, Macie, CloudWatch | Audit trail, threat detection, compliance checks, vulnerability scans, PHI discovery, alarms |
| **Resilience** | AWS Backup | Scheduled backups with a cross-region copy to us-east-1 |
| **Migration** | AWS Application Migration Service, AWS DMS, AWS DataSync | Moves the app servers, database, file shares, and imaging archive |

### Request flow

```
Patient       → Route 53 → CloudFront + WAF → private ALB → EHR portal (EC2) → RDS / S3
Remote staff  → Verified Access → private ALB → EHR (EC2) → RDS
Clinic staff  → Direct Connect or VPN → Transit Gateway → Network Firewall → EHR
Imaging device → Clinic DICOM router → Direct Connect or VPN → AWS HealthImaging → Web viewer
```

## 🧰 Stack

| Tool | Purpose | Status |
|---|---|---|
| draw.io | Architecture diagram | 🔜 Planned |
| AWS Pricing Calculator | Monthly cost estimate | 🔜 Planned |
| Terraform | Primary IaC: the full design, used for the live deploy | 🔜 Planned |
| AWS CloudFormation | Network layer, written for comparison | 🔜 Planned |
| AWS CDK | Network layer, written for comparison | 🔜 Planned |
| Checkov | IaC security scanning | 🔜 Planned |
| AWS Budgets + CloudWatch billing alarm | Deploy cost guardrail | 🔜 Planned |

## 🧭 Roadmap

| Phase | Steps | Gate |
|---|---|---|
| **1 · Design** | Requirements · Current state · Shared responsibility map · ADRs · Cost estimate | Every rubric area has a written decision |
| **2 · Diagram** | draw.io diagram with AWS icons, AZ boundaries, and numbered data flow | Diagram matches the design and the IaC |
| **3 · IaC** | Terraform for the full design · CloudFormation and CDK for the network layer | `terraform plan` is clean; CloudFormation lints and CDK synthesizes |
| **4 · Deploy** | Billing alarm · Deploy the slice · Verify failover and access · Screenshot · Destroy | Slice verified and torn down for under $20 |
| **5 · Present** | Slide deck · Recorded 8–10 minute briefing | Deck and video submitted |

- [x] Repository created
- [x] Design plan drafted
- [ ] Phase 1: Design
- [ ] Phase 2: Diagram
- [ ] Phase 3: IaC
- [ ] Phase 4: Deploy
- [ ] Phase 5: Present

## 📁 Repository map

Every folder has a README describing what goes in it; the contents fill in as each phase is built.

| Folder | What's inside |
|---|---|
| [`00-START-HERE/`](00-START-HERE) | **Overview, reading order, and the step-by-step build log** |
| [`docs/`](docs) | Design plan, requirements, shared responsibility map |
| [`docs/adr/`](docs/adr) | Architecture decision records |
| [`docs/cost/`](docs/cost) | Pricing Calculator estimate and optimization plan |
| [`diagrams/`](diagrams) | draw.io source and exported images |
| [`iac/terraform/`](iac/terraform) | Full design in Terraform: bootstrap, modules, and prod / dev / slice environments |
| [`iac/cloudformation/`](iac/cloudformation) | Network layer in CloudFormation |
| [`iac/cdk/`](iac/cdk) | Network layer in AWS CDK |
| [`scripts/`](scripts) | Secret scanning, IaC scanning, and teardown checks I run |
| [`deploy-evidence/`](deploy-evidence) | Verification results from the live deploy |
| [`presentation/`](presentation) | Slide deck and speaker notes |
| [`screenshots/`](screenshots) | Evidence supporting the documentation |

## 🔒 Privacy & sanitization

- Bayou Clinic Partners is fictional, and no real patient data is used anywhere
- AWS account IDs, access keys, ARNs, and public IPs are removed before commit
- Terraform state and variable files are never committed
- Redacted values appear as `<REDACTED>`

---

<div align="center">

**Caleb Santora** · Security+ · CySA+ · SecurityX · Associate of ISC2

[GitHub Profile](https://github.com/caleb57912)

</div>
