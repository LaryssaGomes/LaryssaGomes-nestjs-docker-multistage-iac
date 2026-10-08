# Repositório privado de imagens Docker (ECR), para onde o CI faz o push.
resource "aws_ecr_repository" "rocketseat-ci-api" {
    # Nome real na AWS. Precisa ser igual ao ECR_REPOSITORY do ci.yml.
    name = "rocketseat-ci"
    # MUTABLE permite sobrescrever uma tag já existente (ex.: "latest").
    image_tag_mutability = "MUTABLE"
    # Permite o "terraform destroy" apagar o repositório mesmo com imagens dentro.
    force_delete = true
    image_scanning_configuration {
        scan_on_push = true//scan try find failures
    }
    # Tag para identificar que o recurso foi criado via Terraform (IaC).
    tags = {
        IAC = "True"
    }
}