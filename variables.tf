variable "region" {
  default = {
    "primary"   = "us-east-2"
    "secondary" = "us-east-1"
  }
}

variable "env" {
  default = {
    "first"  = "primary"
    "second" = "secondary"
  }
}

variable "global_id" {
  default = "global-1"
}

variable "delete" {
  default = "false"
}

variable "dbtype" {
  default = "db.r4.large"
}

variable "dbname" {
  default = "aurora"
}

variable "s_group" {
  default = {
    "primary"   = "sg-01696e7d5bc7ae46c"
    "secondary" = "sg-08608a9a7ca63525e"
  }
}

variable "db_subnets" {
  default = {
    "primary"   = ["subnet-0ae6d1a13074eb512", "subnet-005e29545e7b8687b", "subnet-0d3cc9d19a8506dad"]
    "secondary" = ["subnet-5d821604", "subnet-a9fd71cc", "subnet-bdcf7096"]
  }
}
