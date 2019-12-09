**Repository contains terraform module creating global cluster consisting of two clusters with Aurora 5.7 version in two different AWS regions:** 

* terraform 0.12.7
* plugin "null" (hashicorp/null) 2.1.2
* plugin "aws" (hashicorp/aws) 2.41.0

*************************
**Module logic is as follows:**
*************************
1.  Initializating two aws providers in us-east-1 and us-east-2 regions
2.  Creating two DB subnet groups in two regions
3.  Creating primary cluster with 5.7.mysql_aurora.2.07.0 engine version and 1 db instance within this cluster in one region
4.  Transforming cluster into global cluster
5.  Adding secondary region by creating additional cluster with read-replica instance
6.  Defining null resources required to remove clusters from global cluster and then deleting the global cluster itself

Steps to remove all resources:
*  Execute `terraform apply -var 'delete=true'`
*  Execute `terraform destroy`


**Important nuances:**
* secondary cluster must not contain **database_name, master_username and master_password** parameters 
* secondary cluster is recommended to be added with **lifecycle** *ignoring all* further changes
* **global_cluster_identifier** needs to be indicated through its name and **not** via *data.aws_rds_cluster resource*
* instance_class needs to be of supported type: **db.r4.large** or higher
* correct **depends_on** values are required for almost all resources
