# 01 · Repository and design plan

**Phase:** 1 · Design
**Result:** ✅ Repo created and published, design plan written with a reason for every foundation

## What I built

- A Git repo with a `.gitignore` that keeps Terraform state, variable files, and AWS keys out of version control from the first commit
- A portfolio README covering the scenario, target architecture, and roadmap
- A [design plan](../docs/design-plan.md) covering accounts, network, compute, data, imaging, identity, security monitoring, HA, cost, migration, and IaC
- The folder structure for every later phase

## Issues

| Issue | Cause | Fix |
|---|---|---|
| `bash: your-username: No such file or directory` | Bash read the `<` and `>` in a placeholder URL as file redirection, so the chain stopped after the commit | Re-ran `git remote add` with my real username |
| `Repository not found` on push | The remote repo didn't exist on GitHub yet | Created an empty repo on GitHub, then pushed |

## Decisions

| Decision | Why |
|---|---|
| Healthcare scenario | HIPAA gives the security design the most substance |
| AWS HealthImaging for medical images | Managed and DICOM-native, with no PACS servers to patch |
| Terraform as primary IaC; CloudFormation and CDK for the network layer only | One full build, plus a three-way comparison for the alternatives discussion |
| Separate Prod, Dev, and Security accounts | Environment isolation, and logs that workload admins can't delete |

## Skills

Git remotes · Repo hygiene · Cloud architecture planning · HIPAA-aware design
