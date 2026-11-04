# ADR 005 · Pilot light DR in us-east-1

**Status:** Accepted
**Date:** 2026-11-03

## Context

Multi-AZ design covers the loss of a data center within us-west-2. It doesn't cover the loss of the whole region. The recovery targets are:

| Tier | Systems | RTO (time to recover) | RPO (data that can be lost) |
|---|---|---|---|
| 1 | EHR, database, interface engine | 4 hours | 1 minute |
| 2 | Imaging archive | 24 hours | 15 minutes |
| 3 | Reporting | Best effort | Best effort |

A clinic network's budget can't support running two full environments.

## Options

| Option | RTO / RPO | Cost | Notes |
|---|---|---|---|
| A · Backup and restore | Hours to a day / hours | Lowest | Restoring the database from a snapshot is slow, and everything since the last backup is lost; misses the Tier 1 RPO |
| B · Pilot light | About 1 to 4 hours / about 1 second | Low | Data replicates continuously; servers are built only at failover |
| C · Warm standby | Minutes / seconds | Roughly double compute | A scaled-down copy of everything runs all the time |
| D · Active/active | Near zero / near zero | Highest | The vendor EHR is very unlikely to support running in two regions at once |

## Decision

Option B. A pilot light in us-east-1:

- **Always on:** a headless Aurora Global Database secondary (storage only, no instances), S3 Cross-Region Replication of the imaging archive to Glacier Deep Archive, weekly AWS Backup copies in a locked vault, golden AMI copies, a standby Transit Gateway peered to us-west-2, and GuardDuty and Config.
- **Built at failover:** the DR VPC's app tier from the copied AMIs (by Terraform), Aurora instances added to the promoted cluster, and clinic VPNs brought up on the standby Transit Gateway from pre-staged configs. Route 53 then fails the portal over.

## Why

- **The data is what can't be rebuilt.** Aurora Global Database replicates storage to us-east-1 with about one second of lag, so the RPO is about one second, well inside the 1-minute target. Servers can be rebuilt from AMIs and code; patient records can't.
- **Backup and restore misses the targets.** Restoring the EHR database from snapshots takes too long, and the last snapshot could be hours old.
- **Warm standby costs too much for what it adds.** It would cut recovery from hours to minutes, but it means paying for idle servers every month. A 4-hour RTO is acceptable for a regional outage, which is rare.
- **The cost fits.** The DR group is about $300 a month in the estimate, compared with roughly doubling Prod compute for warm standby.
- **Imaging gets a looser target on purpose.** Studies are re-imported from the replicated S3 archive; clinic DICOM routers store new studies locally until the new data store is ready.

## Consequences

- **Easier:** surviving a regional outage without losing patient data; keeping DR cost predictable.
- **Harder:** recovery depends on a runbook and Terraform working under pressure. It's tested with a full DR drill twice a year and quarterly AZ experiments with Fault Injection Service in Staging.
- **Risk:** failover is a manual decision. Someone has to declare the disaster before the clock starts.
- **Revisit:** if the business decides 4 hours of downtime is too long, warm standby for the EHR tier only is the next step up.
