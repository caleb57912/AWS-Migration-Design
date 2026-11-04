# ADR 008 · AWS Verified Access for remote staff

**Status:** Proposed
**Date:** 2026-11-03

## Context

Some staff work outside the clinics: remote radiologists reading studies, and staff checking the EHR from home. They need the EHR and the image viewer, both behind a private load balancer, and nothing else. Their devices are less controlled than clinic workstations.

## Options

| Option | Pros | Cons |
|---|---|---|
| A · AWS Verified Access | Zero trust: checks identity and device health on every request; grants one app, not a network; no VPN client | Higher cost per app-hour; not in the AWS Pricing Calculator; newer service |
| B · AWS Client VPN | Familiar; cheaper; works for any protocol | Puts the device on the network; a compromised laptop can scan and reach anything its routes allow |

## Decision

Option A. Verified Access in front of the private ALB, using Entra ID through IAM Identity Center for identity and a device trust provider for posture checks.

## Why

- **Least privilege at the network level.** A verified user on a healthy device reaches the EHR and viewer only. A VPN gives the device a route into the VPC.
- **Every request is checked.** Policies evaluate who the user is, their group, and device health on each request, not just at login.
- **Same identity everywhere.** Entra ID is already the identity source (ADR 012), so disabling one account cuts off email, the EHR, and remote access together.
- **Logging.** Verified Access logs every request with user and device context, which feeds the MDR's SIEM.

## Consequences

- **Easier:** onboarding remote readers without shipping VPN configs; proving who reached PHI from where.
- **Harder:** apps must sit behind the ALB; anything that needs raw network access doesn't fit this model.
- **Cost:** about $398 a month, added as a manual line because the calculator doesn't include it.
- **Revisit:** if remote access grows to many non-web tools, Client VPN for a small IT admin group could sit alongside it.
