output "cluster_arn_primary" {
  value = aws_rds_cluster.primary.arn
}

output "cluster_arn_secondary" {
  value = aws_rds_cluster.secondary.arn
}
