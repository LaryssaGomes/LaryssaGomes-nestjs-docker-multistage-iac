# Configuração geral do Terraform: qual provider usar e em qual versão.
# toda vez que faz definicao de mooodulo e alterarna o state, precisa rodar terraform init novamente.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # "~> 6.23" aceita 6.23, 6.24... mas nunca 7.x (evita breaking changes).
      # A 6.23 foi a primeira com suporte ao ECS Express Mode.
      version = "~> 6.23"
    }
  }

  # State remoto no S3, compartilhado entre a sua máquina e o CI.
  # Sem isso, cada execução do CI começa com o state vazio e tenta recriar tudo.
  # O bucket foi criado à mão (fora do Terraform), porque precisa existir antes do init.
  backend "s3" {
    bucket = "laryssa-nestjs-iac-tfstate-223910471502"
    key    = "nestjs-docker-multistage-iac/terraform.tfstate"
    region = "us-east-1"
    # Trava o state com um arquivo .tflock no próprio bucket (Terraform >= 1.10).
    use_lockfile = true
  }
}

provider "aws" {
  # Região onde todos os recursos são criados.
  # Precisa bater com o aws-region do ci.yml.
  region = "us-east-1"

  # Trava de segurança: o Terraform aborta se as credenciais forem de outra conta
  # (ex.: o perfil "trino", da conta 841162676072).
  allowed_account_ids = ["223910471502"]
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "laryssa-nestjs-iac-tfstate-223910471502"
  force_destroy = true
  lifecycle {
    prevent_destroy = true
  }
  acl    = "private"
  tags = {
    IAC = "True"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}