# ADR 006 · Hybrid Direct Connect + VPN

**Status:** Accepted
**Date:** 2026-11-03

## Context

All eight clinics send EHR traffic, HL7 messages, and imaging studies to AWS throughout the day. The flagship clinic is the primary medical facility and houses the imaging suite, so it produces the largest files and the most traffic. The other seven clinics send EHR traffic and occasional X-rays. If a clinic loses its connection, clinical work at that site stops. HIPAA expects PHI to be encrypted in transit on every path.

## Options

| Option | Pros | Cons |
|---|---|---|
| A · Site-to-Site VPN only, all 8 clinics | Cheapest; set up in days | Internet performance varies; each tunnel tops out around 1.25 Gbps; imaging uploads compete with all other internet traffic |
| B · Direct Connect at every clinic | Consistent, dedicated performance everywhere | A carrier circuit and port for each site; weeks of lead time each; far more capacity than small clinics use |
| C · Hybrid: Direct Connect + VPN at the flagship, internet VPN at the other 7 | Spends money where the traffic is; every path encrypted; flagship has a backup | Two connection types to manage; DX takes weeks to order |

## Decision

Option C.

| Site | Primary path | Backup path |
|---|---|---|
| Flagship | 1 Gbps Direct Connect at DataBank HOU3 (Houston), with a Site-to-Site VPN running over it | Site-to-Site VPN over the internet |
| 7 clinics | Site-to-Site VPN over the internet (two tunnels each) | The second tunnel |

All connections terminate on the Transit Gateway in the Network account and pass through Network Firewall inspection.

## Why

- **Capacity where it's needed.** The flagship is the primary facility and generates the imaging volume. A dedicated 1 Gbps circuit gives it steady bandwidth that isn't shared with internet traffic, so EHR use and image uploads stay fast through the day.
- **The other seven don't need it.** Their traffic fits comfortably in an IPsec VPN, which is encrypted and costs a fraction of a circuit.
- **Cost.** Direct Connect means a port fee plus a carrier circuit from the clinic to the Houston facility. Paying that eight times buys capacity seven of the clinics would never use.
- **Encryption on the private line.** Direct Connect is a private circuit, but it isn't encrypted. Running the VPN over it keeps PHI encrypted in transit, as HIPAA expects.
- **No single point of failure.** One DX circuit is still one circuit; a fiber cut or a carrier outage takes it down. The internet VPN is the backup, and BGP fails over to it automatically, at lower speed, until DX returns.

## Consequences

- **Easier:** the flagship's imaging workload runs on predictable bandwidth; adding a new small clinic is a router config and one VPN connection.
- **Harder:** two connection types to monitor; BGP preferences must be set so DX is preferred and the internet VPN is used only on failure.
- **Lead time:** the DX circuit is ordered in migration wave 0, because provisioning can take weeks.
- **Cost:** the carrier circuit is billed by the carrier, outside the AWS estimate.
- **Revisit:** a second DX circuit at a different location if the flagship's traffic grows or the business can't tolerate running on internet VPN during an outage. If a smaller clinic adds imaging, it may need its own DX.
