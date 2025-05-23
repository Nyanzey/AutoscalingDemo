# Getting available availability zones in the region
data "aws_availability_zones" "available" {}

# VPC and Subnets ----------------------------------------------------------------

# Creating a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"  # Address range for the VPC
}

# Creating 2 public subnets for the instances to be launched
resource "aws_subnet" "public" {
  count             = 2  # Number of subnets to create
  vpc_id            = aws_vpc.main.id  # Main VPC ID to attach to
  cidr_block        = "10.0.${count.index}.0/24"  # Creates 10.0.0.0/24 and 10.0.1.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]  # Distributing the subnets across availability zones
}

# Creating an Internet Gateway to allow internet access to the VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Creating a route table for the VPC
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
}

# Adding a default route (0.0.0.0/0) to the Internet Gateway
resource "aws_route" "r" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"  # Default route for all traffic
  gateway_id             = aws_internet_gateway.gw.id  # Routes traffic to the Internet Gateway
}

# Making the subnets public by associating them with the route table
resource "aws_route_table_association" "a" {
  count          = 2  # Number of associations (one for each subnet)
  subnet_id      = aws_subnet.public[count.index].id  # Associates each subnet
  route_table_id = aws_route_table.rt.id  # With the route table containing the route to the Internet Gateway
}

# Security Groups -----------------------------------------------------

# Creating a security group for the web servers
resource "aws_security_group" "web" {
  name        = "web-sg"  # Name
  description = "Allow HTTP"  # Description
  vpc_id      = aws_vpc.main.id  # Target VPC

  # Ingress rule allowing HTTP (port 80) traffic from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Source CIDR (all IPs)
  }

  # Egress rule allowing all outbound traffic
  egress {
    from_port   = 0  # All ports
    to_port     = 0  # All ports
    protocol    = "-1"  # All protocols
    cidr_blocks = ["0.0.0.0/0"]  # Destination (all IPs)
  }
}

# Launch Template ----------------------------------------------------

# Creating a launch template for EC2 instances
resource "aws_launch_template" "web" {
  name_prefix   = "web-lt" 
  image_id      = "ami-0c02fb55956c7d316"  # Amazon Linux 2
  instance_type = "t2.micro" 
  user_data     = base64encode(file("startup.sh"))  # User data script to simulate load

  # Network interface configuration
  network_interfaces {
    associate_public_ip_address = true  # Assigns public IP for access
    security_groups = [aws_security_group.web.id]  # Web security group
  }
}

# Load Balancer Resources ------------------------------------------------------

# Creating an Application Load Balancer
resource "aws_lb" "web" {
  name               = "web-lb"  # Name of the load balancer
  internal           = false  # Makes it internet-facing
  load_balancer_type = "application"  # ALB type
  subnets            = aws_subnet.public[*].id  # Places in all public subnets
  security_groups    = [aws_security_group.web.id]  # Attaches web security group
}

# Creating a target group for the load balancer
resource "aws_lb_target_group" "web" {
  name     = "web-tg"
  port     = 80 # Same as the security group ingress rule
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id  
  
  # Health check configuration
  health_check {
    path = "/"  # Health check endpoint
  }
}

# Creates a listener for the load balancer on port 80
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn  # Associates with the ALB
  port              = 80  # Listens on port 80
  protocol          = "HTTP"  # Uses HTTP protocol

  # Default action forwards traffic to the target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Auto Scaling Group Resources -------------------------------------------------

# Creates an Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  desired_capacity     = 1  # Desired number of instances
  max_size             = 5  # Maximum number of instances
  min_size             = 1  # Minimum number of instances
  vpc_zone_identifier  = aws_subnet.public[*].id  # Spread across public subnets
  target_group_arns    = [aws_lb_target_group.web.arn]  # Registers with target group
  
  # Launch template configuration
  launch_template {
    id      = aws_launch_template.web.id  # Uses the web launch template
    version = "$Latest"  # Always uses the latest version
  }

  # Tag configuration for instances
  tag {
    key                 = "Name"
    value               = "web-instance"
    propagate_at_launch = true  # Applies to all launched instances
  }

  health_check_type = "ELB"  # Uses ELB health checks
}

# Auto Scaling Policy Resources ------------------------------------------------

# Creates a scaling policy to add instances when scaling up
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "cpu-scale-up"  # Policy name
  adjustment_type        = "ChangeInCapacity"  # Changes the capacity directly
  scaling_adjustment     = 1  # Adds 1 instance when triggered
  cooldown               = 120  # Cooldown period in seconds
  autoscaling_group_name = aws_autoscaling_group.web.name  # Associates with ASG
}

# Creates a CloudWatch alarm to trigger scaling
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-high"  # Alarm name
  comparison_operator = "GreaterThanThreshold"  # Triggers when above threshold
  evaluation_periods  = 2  # Number of periods to evaluate
  metric_name         = "CPUUtilization"  # Monitors CPU utilization
  namespace           = "AWS/EC2"  # AWS namespace for EC2 metrics
  period              = 120  # Evaluation period in seconds
  statistic           = "Average"  # Uses average CPU utilization
  threshold           = 60  # Triggers at 60% CPU

  # Dimensions to filter the metric
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name  # Applies to our ASG
  }

  # Action to take when alarm triggers (execute scale-up policy)
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}