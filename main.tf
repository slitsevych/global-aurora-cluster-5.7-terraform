# Initializing empty default provider and two working aws providers in two regions with aliases

provider "aws" {
  region = "us-east-2"
}

provider "aws" {
  region                  = var.region["primary"]
  alias                   = "primary"
}

provider "aws" {
  region                  = var.region["secondary"]
  alias                   = "secondary"
}

# Creating DB subnet groups in two regions
resource "aws_db_subnet_group" "aurora_subnet_primary" {
  provider   = aws.primary
  name       = "${var.env["first"]}-aurora-subnet"
  subnet_ids = var.db_subnets["primary"]
}

resource "aws_db_subnet_group" "aurora_subnet_secondary" {
  provider   = aws.secondary
  name       = "${var.env["second"]}-aurora-subnet"
  subnet_ids = var.db_subnets["secondary"]
}

# Provisioning primary DB cluster and one instance within it
resource "aws_rds_cluster" "primary" {
  provider               = aws.primary
  cluster_identifier     = "${var.env["first"]}-aurora-cluster"
  availability_zones     = ["us-east-2a", "us-east-2b", "us-east-2c"]
  database_name          = var.dbname
  master_username        = var.dbname
  master_password        = "${var.dbname}123"
  engine                 = "aurora-mysql"
  engine_version         = "5.7.mysql_aurora.2.07.0"
  port                   = "3306"
  db_subnet_group_name   = aws_db_subnet_group.aurora_subnet_primary.id
  skip_final_snapshot    = true
  vpc_security_group_ids = [var.s_group["primary"]]

  lifecycle {
    ignore_changes = [master_password]
  }
}

resource "aws_rds_cluster_instance" "aurora-primary" {
  provider            = aws.primary
  identifier          = "aurora-${var.env["first"]}"
  cluster_identifier  = aws_rds_cluster.primary.id
  engine              = "aurora-mysql"
  engine_version      = "5.7.mysql_aurora.2.07.0"
  instance_class      = var.dbtype
  publicly_accessible = false

  depends_on = [aws_rds_cluster.primary]

  tags = {
    Name = "aurora-${var.env["first"]}"
  }
}

# Transforming previously created cluster into global cluster
resource "null_resource" "join_cluster" {
  provisioner "local-exec" {
    command = "aws rds create-global-cluster --global-cluster-identifier ${var.global_id} --source-db-cluster-identifier ${aws_rds_cluster.primary.arn}"
  }
  depends_on = [
    aws_rds_cluster.primary,
    aws_rds_cluster_instance.aurora-primary
  ]
}

resource "null_resource" "delay" {
  provisioner "local-exec" {
    command = "sleep 240"
  }
  depends_on = [
    null_resource.join_cluster
  ]
}

# Provisioning secondary DB cluster and one instance within it in other region
resource "aws_rds_cluster" "secondary" {
  provider                  = aws.secondary
  cluster_identifier        = "${var.env["second"]}-aurora-cluster"
  availability_zones        = ["us-east-1a", "us-east-1b", "us-east-1c"]
  engine                    = "aurora-mysql"
  engine_version            = "5.7.mysql_aurora.2.07.0"
  db_subnet_group_name      = aws_db_subnet_group.aurora_subnet_secondary.id
  skip_final_snapshot       = true
  vpc_security_group_ids    = [var.s_group["secondary"]]
  engine_mode               = "global"
  global_cluster_identifier = var.global_id

  lifecycle {
    ignore_changes = all
  }

  depends_on = [
    null_resource.join_cluster,
    null_resource.delay
  ]
}

resource "aws_rds_cluster_instance" "aurora-secondary" {
  provider            = aws.secondary
  identifier          = "aurora-${var.env["second"]}"
  cluster_identifier  = aws_rds_cluster.secondary.id
  engine              = "aurora-mysql"
  engine_version      = "5.7.mysql_aurora.2.07.0"
  instance_class      = var.dbtype
  publicly_accessible = false

  depends_on = [
    aws_rds_cluster.secondary
  ]

  lifecycle {
    ignore_changes = all
  }

  tags = {
    Name = "aurora-${var.env["second"]}"
  }
}

#################################################
# Null resources required to be applied before destroying resources: removing secondary cluster, then primary cluster and eventually removing the global cluster
# In order to execute the commands below it is recommended to invoke " terraform apply -var 'delete=true' " ; after that it is possible to delete the rest of the
# resources with simple "terraform destroy"
# Kindly note that "remove-from-global-cluster" function does not erase/delete neither cluster nor db instance, it only changes the engine mode from
# "global" to "provisioned" (regional)

resource "null_resource" "remove_from_cluster_secondary" {
  count = var.delete != "false" ? 1 : 0
  provisioner "local-exec" {
    command = "aws rds remove-from-global-cluster --global-cluster-identifier ${var.global_id} --db-cluster-identifier ${aws_rds_cluster.secondary.arn} && sleep 180"
  }
}

resource "null_resource" "remove_from_cluster_primary" {
  count = var.delete != "false" ? 1 : 0
  provisioner "local-exec" {
    command = "aws rds remove-from-global-cluster --global-cluster-identifier ${var.global_id} --db-cluster-identifier ${aws_rds_cluster.primary.arn} && sleep 90"
  }
  depends_on = [
    null_resource.remove_from_cluster_secondary
  ]
}

resource "null_resource" "delete_cluster" {
  count = var.delete != "false" ? 1 : 0
  provisioner "local-exec" {
    command = "aws rds delete-global-cluster --global-cluster-identifier ${var.global_id}"
  }

  depends_on = [
    null_resource.remove_from_cluster_secondary,
    null_resource.remove_from_cluster_primary
  ]
}
