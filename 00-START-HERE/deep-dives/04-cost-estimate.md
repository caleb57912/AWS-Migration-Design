# Deep dive 04 · Cost estimate

Full record of how I priced the Bayou Clinic Partners design. The finished estimate lives in [`docs/cost/`](../../docs/cost).

## Method

1. Wrote sizing assumptions before opening the calculator, so every input traced back to a reason
2. Created one estimate group per account area, so cost reads like showback by `CostCenter`
3. Priced the big drivers first (compute, database, network, security), then the smaller services
4. After every form, compared the result to a rough hand estimate and expanded **Show calculations** whenever they disagreed
5. Recorded anything the calculator couldn't model as a sourced manual adjustment
6. Exported CSV and PDF and checked every line against the design

## Tooling

| Item | Value |
|---|---|
| Tool | AWS Pricing Calculator (calculator.aws), no account required |
| Estimate name | Bayou Clinic Partners - AWS Migration |
| Regions | us-west-2 (primary), us-east-1 (DR) |
| Export date | November 3, 2026 |
| Exports | [`pricing-calculator-export.csv`](../../docs/cost/pricing-calculator-export.csv), [`pricing-calculator-estimate.pdf`](../../docs/cost/pricing-calculator-estimate.pdf) |

## Group-by-group walkthrough

### Prod ($1,597.70)

| Line | Key inputs | Check |
|---|---|---|
| EHR servers | 3 × m7i.xlarge, Compute Savings Plan 1 yr, 100 GB gp3 | $324.36 compute + $24.00 disks = $348.36 |
| Interface engine | 2 × m7i.large, 200 GB gp3, daily snapshots | First snapshot is a full copy (~$20), so it landed above the hand estimate |
| OHIF viewer | 3 × t3.small, 30 GB gp3 | $32.85 + $7.20 |
| Aurora | 2 × db.r7g.large, I/O-Optimized, Reserved 1 yr, 500 GB | My first guess was $20; the real figure is ~30× that because 730 h × 2 nodes |
| Documents | 5 TB Intelligent-Tiering, 500 KB objects | Corrected the 16 MB default |
| Imaging archive copy | 20 TB Deep Archive + 250 GB/month outbound to us-east-1 | Transfer billed here, in the sending region |
| HealthImaging | 20 TB, 10/90 tier split | No retrieval charges; viewing cost is network egress |

### Network ($2,588.67 → $2,467.67)

| Line | Key inputs | Check |
|---|---|---|
| Transit Gateway | 16 attachments, 512 GB each (8,190 GB total) | Includes the inspection hairpin; recalculated per-attachment data when the DR peering attachment was added |
| Site-to-Site VPN | 9 connections, 24/7 | 9 × 730 × $0.05 |
| NAT | 3 zonal, 167 GB each | Regional NAT section left incomplete so it priced $0; waived by Network Firewall |
| Network Firewall | 3 endpoints × 730 h, 4 TB | $865 endpoint-hours + $266 data; TLS inspection and secondary endpoints left out |
| Direct Connect | 1 Gbps, DataBank HOU3, 2 TB out | Closest location to the clinic, not to Oregon |

### Shared Services ($363.40)

| Line | Key inputs | Check |
|---|---|---|
| PrivateLink | 7 endpoints × 3 AZs, 2.5 TB total | 21 ENIs × 730 × $0.01 + data |
| Route 53 Resolver | 2 inbound ENIs, 5 M queries | Outbound deferred; reversible in minutes |

### Security and Logging ($1,029.83)

| Line | Key inputs | Check |
|---|---|---|
| CloudWatch | 120 GB ingested, 350 GB vended to S3, 50 alarms | Split routing: only alarm-driving logs pay CloudWatch prices |
| Log Archive | 0.5 TB Standard + 2.5 TB Glacier IR | PUT requests cost more than storage (millions of small files) |
| CloudTrail | First copy free, 10 M data events | HealthImaging events folded into the S3 field at the same rate |
| GuardDuty | Flow 200 GB, DNS 50 GB, events, RDS, EC2 runtime | Fixed units and EKS/Serverless fields placed in the wrong section |
| Security Hub | 8 accounts × 10,000 checks | Consolidated controls avoid paying four times per finding |
| Config | 20,000 CIs, rules, HIPAA pack | Continuous in Prod/Network/Security, periodic in non-prod |
| Security Lake | 20 GB CloudTrail + 265 GB other | Custom sources (firewall, access logs) carry no ingestion fee |
| Macie | 5 TB scope | Excluded known-PHI log buckets and Deep Archive (unreadable) |
| Audit Manager | 8 × 50 × 110 evidence items | Priced without the 2-month free tier |
| Inspector | 18 instances | Average count, not peak |

### Edge ($25.15 → $438.35)

| Line | Key inputs | Check |
|---|---|---|
| CloudFront | 50 GB, 5 M requests, pay-as-you-go | VPC origins add no cost |
| WAF | 1 ACL, 2 custom rules, 4 managed groups | Anonymous IP list and ATP left out on purpose |
| Route 53 | 3 zones, 1 M queries, 2 health checks | Health checks on AWS endpoints are permanently free |
| Bot Control (manual) | $10 + $5 | No free allowance |
| Verified Access (manual) | 2 apps × 730 h × $0.27 + $4 | Per application, not per user |

### DR ($301.42 → $306.42)

| Line | Key inputs | Check |
|---|---|---|
| Aurora Global secondary | 0 nodes, 500 GB storage | Instance set to db.r7g.large so the record shows the failover size |
| Imaging replica | 20 TB Deep Archive | Inbound transfer is free; sender pays |
| AWS Backup | Aurora 5 weekly + EBS 330 GB × 2 monthly | 35 daily full copies would have cost $367 |
| Standby TGW | 2 attachments | Peering is billed on both TGWs |
| GuardDuty, Config | Light volumes | Detection must run in every allowed region |

### Staging and Development ($441.83)

| Line | Key inputs | Check |
|---|---|---|
| EC2 (4 lines) | On-demand, 36% utilization, no EBS | 262.8 h each |
| Aurora Staging | 2 × db.r7g.large, Standard, 36% | Provisioned stand-in for Serverless v2 |
| Aurora Dev | 1 × db.t4g.medium, Standard, 36% | |
| S3 | 400 GB Standard | |
| EBS | 11 × 50 GB, 730 h, no snapshots | Separate line because stopped servers keep their disks |

## Issues in detail

| # | Symptom | Root cause | Resolution | Lesson |
|---|---|---|---|---|
| 1 | Aurora estimate 30× my guess | Forgot 730 h × 2 nodes | Kept as designed | Always multiply by 730 |
| 2 | Intelligent-Tiering fee too low | 16 MB default object size | 500 KB | Defaults are AWS guesses, not my scenario |
| 3 | HealthImaging form error | Typed TB into percent fields | Total + % split | Split fields divide a total |
| 4 | Regional NAT couldn't be zeroed | Required field | Left incomplete so it priced $0 | Alternatives sit in the same form |
| 5 | TGW data 15× too high | Per-attachment field | Total ÷ 15, then ÷ 16 | Recheck "per" fields when counts change |
| 6 | TGW hairpin | Inspection crosses TGW twice | Doubled ingress | Security routing has a network cost |
| 7 | GuardDuty fields in wrong sections | EKS and Serverless labels next to EC2 and provisioned | Moved values | Read the service name in the label |
| 8 | Bot Control and Verified Access missing | Not in calculator | Manual lines from pricing pages | Estimates have documented adjustments |
| 9 | RDS Proxy silently charging | Default Yes | Set No in every Aurora line | A default can hide in a verified line |
| 10 | DR backups $367 | Full-copy cross-region snapshots | 5 weekly copies | Retention frequency matters as much as length |
| 11 | Replication transfer $0 | Priced on receiving side | Priced in Oregon | Sender pays |
| 12 | Non-prod EBS scaled to 36% | Calculator tied disks to compute hours | Separate 24/7 EBS line | Stopped servers keep billing for disks |
| 13 | Non-prod EBS $121 | 2x daily snapshot default | No snapshots | Don't back up disposable disks |
| 14 | No Serverless v2 | Calculator gap | Provisioned stand-in | Document stand-ins |

## Verification

| Check | Result |
|---|---|
| Group totals sum to calculator total | ✅ $6,348.00 |
| Adjusted total recomputed by hand | ✅ $6,645.20 |
| Every line has a description | ⚠️ CloudWatch blank (cosmetic) |
| No free tiers or trials in steady-state numbers | ✅ (permanent Route 53 health-check tier kept) |
| No account IDs, ARNs, or personal data in exports | ✅ |
| Each manual adjustment sourced | ✅ |

## Evidence

Screenshots for this step go in `screenshots/build-log/04-cost-estimate/`:

- Estimate summary with all 7 groups
- Network Firewall pricing page (NAT waiver)
- WAF Bot Control pricing table
- Verified Access pricing table
- DR AWS Backup calculation (daily vs. weekly)
- Non-prod EBS calculation showing the 36% scaling trap

## Backlog

- [ ] Add the calculator share link to `docs/cost/README.md` and re-export the PDF so the URL is filled
- [ ] Fill the CloudWatch description
- [ ] Correct HealthImaging metadata fields to 50 MB / 2 series / 5 SOP
- [ ] Add S3 data events to DR GuardDuty
- [ ] Add redacted screenshots to the evidence folder
- [ ] Build a qualitative TCO comparison against an on-prem hardware refresh for the cost slide
