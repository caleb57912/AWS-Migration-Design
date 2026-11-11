module "network" {
  source     = "../../modules/network"
  name       = "bayou-slice"
  cidr_block = "10.10.0.0/16"
  azs        = ["us-west-2a", "us-west-2b", "us-west-2c"]
}
