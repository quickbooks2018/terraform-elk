#######################
# ElasticSearch Cluster
#######################

###############
# Master Node 1
###############
module "launch-configuration-es-master-1" {

  source                    = "./modules/aws-launch-configuration"
  launch-configuration-name = "launch-configuration-es-master-node-1"
  ebs_optimized             = true
  iam_instance_profile_name = module.iam-instance-profile.ec2-instance-profile-name
  # Ubuntu
  image_id              = "ami-09a169db1a23aad3c"
  instance_type         = "t3a.medium"
  volume_size           = "30"
  volume_type           = "gp2"
  delete_on_termination = "true"
  encrypted             = "true"
  key_name              = module.ec2-keypair.key-name
  security_groups       = [module.ec2-sg-appsecgroup.security_group_id]
  enable_monitoring     = "true"
  user_data             = file("./modules/aws-launch-configuration/user-data/es-master-1.sh")

}


module "auto-scaling-es-master-1" {
  source                    = "./modules/aws-auto-scaling"
  autoscaling-group-name    = "auto-scaling-es-master-1"
  launch_configuration      = module.launch-configuration-es-master-1.launch_configuration_name
  max-size                  = "1"
  min-size                  = "1"
  health-check-grace-period = "300"
  desired-capacity          = "1"
  force-delete              = "true"
  #A list of subnet IDs to launch resources in
  vpc-zone-identifier = [module.vpc.private_subnets][0]
  target-group-arns   = [aws_lb_target_group.elastic-search-nodes.arn]
  health-check-type   = "EC2"
  key                 = "Name"
  value               = "es-master-node-1"

}


###############
# Master Node 2
###############
module "launch-configuration-es-master-node-2" {

  source                    = "./modules/aws-launch-configuration"
  launch-configuration-name = "launch-configuration-es-master-node-2"
  ebs_optimized             = true
  iam_instance_profile_name = module.iam-instance-profile.ec2-instance-profile-name
  # Ubuntu
  image_id              = "ami-09a169db1a23aad3c"
  instance_type         = "t3a.medium"
  volume_size           = "30"
  volume_type           = "gp2"
  delete_on_termination = "true"
  encrypted             = "false"
  key_name              = module.ec2-keypair.key-name
  security_groups       = [module.ec2-sg-appsecgroup.security_group_id]
  enable_monitoring     = "true"
  user_data             = file("./modules/aws-launch-configuration/user-data/es-master-2.sh")
}




module "auto-scaling-es-master-node-2" {
  source                    = "./modules/aws-auto-scaling"
  autoscaling-group-name    = "auto-scaling-es-master-node-2"
  launch_configuration      = module.launch-configuration-es-master-node-2.launch_configuration_name
  max-size                  = "1"
  min-size                  = "1"
  health-check-grace-period = "300"
  desired-capacity          = "1"
  force-delete              = "true"
  #A list of subnet IDs to launch resources in
  vpc-zone-identifier = [module.vpc.private_subnets][0]
  target-group-arns   = [aws_lb_target_group.elastic-search-nodes.arn]
  health-check-type   = "EC2"
  key                 = "Name"
  value               = "es-master-node-2"

}

###############
# Master Node 3
###############
module "launch-configuration-es-master-node-3" {

  source                    = "./modules/aws-launch-configuration"
  launch-configuration-name = "launch-configuration-es-master-node-3"
  ebs_optimized             = true
  iam_instance_profile_name = module.iam-instance-profile.ec2-instance-profile-name
  # Ubuntu
  image_id              = "ami-09a169db1a23aad3c"
  instance_type         = "t3a.medium"
  volume_size           = "30"
  volume_type           = "gp2"
  delete_on_termination = "true"
  encrypted             = "false"
  key_name              = module.ec2-keypair.key-name
  security_groups       = [module.ec2-sg-appsecgroup.security_group_id]
  enable_monitoring     = "true"
  user_data             = file("./modules/aws-launch-configuration/user-data/es-master-3.sh")
}




module "auto-scaling-es-master-node-3" {
  source                    = "./modules/aws-auto-scaling"
  autoscaling-group-name    = "auto-scaling-es-master-node-3"
  launch_configuration      = module.launch-configuration-es-master-node-3.launch_configuration_name
  max-size                  = "1"
  min-size                  = "1"
  health-check-grace-period = "300"
  desired-capacity          = "1"
  force-delete              = "true"
  #A list of subnet IDs to launch resources in
  vpc-zone-identifier = [module.vpc.private_subnets][0]
  target-group-arns   = [aws_lb_target_group.elastic-search-nodes.arn]
  health-check-type   = "EC2"
  key                 = "Name"
  value               = "es-master-node-3"
}


############
# DATA Nodes
############
module "launch-configuration-es-data-nodes" {

  source                    = "./modules/aws-launch-configuration"
  launch-configuration-name = "launch-configuration-es-data-nodes"
  ebs_optimized             = true
  iam_instance_profile_name = module.iam-instance-profile.ec2-instance-profile-name
  # Ubuntu
  image_id              = "ami-09a169db1a23aad3c"
  instance_type         = "t3a.medium"
  volume_size           = "30"
  volume_type           = "gp2"
  delete_on_termination = "true"
  encrypted             = "false"
  key_name              = module.ec2-keypair.key-name
  security_groups       = [module.ec2-sg-appsecgroup.security_group_id]
  enable_monitoring     = "true"
  user_data             = file("./modules/aws-launch-configuration/user-data/es-data-node.sh")
}




module "auto-scaling-es-data-nodes" {
  source                    = "./modules/aws-auto-scaling"
  autoscaling-group-name    = "auto-scaling-es-data-nodes"
  launch_configuration      = module.launch-configuration-es-data-nodes.launch_configuration_name
  max-size                  = "0"
  min-size                  = "0"
  health-check-grace-period = "300"
  desired-capacity          = "0"
  force-delete              = "true"
  #A list of subnet IDs to launch resources in
  vpc-zone-identifier = [module.vpc.private_subnets][0]
  target-group-arns   = [aws_lb_target_group.elastic-search-nodes.arn]
  health-check-type   = "EC2"
  key                 = "Name"
  value               = "es-data-node"
}




###########
# SNS Topic
###########
module "sns-topic-auto-scaling" {
  source                         = "./modules/aws-sns"
  auto-scaling-sns-name          = "ES-AutoScaling-SNS-Topic"
  sns-subscription-email-address = "info@cloudgeeks.ca"
}

module "auto-scaling-sns" {
  source                       = "./modules/aws-auto-scaling-sns"
  aws_autoscaling_notification = [module.auto-scaling-es-master-1.autoscaling-group-name, module.auto-scaling-es-master-node-2.autoscaling-group-name, module.auto-scaling-es-master-node-3.autoscaling-group-name, module.auto-scaling-es-data-nodes.autoscaling-group-name][0]
  sns-topic-arn                = module.sns-topic-auto-scaling.auto-scaling-sns-arn
}
