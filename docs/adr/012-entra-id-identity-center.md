# ADR 012 · Entra ID federated to IAM Identity Center

**Status:** Accepted
**Date:** 2026-11-03

## Context

The clinics already run Microsoft 365, so every employee has a Microsoft Entra ID account with MFA. Staff and IT need access to AWS accounts, the EHR, and Verified Access. When someone leaves, every one of those has to be cut off quickly, because a former employee with live access to PHI is a reportable risk.

## Options

| Option | Pros | Cons |
|---|---|---|
| A · Entra ID federated to IAM Identity Center (SAML + SCIM) | One identity and one password; Entra MFA and Conditional Access apply to AWS; disabling the Entra account removes access everywhere | Depends on Entra availability; setup across two systems |
| B · Identity Center's built-in directory | Self-contained in AWS; simple | A second set of users and passwords; offboarding has to be done twice, and one will get missed |

## Decision

Option A. Entra ID is the identity provider. Identity Center trusts it through SAML for sign-in and SCIM for automatic user and group sync.

## Why

- **One offboarding switch.** Disabling the user in Entra removes access to email, AWS, the EHR, and remote access at once.
- **Consistent MFA.** The same MFA and Conditional Access rules protect AWS and Microsoft 365.
- **Least privilege by group.** Entra groups map to Identity Center permission sets per account, and department and role flow into session tags for ABAC on `DataClass`.
- **No long-lived keys.** Staff get short-term credentials through Identity Center instead of IAM users with access keys.

## Consequences

- **Easier:** joiner, mover, and leaver handling; access reviews from one place.
- **Harder:** if Entra is down, sign-in to AWS fails. The alarmed break-glass account covers emergencies.
- **Revisit:** if Bayou ever leaves Microsoft 365, the identity provider changes and permission sets would need to be remapped.
