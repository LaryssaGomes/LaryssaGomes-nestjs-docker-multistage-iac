resource "aws_ecr_repository" "rocketseat-ci-api" {
    name = "rocketseat-ci"
    image_tag_mutability = "MUTABLE"
    image_scanning_configuration {
        scan_on_push = true//scan try find failures
    }
    tags = {
        IAC = "True"
    }
}