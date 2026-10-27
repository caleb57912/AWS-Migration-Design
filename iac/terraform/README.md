# Terraform

The full design. Modules hold reusable building blocks; environments wire them together with environment-specific settings.

| Folder | What's inside |
|---|---|
| [`bootstrap/`](bootstrap) | The encrypted S3 bucket that stores Terraform state, created once before anything else |
| [`modules/`](modules) | One module per layer of the design |
| [`environments/prod/`](environments/prod) | Full production design, validated with `terraform plan` only |
| [`environments/dev/`](environments/dev) | Scaled-down dev design, validated with `terraform plan` only |
| [`environments/slice/`](environments/slice) | The live deploy slice: applied, verified, then destroyed |
