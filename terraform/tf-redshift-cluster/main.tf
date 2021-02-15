provider "aws" {
  region = "eu-central-1"
  profile = "redshift"
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

######
# VPC
######
module "vpc" {
  source  = "../modules/terraform-aws-vpc"

  name = "jimdo-vpc"

  cidr = "10.10.0.0/16"

  azs              = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  redshift_subnets = ["10.10.41.0/24", "10.10.42.0/24", "10.10.43.0/24"]

}

###########################
# Security group
###########################
module "sg" {
  source  = "../modules/terraform-aws-security-group//modules/redshift"

  name   = "jimdo-redshift"
  vpc_id = module.vpc.vpc_id

  # Allow ingress rules to be accessed only within current VPC
  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]

  # Allow all rules for all protocols
  egress_rules = ["all-all"]
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.eu-central-1.s3"
}

#############
### Redshift
#############
module "redshift" {
  source = "../modules/terraform-aws-redshift"


  cluster_identifier      = "jimdo-cluster"
  cluster_node_type       = "dc1.large"
  cluster_number_of_nodes = 1

  cluster_database_name   = "mydb"
  cluster_master_username = "mydbuser"
  cluster_master_password = "Password123"
  final_snapshot_identifier = "test"

  subnets                = module.vpc.redshift_subnets
  vpc_security_group_ids = [module.sg.this_security_group_id]
}


