# Scripts

Helper scripts I run during the build.

| Script | Purpose |
|---|---|
| `check-secrets.sh` | Scans files for keys, account IDs, and public IPs before a commit |
| `scan-iac.sh` | Runs Checkov, `terraform validate`, and `cfn-lint` across `iac/` |
| `verify-teardown.sh` | Confirms nothing billable is left running after `terraform destroy` |
