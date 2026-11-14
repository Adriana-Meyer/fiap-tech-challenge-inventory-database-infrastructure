variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  description = "Fixed prefix of every resource name, shared with the other repositories."
  type        = string
  default     = "tech-challenge"
}

variable "service_name" {
  description = "Name of the service that owns this database. It names the resources, the database and its user, and the repository that receives the connection secrets. The service's own configuration expects these names, so change it only together with it."
  type        = string
  default     = "inventory"
}

variable "eks_cluster_name" {
  description = "Fixed name of the EKS cluster provisioned by os-infrastructure — used to discover its VPC, private subnets and cluster security group without manual copy-paste between repos."
  type        = string
  default     = "tech-challenge-eks"
}

variable "db_instance_class" {
  description = "Must be nano/micro/small/medium — the only DB instance classes allowed on AWS Academy Learner Lab."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "GB. Only gp2 storage is supported by the Lab, capped at 100GB."
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL major version. Left without a minor on purpose: AWS picks its current default minor, so there is no pinned minor to keep up to date."
  type        = string
  default     = "16"
}
