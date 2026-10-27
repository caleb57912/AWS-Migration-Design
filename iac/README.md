# Infrastructure as code

| Folder | Tool | Scope | Deployed? |
|---|---|---|---|
| [`terraform/`](terraform) | Terraform | Full design | Slice only |
| [`cloudformation/`](cloudformation) | AWS CloudFormation | Network layer | No, linted only |
| [`cdk/`](cdk) | AWS CDK | Network layer | No, synthesized only |

The network layer is built the same way in all three so they can be compared side by side.
