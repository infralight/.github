# VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  instance_tenancy     = var.instance_tenancy

  tags = merge(
    {
      Name = var.vpc_name
    },
    var.vpc_tags
  )
}

# DHCP Options
resource "aws_vpc_dhcp_options" "eks_dhcp_options" {
  domain_name         = var.dhcp_domain_name
  domain_name_servers = var.dhcp_domain_name_servers

  tags = var.dhcp_options_tags
}

# Internet Gateway
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = var.internet_gateway_name
  }
}

# Subnets
resource "aws_subnet" "eks_subnets" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  tags = merge(
    {
      Name = each.value.name
    },
    each.value.tags
  )
}

# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = var.public_route_table_name
  }
}

# Route Table Associations
resource "aws_route_table_association" "subnet_associations" {
  for_each = var.subnets

  subnet_id      = aws_subnet.eks_subnets[each.key].id
  route_table_id = aws_route_table.public_route_table.id
}

# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster_sg" {
  name        = var.eks_cluster_sg_name
  description = var.eks_cluster_sg_description
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description = "Allow nodes to communicate with cluster"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = ""
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.eks_cluster_sg_name
  }
}

# EKS Managed Security Group
resource "aws_security_group" "eks_managed_sg" {
  name        = var.eks_managed_sg_name
  description = var.eks_managed_sg_description
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description     = "Allows EFA traffic, which is not matched by CIDR rules."
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    self            = true
  }

  egress {
    description = ""
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allows EFA traffic, which is not matched by CIDR rules."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  tags = merge(
    {
      Name = var.eks_managed_sg_name
    },
    var.eks_managed_sg_tags
  )
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = var.eks_cluster_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.eks_cluster_role_tags
}

# Attach policies to EKS Cluster Role
resource "aws_iam_role_policy_attachment" "eks_cluster_policies" {
  for_each = toset(var.eks_cluster_policy_arns)

  policy_arn = each.value
  role       = aws_iam_role.eks_cluster_role.name
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_group_role" {
  name = var.eks_node_group_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.eks_node_group_role_tags
}

# Attach policies to EKS Node Group Role
resource "aws_iam_role_policy_attachment" "eks_node_group_policies" {
  for_each = toset(var.eks_node_group_policy_arns)

  policy_arn = each.value
  role       = aws_iam_role.eks_node_group_role.name
}

# IAM Instance Profile for Node Group
resource "aws_iam_instance_profile" "eks_node_instance_profile" {
  name = var.eks_node_instance_profile_name
  role = aws_iam_role.eks_node_group_role.name

  tags = var.eks_node_instance_profile_tags
}

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.eks_cluster_version

  vpc_config {
    subnet_ids              = [for subnet in aws_subnet.eks_subnets : subnet.id]
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
    endpoint_private_access = var.eks_endpoint_private_access
    endpoint_public_access  = var.eks_endpoint_public_access
    public_access_cidrs     = var.eks_public_access_cidrs
  }

  tags = var.eks_cluster_tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policies
  ]
}

# EKS Node Group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = var.eks_node_group_name
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = [for subnet in aws_subnet.eks_subnets : subnet.id]

  ami_type       = var.eks_node_group_ami_type
  capacity_type  = var.eks_node_group_capacity_type
  disk_size      = var.eks_node_group_disk_size
  instance_types = var.eks_node_group_instance_types

  scaling_config {
    desired_size = var.eks_node_group_desired_size
    max_size     = var.eks_node_group_max_size
    min_size     = var.eks_node_group_min_size
  }

  update_config {
    max_unavailable = var.eks_node_group_max_unavailable
  }

  labels = var.eks_node_group_labels
  tags   = var.eks_node_group_tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_policies
  ]
}