# Configuração geral do Terraform: qual provider usar e em qual versão.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # "~> 6.23" aceita 6.23, 6.24... mas nunca 7.x (evita breaking changes).
      # A 6.23 foi a primeira com suporte ao ECS Express Mode.
      version = "~> 6.23"
    }
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