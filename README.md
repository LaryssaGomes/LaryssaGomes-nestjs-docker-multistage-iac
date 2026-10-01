# nestjs-docker-multistage-iac

Infraestrutura (Terraform) da API [nestjs-docker-multistage](https://github.com/LaryssaGomes/nestjs-docker-multistage).

Recursos criados na AWS (`us-east-1`):

- `ecr.tf` – repositório ECR `rocketseat-ci`, para onde o CI da API faz o push da imagem.
- `iam.tf` – provedor OIDC do GitHub e as roles `ecr_role` (GitHub Actions), `ecs_express_role` e `ecs_execution_role` (ECS Express Mode).

> A trust policy da `ecr_role` aceita apenas o repositório da **API** (branch `main`), não este.

## Uso

```sh
terraform init
terraform plan
terraform apply
```

O state fica local (`terraform.tfstate`, fora do git).
