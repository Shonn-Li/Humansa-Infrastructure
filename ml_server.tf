# SSH Key Pair
resource "aws_key_pair" "humansa_key" {
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = var.ssh_public_key
}

# IAM Role for EC2 Instances
resource "aws_iam_role" "ml_server" {
  name = "${var.project_name}-${var.environment}-ml-server-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ml_server" {
  name = "${var.project_name}-${var.environment}-ml-server-profile"
  role = aws_iam_role.ml_server.name
}

# IAM Policies
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ml_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ml_server_policy" {
  name = "${var.project_name}-${var.environment}-ml-server-policy"
  role = aws_iam_role.ml_server.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      }
    ]
  })
}

# Launch Template
resource "aws_launch_template" "ml_server" {
  name_prefix   = "${var.project_name}-${var.environment}-ml-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.humansa_key.key_name
  
  vpc_security_group_ids = [aws_security_group.ml_server.id]
  
  iam_instance_profile {
    name = aws_iam_instance_profile.ml_server.name
  }
  
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      encrypted             = true
      delete_on_termination = true
    }
  }
  
  monitoring {
    enabled = true
  }
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    region       = var.aws_region
    project_name = var.project_name
    environment  = var.environment
    github_repo  = var.github_repo
  }))
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-${var.environment}-ml-server"
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ml_server" {
  name                = "${var.project_name}-${var.environment}-ml-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.humansa_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  
  min_size         = var.min_instances
  desired_capacity = var.desired_instances
  max_size         = var.max_instances
  
  launch_template {
    id      = aws_launch_template.ml_server.id
    version = "$Latest"
  }
  
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
  
  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-ml-server"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-${var.environment}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.ml_server.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 2
  cooldown              = 300
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-${var.environment}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.ml_server.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown              = 300
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "75"
  alarm_description   = "This metric monitors EC2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ml_server.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "25"
  alarm_description   = "This metric monitors EC2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ml_server.name
  }
}

# Data source for AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}