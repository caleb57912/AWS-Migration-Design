# ADR 011 · Interface engine active/passive behind an NLB

**Status:** Accepted
**Date:** 2026-11-03

## Context

The HL7 interface engine moves admissions, orders, and results between the EHR, the clinics, and outside labs. HL7 v2 messages travel over MLLP, which is raw TCP on port 2575. Messages for one patient have to arrive in order: an admission must be processed before the orders tied to it. If the engine is down, clinical data stops flowing.

## Options

| Option | Pros | Cons |
|---|---|---|
| A · Two nodes, active/passive across AZs, behind an internal NLB | Survives an AZ or instance failure in minutes; only one node processes at a time, so order is kept | Pays for a node that's idle most of the time; needs a failover mechanism |
| B · Single self-healing instance (Auto Scaling group of one) | Cheapest; simplest | Recovery waits for a new instance to launch and the engine to start; AZ failure means a longer outage |
| C · Active/active | Uses both nodes | Two nodes processing the same feeds can reorder messages, which is a patient-safety risk |

## Decision

Option A. Two engine nodes in AZ-a and AZ-b, active/passive, behind an internal Network Load Balancer listening on TCP 2575.

## Why

- **Why an NLB.** An ALB only understands HTTP. MLLP is plain TCP, so it needs a layer 4 load balancer.
- **Order is a safety issue.** Active/passive keeps one node in charge, so messages are processed in the order they arrive.
- **Faster recovery than self-healing.** The passive node is already running and configured; failover is minutes, not a full instance launch.
- **Senders queue.** HL7 senders hold and retry messages until they get an acknowledgment, so a short failover doesn't lose data.

## Consequences

- **Easier:** surviving an AZ failure without manual work.
- **Harder:** the engine's own failover and the NLB health checks have to agree on which node is active; this needs testing in Staging.
- **Cost:** a second engine instance running all the time.
- **Revisit:** if message volume outgrows one node, scale the node up (bigger instance) rather than out.
