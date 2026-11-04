# ADR 002 · Aurora PostgreSQL

**Status:** Proposed
**Date:** 2026-11-03

## Context

The vendor EHR keeps every patient record in a relational database and is assumed to be certified on PostgreSQL. The database is a Tier 1 system: RTO 4 hours and RPO 1 minute for a regional disaster, and minutes for an AZ failure. It holds `restricted` data, so it needs encryption, query auditing, and backups an attacker can't delete.

## Options

| Option | Pros | Cons |
|---|---|---|
| A · Aurora PostgreSQL | Storage keeps six copies across three AZs; failover typically under a minute; readable replicas; Global Database for cross-region DR with about one second of lag | Higher instance cost than RDS; AWS-specific storage layer |
| B · RDS PostgreSQL Multi-AZ | Lower cost; standard PostgreSQL storage | Standby in the classic setup can't serve reads; cross-region DR relies on read replicas with more lag and a slower promotion |
| C · Self-managed PostgreSQL on EC2 | Full control of version and settings | I own patching, backups, replication, and failover; more ways to get HIPAA controls wrong |

## Decision

Option A. Aurora PostgreSQL, I/O-Optimized, with one writer and one reader on db.r7g.large in different AZs, and an Aurora Global Database secondary in us-east-1.

## Why

- **Availability.** Storage is spread across three AZs automatically. If the writer's AZ fails, the reader is promoted, usually in under a minute.
- **Disaster recovery.** Global Database replicates storage to us-east-1 with about one second of lag, which meets the 1-minute RPO. Promotion takes minutes.
- **Security with less effort.** KMS customer managed key per environment, TLS required, credentials in Secrets Manager with rotation, pgAudit for query logging, and AWS Backup with Vault Lock.
- **I/O-Optimized.** An EHR is read- and write-heavy. Paying for I/O by the request makes the bill unpredictable; I/O-Optimized folds it into the instance and storage price.
- **Less to operate.** A small IT team shouldn't be running database failover by hand.

## Consequences

- **Easier:** surviving an AZ loss, meeting the DR targets, and proving who queried which records.
- **Harder:** moving off AWS later; Aurora's storage layer isn't portable, though the data is standard PostgreSQL.
- **Cost:** Aurora costs more per instance than RDS. The 1-year Reserved pricing in the cost estimate offsets part of that.
- **Revisit:** if the EHR vendor certifies only a specific PostgreSQL version Aurora doesn't support, RDS Multi-AZ becomes the fallback.
