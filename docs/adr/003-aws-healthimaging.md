# ADR 003 · AWS HealthImaging

**Status:** Accepted
**Date:** 2026-11-03

## Context

The flagship's imaging suite and the clinics' X-ray rooms produce DICOM studies, which can run to hundreds of MB each. Studies must be kept for years, open quickly when a radiologist reads them, and be protected as PHI. Today an on-site PACS stores and serves them. The migration moves imaging to AWS alongside the EHR.

## Options

| Option | Pros | Cons |
|---|---|---|
| A · PACS software on EC2, images in S3 or EBS | Familiar to radiologists; vendor supports it as-is | Bayou patches, scales, and backs up the PACS servers; license costs; storage tiering managed by hand |
| B · AWS HealthImaging, fed by clinic routers over STOW-RS, read by the OHIF viewer over DICOMweb | Managed DICOM archive with no servers; fast image loading; automatic tiering for older studies; HIPAA-eligible; open standards | Newer service in few regions; no built-in viewer; staff and vendors adjust to a new workflow |
| C · Cloud PACS from a SaaS vendor | Fully managed | Images live in the vendor's environment, outside Bayou's controls; lock-in; per-study fees |

## Decision

Option B. AWS HealthImaging in the Prod account is the imaging archive. The PACS functions are split:

| Function | Component |
|---|---|
| Archive and image delivery | AWS HealthImaging |
| Viewer | OHIF in the app tier, launched from the EHR |
| Worklist and scheduling (RIS) | The EHR's radiology module |
| Upload from clinics | Store-and-forward DICOM routers at each site, sending over STOW-RS |

## Why

- **No PACS servers to run.** HealthImaging is managed, so there are no archive servers to patch, scale, or fail over. With PACS on EC2, that work stays with Bayou's small IT team.
- **One security environment, not two.** Images sit in Bayou's own AWS account under the same controls as the EHR: KMS customer managed keys, IAM and ABAC, CloudTrail, and private access through a VPC interface endpoint. A SaaS PACS would put PHI in a separate party's environment with its own access model to audit.
- **Storage that manages itself.** Imaging archives grow every year. HealthImaging moves studies that aren't accessed to a cheaper tier automatically and brings them back on access, with no lifecycle rules to maintain.
- **Open standards.** DICOMweb and STOW-RS mean the viewer can be swapped, or AI tools added, without moving the archive.
- **Fast reads.** Images are stored in a format built for streaming, so studies open quickly in the browser viewer.

## Consequences

- **Easier:** scaling storage without planning capacity; adding remote readers through Verified Access; keeping imaging and EHR under one set of controls.
- **Harder:** radiologists change viewers; the routers have to be configured at every site; HealthImaging is available in only a few regions, which fixed the DR region (ADR 010).
- **DR:** the design doesn't rely on HealthImaging having cross-region backup. A copy of each study goes to S3, replicates to us-east-1, and can be re-imported into a new data store (ADR 005).
- **Revisit:** if the radiology group needs features only a full PACS provides, such as advanced 3D tools, a vendor viewer can read from HealthImaging over DICOMweb without changing the archive.
