# ADR 007 · Terraform as primary IaC

**Status:** Accepted
**Date:** 2026-11-03

## Context

The environment spans eight accounts and two regions, and Prod, Staging, and Dev have to be built the same way. Building by hand in the console isn't repeatable or reviewable. The class covers CloudFormation and the AWS CDK, and the build also needs to demonstrate them.

## Options

| Option | Pros | Cons |
|---|---|---|
| A · Terraform | Most requested IaC tool in job postings; one tool across many accounts; `plan` previews every change; large module ecosystem | State file to protect and lock; not an AWS product; license changed to BSL in 2023 |
| B · AWS CloudFormation | Native to AWS; no state file to manage; StackSets deploy across accounts | Verbose YAML; slower feedback; AWS-only |
| C · AWS CDK | Real programming language (Python); reusable constructs | Compiles to CloudFormation and inherits its limits; another toolchain to learn |

## Decision

Option A for the whole build. The network layer is also written in CloudFormation and CDK (Python) for comparison, validated in CI, and not deployed.

## Why

- **Career value.** Terraform is the IaC skill most cloud and security job postings ask for.
- **Multi-account in one place.** One configuration uses a provider per account and region, so the hub and spokes are defined together.
- **Safe changes.** `terraform plan` shows exactly what will change before anything happens.
- **Consistency.** Every environment uses the same modules with a small settings file. Changes flow Dev → Staging → Prod.
- **Tag enforcement.** Provider `default_tags` stamps the mandatory tags on every resource.
- **Comparison.** Writing the network layer three ways shows the trade-offs between the tools rather than just naming them.

## Consequences

- **Easier:** rebuilding any environment; reviewing changes as code; running scanners (TFLint, Checkov) before deploy.
- **Harder:** state must be protected. It lives in an encrypted, versioned S3 bucket with native S3 locking, and it can contain sensitive values.
- **Revisit:** if the license change matters to Bayou, OpenTofu is a drop-in fork.
