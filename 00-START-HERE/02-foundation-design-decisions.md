# 02 · Foundation design decisions

**Phase:** 1 · Design
**Result:** ✅ Accounts, data classification, regions, network, edge, and workload placement decided and written into the [design plan](../docs/design-plan.md)

## What I decided

| Layer | Decision |
|---|---|
| Accounts | Eight-account AWS reference structure (Management, Log Archive, Audit, Network, Shared Services, Prod, Staging, Dev) built with Control Tower |
| Data classification | Four sensitivity tiers (`public` → `restricted`) plus a separate `Compliance` tag for HIPAA and PCI scope |
| Enforcement | Prevent and detect: tag policy, an SCP that blocks unlabeled data resources, Config rules, and ABAC on PHI |
| Tags | Eight required tags: `Environment`, `Owner`, `CostCenter`, `Application`, `DataClass`, `Compliance`, `BackupPolicy`, `ManagedBy` |
| Regions | us-west-2 primary, us-east-1 DR, every other region blocked |
| VPCs | Three AZs in every environment; IPAM-managed ranges; app, integration, and data tiers with no internet gateway in any VPC holding PHI |
| Connectivity | Transit Gateway hub; Direct Connect with VPN over it at the flagship clinic; Site-to-Site VPN at the other seven |
| Egress and inspection | Centralized egress with Network Firewall allow-listing; inspection on clinic and inter-VPC traffic |
| Filtering | Security groups referencing each other, baseline NACLs at tier boundaries |
| Edge | Only the patient portal is public; CloudFront VPC origins to a private load balancer; WAF with login rate limits and Bot Control; Shield Standard; Verified Access for remote staff |
| Workloads | Replatformed vendor EHR with its portal and radiology module; interface engine in the integration tier; store-and-forward DICOM routers at each clinic |

## Key trade-offs

| Trade-off | Why I accepted it |
|---|---|
| us-west-2 has roughly double the latency from Louisiana | Stability over a few milliseconds; CloudFront offsets it for patients |
| Three AZs in non-prod raises cost | Staging and Dev behave like Prod, so failover tests prove something |
| Network Firewall and Verified Access are expensive | They stop data exfiltration and lateral movement from the most likely entry point, a phished clinic workstation |
| Direct Connect only at the flagship clinic | Spends money where the imaging volume is; VPN is enough elsewhere |

## What I learned

- Direct Connect is private but not encrypted; a VPN on top supplies the encryption
- SCPs never grant permissions; they only cap what IAM policies can allow
- A public subnet is defined by its route table, not a setting
- Logs and backups inherit the classification of the data they record

## Skills

Multi-account governance · Data classification · VPC and IP design · Hybrid connectivity · Zero-trust access · Defense in depth
