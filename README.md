<div align="center">

# ☁️ AWS Migration Design

**Migrating a regional healthcare clinic network from on-premises servers to a secure, highly available AWS architecture.**

<img src="https://img.shields.io/badge/Status-Phase_1:_Design-F2A900?style=for-the-badge">
<img src="https://img.shields.io/badge/Cloud-AWS-232F3E?style=for-the-badge&logo=amazonwebservices&logoColor=white">
<img src="https://img.shields.io/badge/IaC-Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white">
<img src="https://img.shields.io/badge/HIPAA-Aligned_Design-0A7E8C?style=for-the-badge">

</div>

---

> ### 📖 Start here: [**Build Log →**](build-log/)
> Every step I've completed so far, in order, with the decisions, issues and fixes behind each one.
>
> - **Phase 1 Design 🔄** requirements, current state, architecture decisions, cost estimate

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
| Imaging and documents on a local file server | Storage is running out and backups are manual |
| Clinics connect to the main site over the WAN | The main site is a single point of failure |
| Patching and audits handled by a small IT team | Compliance evidence is slow to produce |

## 🏗️ Target architecture

```
                 Clinic staff · Patients
                           │
                     Route 53 (DNS)
                           │
                 CloudFront + AWS WAF
                           │
┌──────────────────── VPC · us-east-1 ────────────────────┐
│                                                         │
│        AZ-a                            AZ-b             │
│   ┌─────────────────────────────────────────────────┐   │
│   │      Application Load Balancer (public)         │   │
│   └───────────┬───────────────────────┬─────────────┘   │
│               │                       │                 │
│      EC2 app tier (private)   EC2 app tier (private)    │  ◄ Auto Scaling group
│               │                       │                 │
│        RDS primary ───── sync ────► RDS standby         │  ◄ Multi-AZ · KMS
│                                                         │
└──────────┬───────────────────────────────────┬──────────┘
           │ VPC endpoint                      │ Site-to-Site VPN
    S3 (KMS · versioned)                 8 clinic sites
           │
    Backup copy ──► us-west-2
```

The full draw.io diagram with AWS icons lives in [`diagrams/`](diagrams).

### Components

| Tier | Services | Role |
|---|---|---|
| **Edge** | Route 53, CloudFront, AWS WAF | DNS, caching, and filtering of web attacks before they reach the app |
| **Web / app** | Application Load Balancer, EC2 Auto Scaling | Runs the EHR and patient portal across two AZs, scaling with demand |
| **Data** | Amazon RDS (Multi-AZ) | Patient records, encrypted with KMS, with automatic failover |
| **Storage** | Amazon S3 | Imaging and documents, encrypted, versioned, aged to cheaper tiers |
| **Identity** | IAM Identity Center, IAM roles, MFA | Staff single sign-on, least privilege, no long-lived keys on servers |
| **Security & monitoring** | CloudTrail, GuardDuty, Security Hub, AWS Config, CloudWatch | Audit trail, threat detection, compliance checks, alarms |
| **Connectivity** | Site-to-Site VPN | Encrypted links from each clinic |
| **Resilience** | AWS Backup | Scheduled backups with a cross-region copy for disaster recovery |
| **Migration** | AWS DMS, AWS DataSync | Moves the database and file shares from on-premises |

### Request flow

```
Clinic user → Route 53 → CloudFront + WAF → ALB → EC2 (private subnet) → RDS / S3
```

## 🧰 Stack

| Tool | Purpose | Status |
|---|---|---|
| draw.io | Architecture diagram | 🔜 Planned |
| AWS Pricing Calculator | Monthly cost estimate | 🔜 Planned |
| Terraform | Primary IaC: the full design, used for the live deploy | 🔜 Planned |
| AWS CloudFormation | Network layer, written for comparison | 🔜 Planned |
| AWS CDK | Network layer, written for comparison | 🔜 Planned |
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
- [ ] Phase 1: Design
- [ ] Phase 2: Diagram
- [ ] Phase 3: IaC
- [ ] Phase 4: Deploy
- [ ] Phase 5: Present

## 📁 Repository map

Folders fill in as each phase is built.

| Folder | What's inside |
|---|---|
| [`build-log/`](build-log) | **Step-by-step record of the build** |
| [`docs/`](docs) | Requirements, current state, shared responsibility map |
| [`docs/adr/`](docs/adr) | Architecture decision records |
| [`docs/cost/`](docs/cost) | Pricing Calculator estimate and optimization plan |
| [`diagrams/`](diagrams) | draw.io source and exported images |
| [`iac/terraform/`](iac/terraform) | Full design in Terraform |
| [`iac/cloudformation/`](iac/cloudformation) | Network layer in CloudFormation |
| [`iac/cdk/`](iac/cdk) | Network layer in AWS CDK |
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
