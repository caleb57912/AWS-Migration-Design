# ADR 004 · Multi-account landing zone with Control Tower

**Status:** Accepted
**Date:** 2026-11-03

## Context

Bayou Clinic Partners stores protected health information (PHI). HIPAA's minimum-necessary rule means people and systems should reach only the data their job requires. In AWS, the account is the strongest boundary available: IAM permissions, resource policies, billing, and service quotas all stop at the account edge.

The environment has three workload stages (Prod, Staging, Dev), a shared network, shared services, and security tooling. All of it has to be auditable, and the audit trail has to survive a compromise of any one workload.

## Options

| Option | Pros | Cons |
|---|---|---|
| A · One account, environments separated by tags and IAM | Simplest; cheapest; no cross-account networking | One bad policy or leaked admin key exposes everything; Dev mistakes can reach Prod; audit logs live where an attacker would be |
| B · A few hand-built accounts (Prod, Non-prod, Security) | Real separation with less setup | No standard baseline; guardrails built by hand; new accounts drift from the rest |
| C · Control Tower landing zone, 8 accounts | Guardrails apply to every account automatically; logs in a separate account; new accounts come out pre-secured | More moving parts; needs cross-account networking; steeper learning curve |

## Decision

Option C. An AWS Control Tower landing zone with home region us-west-2 and eight accounts:

| OU | Accounts |
|---|---|
| Root | Management |
| Security | Log Archive, Audit |
| Infrastructure | Network, Shared Services |
| Workloads | Prod, Staging, Dev |

## Why

- **Each account is its own layer of defense.** Permissions are scoped per account, so a user or role is granted only the accounts and actions the job needs. Least privilege is enforced by the boundary itself, not only by how carefully a policy was written.
- **Blast radius.** A compromised Dev account has no path into Prod unless one is explicitly built. In a single account, the same breach reaches everything.
- **Guardrails that even admins can't bypass.** Service control policies (SCPs) cap what any member account can do: region deny, deny untagged data resources, and protection for CloudTrail and Config. SCPs never grant permissions; they only limit them.
- **Evidence that survives an incident.** CloudTrail, Config, VPC Flow, and firewall logs from every account land in Log Archive with Object Lock. No workload admin can delete them, which is what makes them usable in an investigation or audit.
- **Central visibility.** Control Tower sets up the organization trail and Config baseline in every account, and drift detection flags changes to that baseline. GuardDuty and Security Hub run with the Audit account as delegated administrator, so the security team watches every account without having workload access.
- **Clean cost reporting.** Each account bills separately, so Prod, non-prod, networking, and security costs are visible without relying on tags alone.

## Consequences

- **Easier:** onboarding a new environment (Account Factory creates it with guardrails already in place); proving separation of PHI to an auditor; containing an incident to one account.
- **Harder:** traffic between accounts needs the Transit Gateway shared through AWS RAM; Terraform needs a provider per account; troubleshooting spans more consoles.
- **Cost:** Control Tower itself is free, but the services it turns on (Config, CloudTrail, the log buckets) are billed in every account. These are counted in the cost estimate's Security and Logging group.
- **Revisit:** the home region can't be changed after setup, so us-west-2 is locked in (see ADR 010). If Bayou adds a second business unit, a separate OU and SCP set would go under the Workloads level rather than in the existing accounts.
