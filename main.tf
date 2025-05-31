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

  # Ingress rule for SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Source CIDR (all IPs)
  }

  # Ingress rule allowing Flask API (port 5000)
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
  key_name = "koderush-dev"  # Key pair for SSH access

  instance_market_options {
    market_type = "spot"  # Using spot instances for cost efficiency

    spot_options {
      spot_instance_type = "one-time"  # One-time request for spot instances
      instance_interruption_behavior = "terminate"  # Terminate on interruption
    }
  }

  # Network interface configuration
  network_interfaces {
    associate_public_ip_address = true  # Assigns public IP for access
    security_groups = [aws_security_group.web.id]  # Web security group
  }
}

# Load Balancer ------------------------------------------------------

# Creating an Application Load Balancer
resource "aws_lb" "web" {
  name               = "web-lb"
  internal           = false  # Makes it accessible from the internet
  load_balancer_type = "application"  # Load Balancer type
  subnets            = aws_subnet.public[*].id  # Place it in all public subnets
  security_groups    = [aws_security_group.web.id]  # Web security group
}

# Creating a target group for the load balancer
resource "aws_lb_target_group" "web" {
  name     = "web-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    path = "/generate"
    matcher = "200"
  }
}

# Creating a listener for the load balancer on port 80
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 5000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Auto Scaling Group -------------------------------------------------

# Creating an Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  desired_capacity     = 2  # Desired # of instances
  max_size             = 2  # Maximum # of instances
  min_size             = 2  # Minimum # of instances
  vpc_zone_identifier  = aws_subnet.public[*].id  # Spread across public subnets
  target_group_arns    = [aws_lb_target_group.web.arn]  # Registers with target group
  
  # Launch template configuration
  launch_template {
    id      = aws_launch_template.web.id  # Web launch template to test load
    version = "$Latest"  # Always the latest version
  }

  # Tags
  tag {
    key                 = "Name"
    value               = "web-load-instance"
    propagate_at_launch = true  # Applies to all launched instances
  }

  health_check_type = "ELB"  # Elastic Load Balancing health checks
}

# Auto Scaling Policy ------------------------------------------------

# Scaling policy to add instances
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "cpu-scale-up"
  adjustment_type        = "ChangeInCapacity"  # Changes the capacity directly
  scaling_adjustment     = 1  # Adds 1 instance when triggered
  cooldown               = 120  # Cooldown period in seconds
  autoscaling_group_name = aws_autoscaling_group.web.name  # Associates with the auto scaling group
}

# Creating a CloudWatch alarm to trigger scaling up
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-high" 
  comparison_operator = "GreaterThanThreshold"  # Triggers when above threshold
  evaluation_periods  = 2  # Number of periods to evaluate
  metric_name         = "CPUUtilization"  # Monitors CPU utilization
  namespace           = "AWS/EC2"  # AWS namespace for EC2 metrics
  period              = 120  # Evaluation period in seconds
  statistic           = "Average"  # Uses average CPU utilization
  threshold           = 60  # Triggers at 60% CPU usage

  # Dimensions to filter the metric
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name  # Applies to the auto scaling group
  }

  # Execute scale-up policy when alarm triggers
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}
