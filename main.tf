resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "/@"
}

# Creating a AWS secret for database master account (Masteraccoundb)

resource "aws_secretsmanager_secret" "secretmasterDB" {
   name = "Masteraccoundb"
}

# Creating a AWS secret versions for database master account (Masteraccoundb)

resource "aws_secretsmanager_secret_version" "sversion" {
  secret_id = aws_secretsmanager_secret.secretmasterDB.id
  secret_string = <<EOF
   {
    "username": "adminaccount",
    "password": "${random_password.password.result}"
   }
EOF
}

# Importing the AWS secrets created previously using arn.

data "aws_secretsmanager_secret" "secretmasterDB" {
  arn = aws_secretsmanager_secret.secretmasterDB.arn
}

# Importing the AWS secret version created previously using arn.

data "aws_secretsmanager_secret_version" "creds" {
  secret_id = aws_secretsmanager_secret.secretmasterDB.id
}

# After importing the secrets storing into Locals

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.creds.secret_string)
}
resource "aws_db_subnet_group" "dbsubnet" {
  name       = "dbsubntg"
  subnet_ids = ["subnet-0a5c652cee0a67725","subnet-0f4d9c0a9a0d5861c"]

  tags = {
    Name = "dbsubnetgroup"
  }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "democluster"
  database_name = "maindb"
  master_username = local.db_creds.username
  master_password = local.db_creds.password
  port = 5432
  engine = "aurora-postgresql"
  engine_version = "11.9"
  db_subnet_group_name = "dbsubntg"  # Make sure you create this before manually
  storage_encrypted = true
}


resource "aws_rds_cluster_instance" "main" {
  count = 2
  identifier = "myinstance-${count.index + 1}"
  cluster_identifier = "${aws_rds_cluster.main.id}"
  instance_class = "db.r4.large"
  engine = "aurora-postgresql"
  engine_version = "11.9"
  db_subnet_group_name = aws_db_subnet_group.dbsubnet.name
  publicly_accessible = true
}
