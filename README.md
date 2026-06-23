# Digest

*Documento parcialmente gerado por IA, revisado e mantido por ma-alves.*

**Digest** é uma aplicação serverless de newsletter automatizada construída com TypeScript e AWS. Ela busca artigos da NewsAPI, renderiza newsletters em HTML usando Handlebars e as envia para assinantes via SES, tudo orquestrado pelo serviço de Step Functions acionada diariamente pelo EventBridge Scheduler. A infraestrutura é 100% definida com Terraform.

## Arquitetura Serverless

O sistema é dividido em dois planos: o **workflow de newsletter** (pipeline batch disparado por tempo) e a **API de gerenciamento de assinantes** (sob demanda via API Gateway).

### Workflow de Newsletter

Um EventBridge Scheduler dispara o Step Functions todos os dias às 08:00 UTC. A máquina de estados executa 5 Lambdas em sequência:

1. **fetch-articles** — Busca o secret da NewsAPI no Secrets Manager e faz uma requisição à NewsAPI para obter artigos do último dia. Retorna um array de artigos padronizados.
2. **generate-newsletter** — Lê o template Handlebars do S3, compila o HTML com os artigos e faz upload do resultado para outro bucket S3. Salva o registro da newsletter no DynamoDB com status `GENERATED`.
3. **send-emails** — Escaneia a tabela de assinantes no DynamoDB filtrando apenas os `SUBSCRIBED`, busca o HTML renderizado no S3 e envia os emails via SES em lotes de 50 com retry exponencial. Atualiza o status para `SENT` no DynamoDB.
4. **mark-newsletter-status** — Atualiza o registro da newsletter no DynamoDB com o resultado do envio (successo ou falha).
5. **notify-failure** — Publica uma mensagem no SNS notificando administradores sobre falhas no workflow.

Em caso de erro em qualquer etapa, o Step Functions desvia para o caminho de falha, executando `mark-newsletter-status` com status `FAILED` e disparando o `notify-failure`.

### API de Assinantes

Três endpoints REST expostos via API Gateway:

| Método | Rota | Handler | Descrição |
|--------|------|---------|-----------|
| POST | `/api/v1/subscribers` | subscribe-handler | Cadastra um novo assinante (com validação Zod e prevenção de duplicatas via ConditionExpression) |
| GET | `/api/v1/subscribers` | list-subscribers | Lista todos os assinantes ativos |
| GET | `/unsubscribe?email=` | unsubscribe-handler | Remove um assinante (atualiza status para UNSUBSCRIBED, retorna página HTML de confirmação) |

### Serviços AWS Utilizados

| Serviço | Função |
|---------|--------|
| **Lambda** | 8 funções Node.js 24 com 128MB–512MB de memória, agrupadas em um Lambda Layer compartilhado. Validação de env vars na inicialização via `requireEnv()` |
| **Step Functions** | Orquestração do pipeline com retry em falhas de Lambda, caminho de erro dedicado e suporte a newsletterId opcional em falhas precoces |
| **EventBridge Scheduler** | Agendamento diário do workflow (cron `0 8 * * ? *`) com DLQ (SQS) para falhas de entrega |
| **API Gateway** | REST API com 3 rotas, deployment com stage v1, CORS habilitado via OPTIONS mock |
| **DynamoDB** | 2 tabelas PAY_PER_REQUEST: `subscribers` (PK: email) e `newsletters` (PK: id, GSI por status) |
| **S3** | 2 buckets com SSE-AES256 e public access block: templates (versionamento) e HTML renderizado (expiração 90 dias) |
| **SES** | Envio de emails em lotes de 50 com retry exponencial |
| **Secrets Manager** | Armazenamento seguro da chave da NewsAPI |
| **SNS** | Tópico de notificação de falhas com assinatura por email |
| **CloudWatch** | Dashboard com 5 widgets e 3 alarmes (falha no workflow, bounce rate > 5%, erros Lambda) |

## Estrutura do Projeto

```
digest/
├── terraform/                    # Infraestrutura como código (HCL)
│   ├── main.tf                   # Módulo raiz: wiring, IAM, Secrets Manager
│   ├── modules/
│   │   ├── database/             # DynamoDB + S3 (com public access block)
│   │   ├── api/                  # API Gateway + CORS + integração Lambda
│   │   ├── lambda-function/      # Função Lambda reutilizável + IAM role
│   │   ├── lambda-layer/         # Lambda Layer compartilhado
│   │   ├── workflow/             # Step Functions + EventBridge + SNS + DLQ
│   │   └── monitoring/           # CloudWatch dashboard + alarmes
│   └── lambda-packages/          # ZIPs compilados (gitignored)
├── handlers/                     # Código TypeScript das Lambdas
│   ├── shared/                   # Lambda Layer (modelos, schemas, clientes, utilitários)
│   │   └── utils/
│   │       ├── ses-batcher.ts    # Envio em lote com retry
│   │       ├── template-cache.ts # Cache de templates Handlebars
│   │       ├── scan-all.ts       # Scan paginado do DynamoDB
│   │       └── require-env.ts    # Validação de variáveis de ambiente
│   ├── subscribe-handler/        # POST /api/v1/subscribers
│   ├── list-subscribers/         # GET /api/v1/subscribers
│   ├── unsubscribe-handler/      # GET /unsubscribe?email=
│   ├── fetch-articles/           # Busca artigos da NewsAPI
│   ├── generate-newsletter/      # Renderiza template Handlebars
│   ├── send-emails/              # Envia emails via SES (lança erro em falha parcial)
│   ├── mark-newsletter-status/   # Atualiza status (aceita newsletterId opcional)
│   └── notify-failure/           # Publica falha no SNS
├── tests/
│   ├── setup-env.ts              # Config global de env vars para testes
│   ├── unit/                     # 8 suites, 31 testes unitários
│   └── integration/              # 2 suites, 7 testes de integração
├── scripts/                      # Scripts de build, bootstrap e seed
└── .github/
    ├── workflows/
    │   ├── ci.yml                # Lint + audit + testes + build em PRs
    │   └── release.yml           # GitHub Release ao push de tag v*
    ├── dependabot.yml            # Automação de dependências
    └── pull_request_template.md  # Template de PR
```

## CI/CD

O pipeline de CI roda em pull requests para `main` (e pushes para `dev`): `npm ci` → `npm audit` → `npm run lint` → `npm test` → `npm run build:handlers`. Em pushes para `main`, o workflow de deploy executa `terraform plan` e `terraform apply -auto-approve` com as credenciais AWS armazenadas em secrets do GitHub.

## Setup

```bash
git clone https://github.com/ma-alves/digest.git
bash scripts/bootstrap-state.sh  # apenas na primeira vez
npm ci
npm run build:handlers
npm run tf:apply
```

## Comandos

| Comando | Descrição |
|---------|-----------|
| `npm test` | Testes unitários (Jest 31 testes) |
| `npm run test:integration` | Testes de integração (7 testes) |
| `npm run test:watch` | Jest watch mode |
| `npm run lint` | Type-check (tsc --noEmit) |
| `npm run build:handlers` | Compila e compacta todas as Lambdas + Layer |
| `npm run tf:plan` | Terraform plan |
| `npm run tf:apply` | Terraform apply |
| `npm run seed` | Popula assinantes de exemplo no DynamoDB |
