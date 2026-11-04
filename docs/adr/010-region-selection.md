# ADR 010 · us-west-2 primary, us-east-1 DR

**Status:** Proposed
**Date:** 2026-11-03

## Context

The clinics are in Louisiana. The primary region also becomes the Control Tower home region, which can't change later. PHI has to stay in the US, and both regions need AWS HealthImaging for the imaging archive.

## Options

| Option | Pros | Cons |
|---|---|---|
| A · us-west-2 primary, us-east-1 DR | us-west-2 has a steadier outage history; both regions have HealthImaging and Control Tower | Roughly double the network latency from Louisiana compared to us-east-1 |
| B · us-east-1 primary, us-west-2 DR | Lowest latency from Louisiana; newest features usually launch here first | Largest and busiest region with the longest history of major outages; many AWS global services depend on it |

## Decision

Option A. us-west-2 (Oregon) is primary and the Control Tower home region; us-east-1 (N. Virginia) is the pilot-light DR region.

## Why

- **Stability.** us-east-1 has had the most widely felt AWS outages. The primary region should be the one least likely to fail.
- **Service coverage.** HealthImaging is available in only a few regions. us-east-1 is the only other US region that has it, which makes it the DR site by default.
- **Latency is acceptable.** The EHR is a web app used by staff; tens of extra milliseconds aren't noticeable. CloudFront serves the patient portal from edge locations close to users.
- **Guardrail.** An SCP denies every region except these two, which keeps PHI in the US by policy.

## Consequences

- **Easier:** DR planning, since the DR region is fixed by service availability.
- **Harder:** traffic from the Houston Direct Connect location travels farther to reach Oregon; cross-region transfer is billed.
- **Revisit:** if HealthImaging launches in another US region (such as us-east-2), the DR region choice should be re-checked.
