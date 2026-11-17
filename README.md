# fiap-tech-challenge-inventory-database-infrastructure

Infraestrutura do banco de dados do **Inventory Service** (estoque de peças e insumos) do Tech Challenge — FIAP Pós-Tech, Arquitetura de Software, turma 15SOAT. Provisiona, via Terraform, uma instância **Amazon RDS for PostgreSQL** só deste serviço, e entrega ao repositório do serviço, sem intervenção manual, as credenciais de conexão.

| Repositório | Papel |
|---|---|
| [`fiap-tech-challenge-inventory-service`](https://github.com/Adriana-Meyer/fiap-tech-challenge-inventory-service) | Código do serviço (recebe os secrets de conexão) |
| [`fiap-tech-challenge-inventory-infrastructure`](https://github.com/Adriana-Meyer/fiap-tech-challenge-inventory-infrastructure) | Namespace e fila de comandos do serviço |
| **fiap-tech-challenge-inventory-database-infrastructure** (este) | RDS PostgreSQL do serviço |
| [`fiap-tech-challenge-os-infrastructure`](https://github.com/Adriana-Meyer/fiap-tech-challenge-os-infrastructure) | VPC, cluster EKS, New Relic e a mensageria compartilhada da saga |

## O que este repositório cria

| Recurso | Detalhe |
|---|---|
| `aws_db_instance` | `tech-challenge-inventory-postgres`: PostgreSQL 16, `db.t3.micro`, 20 GB gp2, single-AZ, sem IP público |
| Banco e usuário | `inventory_db` e `inventory` (a convenção que o serviço já usa em `application-docker.yml`) |
| `aws_security_group` | `tech-challenge-inventory-rds-sg`: porta 5432 **somente** a partir do security group do cluster EKS |
| `aws_db_subnet_group` | nas subnets privadas do cluster |
| `random_password` | senha mestre, gerada pelo Terraform e nunca digitada nem impressa |

## Tecnologias

| Camada | Tecnologia |
|---|---|
| Provisionamento | Terraform >= 1.5, providers `hashicorp/aws` e `hashicorp/random` |
| Nuvem | AWS (conta acadêmica AWS Academy Learner Lab) |
| Banco | Amazon RDS for PostgreSQL 16 |
| CI/CD | GitHub Actions |

## Decisões de desenho

- **Um banco por serviço:** o Inventory é o único a acessar este banco; nenhum outro serviço tem credencial nem rota até ele. É o que mantém os serviços independentes (a saga troca mensagens, não lê o banco do vizinho).
- **Rede descoberta por data source**, como no `os-database-infrastructure`: a VPC, as subnets privadas (tag `Tier=private`) e o security group do cluster são encontrados pelo nome fixo `tech-challenge-eks`, sem ler o state de outro repositório. O `os-infrastructure` precisa ter sido aplicado antes, na mesma sessão do Lab.
- **Nomes com o nome do serviço** (`tech-challenge-inventory-...`): cada serviço tem o seu repositório de banco e o seu state, e os nomes de instância, subnet group e security group precisam ser únicos na conta.
- **PostgreSQL 16 sem versão menor fixada:** a AWS escolhe a menor corrente, então não há uma versão menor para manter atualizada.
- **Single-AZ, `db.t3.micro`, gp2, Enhanced Monitoring desligado:** dentro dos limites do Learner Lab (classes nano a medium, só gp2, sem Enhanced Monitoring) e sem pagar Multi-AZ num projeto acadêmico.
- **A senha não tem caracteres que o shell trata de forma especial:** além dos proibidos pelo RDS (`/`, `@`, `"` e espaço), ficam de fora `$`, `!`, crase e aspas. A senha passa por shells (`gh secret set`, `kubectl`), e um `$` seguido de letra seria expandido em silêncio, entregando ao serviço uma senha diferente da do banco. Ainda sobra aleatoriedade de sobra: 20 caracteres de um conjunto de 72.
- **Credenciais entregues sem aparecer em log:** o workflow envia `RDS_DATASOURCE_URL`, `RDS_USERNAME` e `RDS_PASSWORD` como secrets do repositório do serviço, por `gh secret set` com o valor passado pela entrada padrão, nunca em variável registrada nem em argumento de comando.
- **`sslmode=require` na URL JDBC:** o RDS PostgreSQL 15 ou superior recusa conexões sem criptografia.
- **Custo:** com Billing, Inventory e OS são três instâncias RDS ligadas ao mesmo tempo, e o Learner Lab tem orçamento limitado. Prefira `destroy` entre as sessões. Mesmo parada (`stop`), uma instância RDS volta a ligar sozinha depois de 7 dias.

## Pré-requisitos

- Terraform >= 1.5
- Conta AWS Academy Learner Lab **ativa**, com credenciais temporárias
- `os-infrastructure` já aplicado na mesma sessão
- Secret `GH_PAT_CROSS_REPO_SECRETS` neste repositório: um token fine-grained com **Secrets: Read and write** no repositório `inventory-service`. O `GITHUB_TOKEN` do workflow só enxerga este repositório.

## Executando

O fluxo real é pelo workflow `terraform-apply.yml` (`workflow_dispatch`), porque o state é local ao runner: rodar `apply` na sua máquina deixaria o Terraform sem memória do que já existe na AWS, e um segundo `apply` tenderia a falhar por conflito de nome.

```bash
# apenas para inspecionar o plano localmente, com as credenciais do Lab exportadas
terraform init
terraform plan
```

Ordem de uso numa sessão do Lab:

- **Subir:** `os-infrastructure` → `inventory-infrastructure` → **este repositório** → deploy do `inventory-service`.
- **Desligar:** `destroy` do `inventory-service` → **este repositório** → `inventory-infrastructure` → `os-infrastructure`.

## CI/CD

- **`terraform-validate.yml`** — em todo push/PR para `develop`/`main`: `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`. Não precisa de credenciais AWS.
- **`terraform-apply.yml`** — disparo manual (`workflow_dispatch`) com escolha entre `plan`, `apply` e `destroy`. Usa as credenciais temporárias do Lab (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, renovadas a cada sessão). No `apply`, também envia as credenciais do banco ao `inventory-service`. Fica manual de propósito, para não gastar o orçamento do Lab a cada merge.

## Variáveis Terraform

Todas têm valor padrão (ver [`variables.tf`](variables.tf)):

| Variável | Padrão | Descrição |
|---|---|---|
| `service_name` | `inventory` | Nome do serviço: nomeia recursos, banco e usuário |
| `eks_cluster_name` | `tech-challenge-eks` | Cluster criado pelo `os-infrastructure` |
| `db_instance_class` | `db.t3.micro` | Classe da instância (limite do Lab: nano a medium) |
| `db_allocated_storage` | `20` | GB, gp2 |
| `db_engine_version` | `16` | Versão maior do PostgreSQL |

## Como foi validado

- `terraform fmt`, `init`, `validate` e `actionlint` passam (como no `terraform-validate.yml`).
- Um `terraform plan` offline, com as referências ao cluster trocadas por valores fixos, mostra os 4 recursos esperados com os nomes, a porta 5432 e o PostgreSQL 16.
- O gerador de senha foi exercitado várias vezes: tamanho 20, só caracteres permitidos e a senha sobrevive intacta a uma ida e volta por um shell com aspas duplas.

**Não validado:** o `apply` contra a AWS real (o RDS não existe em emuladores gratuitos) e o envio dos secrets ao repositório do serviço, que dependem das credenciais do Lab e do token. Isso é verificado na validação no Lab.

## APIs

Este repositório não expõe API própria — é infraestrutura de banco de dados. A API do serviço está no [inventory-service](https://github.com/Adriana-Meyer/fiap-tech-challenge-inventory-service).
