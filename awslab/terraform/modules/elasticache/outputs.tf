output "primary_endpoint" {
  description = "Redis primary endpoint address (null when enabled = false)"
  value = !var.enabled ? null : (
    var.use_replication_group ? (
      length(aws_elasticache_replication_group.this) > 0 ? aws_elasticache_replication_group.this[0].primary_endpoint_address : null
    ) : (
      length(aws_elasticache_cluster.this) > 0 ? aws_elasticache_cluster.this[0].cache_nodes[0].address : null
    )
  )
}

output "reader_endpoint" {
  description = "Redis reader endpoint (null when enabled = false or cluster mode)"
  value = !var.enabled ? null : (
    var.use_replication_group ? (
      length(aws_elasticache_replication_group.this) > 0 ? aws_elasticache_replication_group.this[0].reader_endpoint_address : null
    ) : (
      length(aws_elasticache_cluster.this) > 0 ? aws_elasticache_cluster.this[0].cache_nodes[0].address : null
    )
  )
}

output "cache_port" {
  description = "Redis port (6379)"
  value       = 6379
}

output "replication_group_id" {
  description = "ElastiCache cluster/group ID (null when enabled = false)"
  value = !var.enabled ? null : (
    var.use_replication_group ? (
      length(aws_elasticache_replication_group.this) > 0 ? aws_elasticache_replication_group.this[0].replication_group_id : null
    ) : (
      length(aws_elasticache_cluster.this) > 0 ? aws_elasticache_cluster.this[0].cluster_id : null
    )
  )
}
