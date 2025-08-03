output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.humansa_alb.arn
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.humansa_alb.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.humansa_alb.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.humansa_tg.arn
}

output "load_balancer_arn_suffix" {
  description = "ARN suffix of the load balancer for CloudWatch metrics"
  value       = aws_lb.humansa_alb.arn_suffix
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group for CloudWatch metrics"
  value       = aws_lb_target_group.humansa_tg.arn_suffix
}

output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.humansa_cert.arn
}