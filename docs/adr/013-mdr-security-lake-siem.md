# ADR 013 · MDR provider with Security Lake and a SIEM

**Status:** Accepted
**Date:** 2026-11-03

## Context

GuardDuty, Security Hub, and CloudTrail produce alerts and evidence, but someone has to watch them around the clock and respond. Bayou's IT team is small and works business hours. Attacks on healthcare often start at night and on weekends.

## Options

| Option | Pros | Cons |
|---|---|---|
| A · MDR provider watching a SIEM fed by Security Lake | 24/7 analysts and response; logs normalized to OCSF so the SIEM or provider can change later | Ongoing contract cost outside AWS; the provider needs a BAA because logs contain PHI |
| B · Native AWS tools only | No extra vendor; lower cost | Findings sit unread outside business hours; no correlation with clinic endpoint and firewall logs |
| C · In-house SOC | Full control | Needs at least five or six analysts to staff 24/7; far beyond a clinic network's budget |

## Decision

Option A. Security Lake in the Log Archive account collects AWS logs in OCSF format. The MDR provider's SIEM subscribes to it and also takes in clinic endpoint and firewall logs.

## Why

- **Someone is always watching.** A breach found Monday morning is a breach that ran all weekend.
- **Response, not just alerts.** The MDR provider can trigger the EventBridge quarantine runbook and contain an instance in minutes.
- **Swappable.** OCSF is an open schema, so changing SIEMs or providers doesn't mean re-plumbing the logs.
- **Native tools still run.** GuardDuty and Security Hub stay on as the detection layer feeding the SIEM.

## Consequences

- **Easier:** meeting HIPAA's requirement to review activity and respond to incidents.
- **Harder:** another vendor to manage, and a BAA to sign before any logs are shared.
- **Cost:** the MDR contract is outside the AWS estimate and listed under costs outside AWS.
- **Revisit:** if Bayou grows enough to hire security staff, a hybrid model (in-house days, MDR nights) becomes an option.
