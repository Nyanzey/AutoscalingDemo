output "load_balancer_dns" {
  value = aws_lb.web.dns_name
}