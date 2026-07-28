# Stop the development instance after 30 minutes without meaningful CPU activity.
# Five-minute EC2 CPU metrics avoid the cost of detailed monitoring.
resource "aws_cloudwatch_metric_alarm" "t3_large_idle_stop" {
  alarm_name          = "${var.instance_name}-idle-stop"
  alarm_description   = "Stops the t3.large after 30 minutes with CPU utilization at or below ${var.idle_cpu_threshold_percent}%"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 6
  datapoints_to_alarm = 6
  threshold           = var.idle_cpu_threshold_percent
  comparison_operator = "LessThanOrEqualToThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.t3_large.id
  }

  alarm_actions = ["arn:aws:automate:${var.aws_region}:ec2:stop"]
}
