# ADR 009 · Centralized egress with Network Firewall

**Status:** Accepted
**Date:** 2026-11-03

## Context

Servers in the workload VPCs need some outbound internet access: OS patches, EHR vendor updates, and EDR agent check-ins. A compromised server will use the same outbound path to send PHI to an attacker's server. Bayou runs Prod, Staging, Dev, and Shared Services VPCs, each across three AZs.

## Options

| Option | Pros | Cons |
|---|---|---|
| A · NAT gateway in every VPC | AWS's default pattern; no shared dependency | Every VPC needs a public subnet and an internet gateway; NAT blocks inbound only, so anything can go out to any destination; NAT gateways multiplied across VPCs and AZs |
| B · NAT plus Network Firewall in every VPC | Outbound filtering everywhere | Firewall endpoints in every AZ of every VPC; rules maintained in several places and drifting apart |
| C · Centralized egress VPC: workload VPCs → Transit Gateway → Network Firewall → NAT → internet | One set of rules in one place; no VPC holding PHI has an internet gateway; NAT charges waived behind Network Firewall | Shared dependency for all outbound traffic; traffic hairpins through the Transit Gateway, which adds data-processing cost |

## Decision

Option C. An egress VPC in the Network account with a Network Firewall endpoint and NAT gateway in each of three AZs. Workload VPC route tables send internet-bound traffic to the Transit Gateway, which sends it through the firewall. The firewall allows only an approved list of domains.

## Why

- **Fewer internet doors.** With NAT in every VPC, every VPC also needs a public subnet and an internet gateway. Each one is a path to the internet that can be misconfigured. Centralizing leaves one controlled exit, and the PHI VPCs have none of their own.
- **NAT doesn't filter outbound.** NAT only stops the internet from starting connections to a server. It does nothing when a server connects out. The domain allow-list means a compromised server can't reach an attacker's site.
- **One place to configure and monitor.** One rule set, one log stream to Log Archive, one place for the MDR provider to watch. Rules in several VPCs drift apart over time.
- **Still highly available.** "Central" doesn't mean one box: the firewall and NAT run in all three AZs, so losing an AZ doesn't cut off outbound traffic.
- **Cost.** Firewall endpoints are paid for once instead of in every VPC, and AWS waives NAT gateway charges for traffic processed by Network Firewall.

## Consequences

- **Easier:** proving to an auditor that PHI can only leave to approved destinations; adding a VPC means attaching it to the Transit Gateway and pointing its default route there.
- **Harder:** every new outbound destination needs an allow-list change, which can slow down vendor updates; the egress VPC must be treated as critical infrastructure.
- **Cost:** Transit Gateway data processing on every outbound byte, counted in the Network group of the estimate.
- **Revisit:** if a workload needs high outbound volume (for example, large vendor downloads), cache it in S3 or move it behind a VPC endpoint rather than widening the allow-list.
