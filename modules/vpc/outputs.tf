output "vpc_id" { value = aws_vpc.spoke_vpc.id }
output "subnet_id" { value = aws_subnet.spoke_subnet.id }
output "route_table_id" {
  description = "The ID of the route table"
  # FIX: Use 'one' and the splat operator [*] to handle the list
  value       = one(aws_route_table.spoke_rt[*].id)
}