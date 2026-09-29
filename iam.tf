resource "aws_iam_openid_connect_provider" "oidc-git" {
    url = "https://token.actions.githubusercontent.com"
    client_id_list = ["sts.amazonaws.com"]
    thumbprint_list = ["ab9d0263244dd0326eb67015705a667e79cfe998"]

    tags = {
        IAC = "True"
    }
}

resource "aws_iam_role" "ecr-role" {
    name = "ecr_role"
    assume_role_policy = jsonencode({
       Statement = [{
            Action = "sts:AssumeRoleWithWebIdentity",
            Condition = {
                StringEquals = {
                    "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
                    "token.actions.githubusercontent.com:sub" = "repo:LaryssaGomes/nestjs-docker-multistage:ref:refs/heads/main"
                }
            } 
            Effect = "Allow",
            Principal = {
                Federated = "arn:aws:iam::223910471502:oidc-provider/token.actions.githubusercontent.com"
            }
       }]
    Version = "2012-10-17"
    })
    
    inline_policy {
        name = "ecr-app-permissions"

        policy = jsonencode({
            Statement = [{
                Sid = "Statement1",
                Action = [
                    "ecr:GetDownloadUrlForLayer",
                    "ecr:BatchGetImage",
                    "ecr:BatchCheckLayerAvailability",
                    "ecr:PutImage",
                    "ecr:InitiateLayerUpload",
                    "ecr:UploadLayerPart",
                    "ecr:CompleteLayerUpload",
                    "ecr:GetAuthorizationToken"
                ]
                Effect = "Allow"
                Resource = "*"
            }]
        })
    }


    tags = {
        IAC = "True"
    }
}