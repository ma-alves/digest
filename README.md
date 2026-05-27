# Digest

*Legado da aplicação atualmente utilizada como referência.*

Digest é uma aplicação de newsletter automatizada que busca artigos da NewsAPI com base em critérios configuráveis, gera um email estilizado com Thymeleaf e envia a newsletter periodicamente para assinantes via AWS SES. O processo é orquestrado por um pipeline Spring Batch de 3 etapas, agendado diariamente com Quartz Scheduler.

## Tech Stack
- [Spring Boot](https://github.com/spring-projects/spring-boot) - Application Framework
- [Spring Batch](https://github.com/spring-projects/spring-batch) - Batch Processing
- [Quartz Scheduler](https://github.com/quartz-scheduler/quartz) - Job Scheduling
- [Spring Data JPA](https://github.com/spring-projects/spring-data-jpa) - Persistence
- [PostgreSQL](https://www.postgresql.org) - Banco de Dados
- [H2](https://www.h2database.com) - Banco de Dados de Teste
- [AWS SES](https://aws.amazon.com/ses/) - Email Service
- [NewsAPI](https://newsapi.org) - Fonte de Artigos
- [Thymeleaf](https://www.thymeleaf.org/) - Template Engine
- [WebClient (Spring WebFlux)](https://github.com/spring-projects/spring-webflux) - HTTP Client
- [Docker Compose](https://docs.docker.com/compose/) - Container Orchestration
- [GitHub Actions](https://github.com/features/actions) - CI/CD

## Configuração
1. Clone o repositório:
```bash
git clone https://github.com/ma-alves/digest.git
```
2. Ajuste as variáveis de ambiente:
```bash
cp .env.example .env
```
3. Inicie o banco de dados com Docker Compose:
```bash
docker-compose up -d postgres
```
4. Execute a aplicação:
```bash
./mvnw spring-boot:run
```

## Arquitetura

### Fluxo de Processamento
O projeto utiliza Spring Batch para orquestrar um pipeline de 3 etapas executadas sequencialmente. O Quartz Scheduler dispara o job diariamente às 08:00 UTC. Dados compartilhados entre etapas são passados via `JobExecutionContext`.

### Agendamento
- Agendamento baseado em Quartz com expressão CRON configurável
- Disparo diário para buscar artigos do dia anterior
- JobParameters únicos baseados em timestamp para evitar execuções duplicadas

### Geração de Newsletter
- Template Thymeleaf responsivo com artigos estilizados
- Fallback para estado vazio ("Nenhum artigo disponível")
- Rastreamento de status da newsletter (GENERATED, SENT, FAILED)

## Detalhes Técnicos

### Consumidor NewsAPI
O módulo `NewsAPIClient` utiliza WebClient reativo para consumir a API v2 do NewsAPI:
- Endpoint `/v2/everything` com parâmetros configuráveis (query, idioma, data, pageSize)
- Ordenação por data de publicação
- Timeout de conexão de 10s e resposta de 5s
- Tratamento de erros para respostas 4xx/5xx

### Modelo de Dados
- **Subscriber**: Assinantes com email único e timestamp de criação
- **Newsletter**: Newsletters geradas com título, contagem de artigos e status
- Relacionamentos com índices para consultas eficientes

### Camada de Persistência
- PostgreSQL para dados estruturados (assinantes, newsletters)
- Índices em timestamps para ordenação eficiente
- Spring Data JPA com Hibernate para abstração de banco
- Schema gerenciado automaticamente com `ddl-auto=update`

### Camada de Email
- AWS SES para envio de emails transacionais
- Batching de 50 destinatários por chamada (limite da SES)
- Retry com exponential backoff (máximo configurável, padrão 3)
- Suporte a charset UTF-8

### API REST
- `POST /api/v1` - Cadastro de assinantes com validação de email
- Tratamento centralizado de exceções com `@ControllerAdvice`
- Respostas padronizadas com código de erro, timestamp e detalhes

## Fluxo de Dados

1. **Quartz Scheduler** ou **EventBridge** disparam o job diariamente
2. **NewsArticleTasklet** busca artigos da NewsAPI com base nos parâmetros configurados
3. **NewsletterGenerationTasklet** renderiza o template Thymeleaf com os artigos e persiste a entidade Newsletter
4. **EmailSendingTasklet** recupera todos os assinantes do banco e envia emails em lote via AWS SES
5. Status da newsletter é atualizado para SENT ou FAILED conforme o resultado

## Estrutura de Diretórios

```
digest/
├── aws/                      # Scripts de deploy e infraestrutura AWS
├── docs/                     # Documentação adicional
├── src/
│   ├── main/
│   │   ├── java/com/example/digest/
│   │   │   ├── batch/        # Tasklets e listeners do Spring Batch
│   │   │   ├── client/       # Cliente NewsAPI (request/response DTOs)
│   │   │   ├── config/       # Configurações (AWS SES, Batch, Quartz, Dotenv)
│   │   │   ├── controllers/  # REST controller (assinantes)
│   │   │   ├── dto/          # Data Transfer Objects
│   │   │   ├── exception/    # Tratamento global de exceções
│   │   │   ├── models/       # Entidades JPA (Subscriber, Newsletter)
│   │   │   ├── repositories/ # Repositórios Spring Data JPA
│   │   │   └── services/     # Lógica de negócio (email, assinantes)
│   │   └── resources/
│   │       └── templates/    # Template Thymeleaf de email
│   └── test/                 # Testes unitários e de integração
├── docker-compose.yaml       # Orquestração PostgreSQL
├── Dockerfile                # Build multi-estágio
└── pom.xml                   # Dependências Maven
```

## CI/CD 

O projeto utiliza **GitHub Actions** para automação de build, testes e deploy. A pipeline é executada automaticamente em pushes para a branch `main`.

### Pipeline de Deploy

A pipeline configurada em `.github/workflows/deploy.yml` realiza as seguintes etapas:

1. **Setup de Ambiente**
   - JDK 25 (Temurin) com cache Maven
   - Checkout do código

2. **Build e Testes**
   - Compilação e execução de testes com `./mvnw clean package`
   - Validação de dependências e configurações

3. **Deploy para AWS ECS**
   - Login no Amazon ECR
   - Build e push da imagem Docker com tag baseada no commit SHA
   - Atualização da task definition do ECS com a nova imagem
   - Forçar novo deployment no serviço ECS Fargate
   - Verificação do status do deployment

### Benefícios

- **Validação Automática**: Cada commit é testado e buildado automaticamente
- **Deploy Contínuo**: Atualização automática da infraestrutura AWS
- **Consistência**: Ambiente de produção reproduzível via Docker multi-estágio
- **Segurança**: Credenciais gerenciadas via GitHub Secrets e AWS Secrets Manager

## Testes

O projeto inclui testes de integração que validam:
- Carregamento do contexto Spring com todas as configurações

*Observação: a cobertura de testes ainda não está completa*

*Documento parcialmente gerado por IA, revisado e mantido por ma-alves.*
