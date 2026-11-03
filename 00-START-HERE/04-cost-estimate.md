# 04 · Cost estimate

**Phase:** 1 · Design
**Result:** ✅ Full design priced in the AWS Pricing Calculator: **$6,645/month adjusted (~$79,700/year)** across 7 account groups, 39 calculator lines, and 5 sourced manual adjustments. Full write-up: [Cost Estimate](../docs/cost/README.md)

## What I built

- An estimate with one group per account area: Prod, Network, Shared Services, Security and Logging, Edge, DR, Staging and Development
- 18 written sizing assumptions, each with its reasoning
- Five manual adjustments for things the calculator doesn't model, each sourced from an AWS pricing page
- A cost-of-security breakdown and a cost-by-purpose chart
- CSV and PDF exports committed to [`docs/cost/`](../docs/cost)

## The numbers

| | Monthly |
|---|---:|
| Calculator total | $6,348.00 |
| Manual adjustments | +$297.20 |
| **Adjusted total** | **$6,645.20** |
| Security and compliance share | $2,614.32 (39%) |
| Production workload share | $1,597.70 (24%) |

## Issues

| Issue | Cause | Fix |
|---|---|---|
| TGW data priced at 60 TB instead of 4 TB | Field was per attachment, not total | Divided the total by attachment count; recounted when a peering attachment was added |
| Inspection traffic underpriced | Traffic through the firewall crosses the Transit Gateway twice | Doubled TGW ingress for the hairpin |
| Direct Connect at ~$1,600/month | Port defaulted to 10 Gbps | Set 1 Gbps, Houston location |
| GuardDuty pricing single events | Unit defaulted to "per month" instead of millions | Entered plain counts |
| Bot Control and Verified Access missing | Not modeled in the calculator | Priced from AWS pricing pages as manual lines |
| NAT gateways double-counted | Calculator ignores the Network Firewall NAT waiver | −$121 manual adjustment |
| Hidden RDS Proxy charge | Proxy defaulted to Yes on Aurora | Set to No |
| DR backups at $367/month | Each cross-region Aurora copy is a full snapshot | Switched 35 daily copies to 5 weekly |
| Cross-region transfer showing $0 | Priced on the receiving region | Moved to the sending region |
| Non-prod disks underpriced | Calculator scaled EBS with the 36% compute schedule | Separate 24/7 EBS line |
| Non-prod EBS at $121/month | Snapshot frequency defaulted to 2x daily | No snapshots on disposable disks |
| No Serverless v2 option | Calculator lacks it for Aurora PostgreSQL | Provisioned stand-in at 36%, documented |

## Decisions

| Decision | Why |
|---|---|
| 1-year Compute Savings Plan on Prod baseline only | Applies across regions and families, so it still covers DR rebuilds and resizing |
| Aurora I/O-Optimized in Prod, Standard in non-prod | Predictable bill for a busy EHR; non-prod I/O is negligible and billing mode doesn't change behavior |
| Headless Aurora secondary in DR | Data stays current without paying for an idle server |
| Minimal standby network | Hub and peering stay up; clinic VPNs are built at failover inside the 4-hour RTO |
| 5 weekly DR backup copies | Daily recovery stays in Oregon; DR keeps weekly copies for the double-failure case |
| Business-hours Staging, same 3-AZ shape | Matches Prod in shape, not hours |
| Steady-state pricing, no trials | Avoids a month-three surprise |

## What I learned

- Hourly prices look tiny until multiplied by 730 hours and every instance
- In a hub-and-spoke design, fixed attachment and endpoint hours outweigh data charges
- Calculator defaults consistently favored spending more
- A replica is not a backup, and a cross-region backup copy is a full copy
- Stopped servers stop billing; their disks don't
- The region a byte leaves pays for it

## Skills

Cloud cost modeling · AWS Pricing Calculator · Commitment strategy · DR cost trade-offs · Reading pricing pages · Assumption documentation
