# Visão geral das roles deste arquivo:
#   ecr_role           -> assumida pelo GitHub Actions (via OIDC) para push no ECR e deploy
#   ecs_express_role   -> assumida pelo ECS para criar ALB, security groups e auto scaling
#   ecs_execution_role -> assumida pelas tasks para puxar a imagem do ECR e mandar logs
#
# Toda role tem duas partes:
#   assume_role_policy (trust policy) -> QUEM pode assumir a role
#   policies anexadas                 -> O QUE a role pode fazer

# Registra o GitHub como provedor de identidade na conta AWS.
# Com isso, o GitHub Actions faz login com um token temporário, sem access keys fixas.
resource "aws_iam_openid_connect_provider" "oidc-git" {
  url = "https://token.actions.githubusercontent.com"
  # "aud" que o token precisa ter; é o audience usado pelo configure-aws-credentials.
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ab9d0263244dd0326eb67015705a667e79cfe998"]

  tags = {
    IAC = "True"
  }
}
resource "aws_iam_role" "tf-role" {
  name = "tf_role"
  assume_role_policy = jsonencode({
    Statement = [{
      # Login com token OIDC (web identity), não com access keys.
      Action = "sts:AssumeRoleWithWebIdentity",
      # Só aceita o token se as claims baterem EXATAMENTE (StringEquals).
      Condition = {
        StringEquals = {
          # Token emitido para a AWS.
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          # Só este repositório, na branch main.
          # O GitHub envia o formato com IDs (usuario@id/repo@id); se o repo
          # for apagado e recriado com o mesmo nome, o ID muda e o acesso é negado.
          # Pull requests enviam ":pull_request" no lugar de ":ref:refs/heads/main".
          "token.actions.githubusercontent.com:sub" = "repo:LaryssaGomes@61350150/LaryssaGomes-nestjs-docker-multistage-iac@1400581933:ref:refs/heads/main"
        }
      }
      Effect = "Allow",
      Principal = {
        # O provedor OIDC do GitHub criado no início deste arquivo.
        Federated = "arn:aws:iam::223910471502:oidc-provider/token.actions.githubusercontent.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = {
    IAC = "True"
  }
}

# O que o Terraform (rodando no CI com a tf_role) pode fazer.
# Só os recursos que este repositório gerencia + o bucket do state.
# Os ARNs são escritos à mão (e não aws_iam_role.x.arn) porque a tf_role
# também está na lista, e referenciar a si mesma criaria um ciclo.
resource "aws_iam_role_policy" "tf-permissions" {
  # Mesmo nome da antiga inline_policy, para sobrescrevê-la na AWS.
  name = "tf-permissions"
  role = aws_iam_role.tf-role.id

  policy = jsonencode({
    Statement = [{
      # Ler e gravar o terraform.tfstate (e o .tflock) no bucket do backend.
      Sid      = "StateBucketList",
      Action   = "s3:ListBucket",
      Effect   = "Allow",
      Resource = "arn:aws:s3:::laryssa-nestjs-iac-tfstate-223910471502"
      }, {
      Sid      = "StateObjects",
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      Effect   = "Allow",
      Resource = "arn:aws:s3:::laryssa-nestjs-iac-tfstate-223910471502/*"
      }, {
      # Gerenciar o repositório do ECR (ecr.tf).
      Sid      = "ManageEcr",
      Action   = "ecr:*",
      Effect   = "Allow",
      Resource = "arn:aws:ecr:us-east-1:223910471502:repository/rocketseat-ci"
      }, {
      # Gerenciar as roles, o provedor OIDC e a service-linked role deste arquivo.
      Sid    = "ManageIam",
      Action = "iam:*",
      Effect = "Allow",
      Resource = [
        "arn:aws:iam::223910471502:oidc-provider/token.actions.githubusercontent.com",
        "arn:aws:iam::223910471502:role/tf_role",
        "arn:aws:iam::223910471502:role/ecr_role",
        "arn:aws:iam::223910471502:role/ecs_express_role",
        "arn:aws:iam::223910471502:role/ecs_execution_role",
        "arn:aws:iam::223910471502:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"
      ]
      }, {
      # As policies gerenciadas pela AWS anexadas nas roles do ECS (só leitura).
      Sid    = "ReadAwsManagedPolicies",
      Action = ["iam:GetPolicy", "iam:GetPolicyVersion"],
      Effect = "Allow",
      Resource = [
        "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices",
        "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
      ]
    }]
    Version = "2012-10-17"
  })
}
# Infrastructure role do ECS Express Mode (vai no infrastructure-role-arn do ci.yml).
resource "aws_iam_role" "ecs-express-role" {
  name = "ecs_express_role"
  assume_role_policy = jsonencode({
    Statement = [{
      # Serviço da AWS assumindo role: usa sts:AssumeRole (sem OIDC, sem Condition).
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        # O próprio serviço ECS.
        Service = "ecs.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = {
    IAC = "True"
  }

}

# Permissões gerenciadas pela AWS para o ECS criar ALB, security groups,
# certificado ACM e auto scaling do serviço Express.
resource "aws_iam_role_policy_attachment" "ecs-express-infrastructure" {
  role       = aws_iam_role.ecs-express-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRoleforExpressGatewayServices"
}

# Execution role (vai no execution-role-arn do ci.yml).
resource "aws_iam_role" "ecs-execution-role" {
  name = "ecs_execution_role"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        # Atenção ao "-tasks": quem assume são as tasks (containers), não o serviço ECS.
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = {
    IAC = "True"
  }
}

# Permite puxar a imagem do ECR e enviar logs para o CloudWatch.
resource "aws_iam_role_policy_attachment" "ecs-execution" {
  role       = aws_iam_role.ecs-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Role assumida pelo GitHub Actions (role-to-assume do ci.yml).
resource "aws_iam_role" "ecr-role" {
  name = "ecr_role"
  assume_role_policy = jsonencode({
    Statement = [{
      # Login com token OIDC (web identity), não com access keys.
      Action = "sts:AssumeRoleWithWebIdentity",
      # Só aceita o token se as claims baterem EXATAMENTE (StringEquals).
      Condition = {
        StringEquals = {
          # Token emitido para a AWS.
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          # Só este repositório, na branch main.
          # O GitHub envia o formato com IDs (usuario@id/repo@id); se o repo
          # for apagado e recriado com o mesmo nome, o ID muda e o acesso é negado.
          # Pull requests enviam ":pull_request" no lugar de ":ref:refs/heads/main".
          "token.actions.githubusercontent.com:sub" = "repo:LaryssaGomes@61350150/nestjs-docker-multistage@1356158954:ref:refs/heads/main"
        }
      }
      Effect = "Allow",
      Principal = {
        # O provedor OIDC do GitHub criado no início deste arquivo.
        Federated = "arn:aws:iam::223910471502:oidc-provider/token.actions.githubusercontent.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = {
    IAC = "True"
  }
}

# O que o GitHub Actions pode fazer depois de assumir a ecr_role.
# Cada Sid precisa ser único dentro da policy.
resource "aws_iam_role_policy" "ecr-app-permissions" {
  name = "ecr-app-permissions"
  role = aws_iam_role.ecr-role.id

  policy = jsonencode({
    Statement = [{
      # Substitui o antigo "apprunner:*" do curso.
      # Permissões pedidas pela action amazon-ecs-deploy-express-service.
      Sid = "EcsExpressDeploy",
      Action = [
        "ecs:CreateCluster",
        "ecs:RegisterTaskDefinition",
        "ecs:CreateExpressGatewayService", # primeiro deploy
        "ecs:UpdateExpressGatewayService", # deploys seguintes (troca a imagem)
        "ecs:DescribeExpressGatewayService",
        "ecs:DescribeClusters",
        "ecs:DescribeServices",
        "ecs:ListServiceDeployments", # acompanhar o deploy
        "ecs:DescribeServiceDeployments",
        "ecs:TagResource",
        "ecs:UntagResource"
      ],
      Effect   = "Allow",
      Resource = "*"
      }, {
      # "Passar" uma role = entregar ao ECS uma role para ele usar.
      # Restrito só às duas roles do ECS, para o GitHub não repassar qualquer role da conta.
      Sid    = "PassEcsRoles", # TROCA ROLE EM TEMPO DE EXECUÇÃO
      Action = "iam:PassRole",
      Effect = "Allow",
      Resource = [
        aws_iam_role.ecs-express-role.arn,
        aws_iam_role.ecs-execution-role.arn
      ]
      }, {
      # Push da imagem Docker para o ECR.
      Sid = "EcrPush",
      Action = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken" # usado pelo "docker login" (amazon-ecr-login)
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
    Version = "2012-10-17"
  })
}

# Service-linked role do ECS (AWSServiceRoleForECS).
# O ECS usa essa role para gerenciar recursos da conta (rede, load balancer).
# Contas que nunca usaram ECS não têm essa role, e o CreateExpressGatewayService
# falha com "Unable to assume the service linked role". Só existe uma por conta.
resource "aws_iam_service_linked_role" "ecs" {
  aws_service_name = "ecs.amazonaws.com"
}
