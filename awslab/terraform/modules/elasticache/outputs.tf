output "cache_endpoint" {
  description = "Redis endpoint address — use in app connection config"
  value       = aws_elasticache_cluster.this.cache_nodes[0].address
}

output "cache_port" {
  description = "Redis port (6379)"
  value       = aws_elasticache_cluster.this.cache_nodes[0].port
}

output "cluster_id" {
  description = "ElastiCache cluster ID — used in CloudWatch dimensions and CLI references"
  value       = aws_elasticache_cluster.this.cluster_id
}
