locals {
  # Same convention the service already uses (application-docker.yml): the
  # database is <service>_db and its user is <service>.
  db_name     = "${var.service_name}_db"
  db_username = var.service_name
  name_prefix = "${var.project_name}-${var.service_name}"
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = data.aws_subnets.private.ids

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Allows PostgreSQL only from the EKS cluster/node security group provisioned in os-infrastructure"
  vpc_id      = data.aws_eks_cluster.main.vpc_config[0].vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes/pods"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-rds-sg"
  }
}

# RDS forbids '/', '@', '"' and whitespace in the master password. '$', '!',
# backticks and quotes are left out as well: the password travels through
# shells (gh secret set, kubectl) and a character the shell treats specially
# is how a password gets silently corrupted on the way.
resource "random_password" "db_master" {
  length           = 20
  special          = true
  override_special = "#%^*()-_=+"
}

resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = var.db_engine_version

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"

  db_name  = local.db_name
  username = local.db_username
  password = random_password.db_master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false # single-AZ: Multi-AZ would double cost with no real benefit for a school project
  publicly_accessible = false
  skip_final_snapshot = true
  monitoring_interval = 0 # Enhanced Monitoring is not supported on AWS Academy Learner Lab

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}
