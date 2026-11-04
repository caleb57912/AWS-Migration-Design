# ADR 001 · Replatform the vendor EHR onto EC2 and Aurora

**Status:** Accepted
**Date:** 2026-11-03

## Context

Bayou runs a vendor EHR on servers in its own facilities. Staff at all eight clinics use it every day, and its database holds years of patient records. The migration has to improve availability and security without disrupting clinical work. Bayou doesn't own the EHR's source code.

AWS groups migration strategies into the "7 Rs." Four apply here.

## Options

| Option | Pros | Cons |
|---|---|---|
| A · Rehost (lift and shift app and database servers to EC2) | Fastest; lowest change risk | Bayou still patches, backs up, and fails over its own database; the riskiest part of the EHR is unchanged |
| B · Replatform (app servers to EC2 with AWS MGN, database to Aurora with AWS DMS) | Managed, multi-AZ database without changing the vendor's application; staff keep the system they know | Vendor must support PostgreSQL on Aurora; database cutover needs careful testing |
| C · Repurchase (switch to a SaaS EHR) | No servers to run | A new system for every clinician; years of records converted; the vendor controls PHI, uptime, and pricing; lock-in |
| D · Refactor (rebuild as cloud-native) | Best long-term fit | Not possible without the source code; even with it, years of development |

## Decision

Option B.

| Component | How it moves | Where it lands |
|---|---|---|
| EHR application servers | AWS Application Migration Service (MGN), continuous block-level replication | EC2 Auto Scaling groups from golden AMIs |
| EHR database | AWS Database Migration Service (DMS), full load plus ongoing change capture | Aurora PostgreSQL |
| Cutover | Weekend window, flagship first, 30-day rollback period | Old servers wiped to NIST 800-88 after rollback closes |

## Why

- **Staff keep the system they know.** Clinicians use the same EHR the day after cutover. No retraining, no data conversion to a new product.
- **Fix the weakest part, leave the rest alone.** A self-run database is the hardest piece to keep available and secure. Moving it to Aurora gives multi-AZ storage, automatic failover, Global Database for DR, and KMS encryption. The vendor's application isn't touched.
- **Build the platform around it.** Replatforming lets the infrastructure be designed for AWS: Auto Scaling with a minimum per AZ, golden AMIs, Session Manager instead of SSH, and the security controls in the other ADRs.
- **Rehosting just moves the problem.** The same database administration and single points of failure would follow the servers to AWS.
- **SaaS trades control for convenience.** It removes the servers but puts PHI, uptime, and future costs in a vendor's hands, and makes leaving expensive.
- **Refactoring isn't available.** Without the source code, the application can't be rebuilt; even with it, it would take a development team years.

## Consequences

- **Easier:** surviving an AZ failure; patching through AMIs; meeting the Tier 1 DR targets.
- **Harder:** the vendor must confirm support for Aurora PostgreSQL and for running on EC2; DMS replication must be watched closely until cutover.
- **Risk:** cutover weekend is the riskiest point; the 30-day rollback keeps the old environment available until the new one is proven.
- **Revisit:** if the vendor releases a hosted version that meets Bayou's security and BAA requirements, repurchase can be reconsidered at the next contract renewal.
