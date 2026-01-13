# Pipeline Webhooks - Documentação

## Visão Geral

O sistema de Pipeline Webhooks permite receber leads de sistemas externos (como RD Station, Facebook Ads, landing pages, etc.) automaticamente no CRM através de integrações webhook.

## Funcionalidades

- ✅ Múltiplas integrações por pipeline
- ✅ URL única e segura por integração (token)
- ✅ Wizard de configuração em 3 passos
- ✅ Mapeamento flexível de campos (suporta JSON aninhado)
- ✅ Aplicação automática de tags
- ✅ Processamento assíncrono via Sidekiq
- ✅ Ativação/desativação de webhooks

## Como Configurar

### 1. Acessar Pipelines

Navegue para: **Configurações → Conta → Pipelines**

### 2. Editar Pipeline

Clique em um pipeline existente para abrir o modal de edição.

### 3. Acessar Aba Webhooks

No modal, clique na aba **"Webhooks"**.

### 4. Criar Nova Integração

Clique em **"+ Nova Integração"** e siga o wizard:

#### Passo 1: Informações Básicas
- **Nome da Integração**: Ex: "RD Station", "Facebook Ads"
- **Etapa Inicial**: Selecione em qual etapa os leads devem ser criados
- **Webhook Ativo**: Marque para ativar imediatamente

#### Passo 2: Tags
- Adicione tags que serão aplicadas automaticamente aos leads
- Tags são criadas automaticamente se não existirem

#### Passo 3: Mapeamento de Campos
- Configure como os campos do webhook serão mapeados
- Suporte para notação de ponto: `lead.name`, `data.email`, `contact.phone`
- Campos disponíveis:
  - Nome do Contato
  - Email
  - Telefone
  - Empresa
  - Cidade
  - País
  - Título do Negócio
  - Valor
  - Data de Fechamento
  - Observações

#### Passo 4: Sucesso
- Copie a URL gerada
- Configure no sistema de origem

## Exemplo de Uso

### Payload Exemplo (JSON)

```json
{
  "lead": {
    "name": "João Silva",
    "email": "joao@example.com",
    "phone": "+5511999999999"
  },
  "company": {
    "name": "Empresa XYZ",
    "city": "São Paulo",
    "country": "Brasil"
  },
  "deal": {
    "title": "Proposta Comercial",
    "value": 5000.00,
    "close_date": "2026-02-15",
    "notes": "Lead interessado em plano enterprise"
  }
}
```

### Mapeamento Correspondente

| Campo do Sistema | Campo do Webhook |
|------------------|------------------|
| Nome | `lead.name` |
| Email | `lead.email` |
| Telefone | `lead.phone` |
| Empresa | `company.name` |
| Cidade | `company.city` |
| País | `company.country` |
| Título do Negócio | `deal.title` |
| Valor | `deal.value` |
| Data de Fechamento | `deal.close_date` |
| Observações | `deal.notes` |

### Requisição HTTP

```bash
POST https://seu-crm.com/webhooks/pipelines/ABC123TOKEN456
Content-Type: application/json

{
  "lead": {
    "name": "João Silva",
    "email": "joao@example.com",
    "phone": "+5511999999999"
  },
  "company": {
    "name": "Empresa XYZ"
  }
}
```

### Resposta

```
200 OK
```

O lead será processado assincronamente e criado no pipeline configurado.

## Segurança

- Cada webhook possui um token único de 32 caracteres
- Tokens são gerados automaticamente e não podem ser alterados
- Webhooks inativos não aceitam requisições

## Gerenciamento

### Ver Webhooks

Na aba "Webhooks" de cada pipeline, você verá:
- Nome da integração
- Status (Ativo/Inativo)
- Etapa configurada
- Tags aplicadas
- URL do webhook

### Editar Webhook

Clique no botão "Editar" para modificar:
- Nome
- Etapa
- Tags
- Mapeamento de campos

**Nota:** A URL não pode ser alterada.

### Ativar/Desativar

Use o toggle para ativar ou desativar um webhook sem deletá-lo.

### Excluir Webhook

Clique no botão "Excluir" para remover permanentemente a integração.

## Comportamento do Sistema

### Contatos Existentes

Se um lead com o mesmo email ou telefone já existir:
- O contato existente será atualizado (se houver novos dados)
- Um novo negócio será criado e vinculado ao contato

### Campos Obrigatórios

- **Nome**: Obrigatório para criar o contato
- Se não fornecido, o lead não será criado

### Tags

- Tags configuradas no webhook são aplicadas tanto ao contato quanto ao negócio
- Tags são criadas automaticamente se não existirem no sistema

### Processamento Assíncrono

- Webhooks são processados via Sidekiq (fila `medium`)
- Não bloqueia a resposta HTTP
- Logs detalhados em `log/production.log`

## Troubleshooting

### Webhook não está recebendo leads

1. Verifique se o webhook está **ativo**
2. Confirme se a URL está correta
3. Verifique os logs: `tail -f log/production.log | grep "Pipeline webhook"`

### Lead não foi criado

Possíveis causas:
- Campo "nome" não foi mapeado ou está vazio no payload
- Formato do JSON inválido
- Mapeamento de campos incorreto

Verifique os logs para detalhes do erro.

### Campos não estão sendo preenchidos

- Confirme que o mapeamento usa a notação de ponto correta
- Verifique se os campos existem no payload JSON
- Teste o payload usando o preview no passo 3 do wizard

## Estrutura Técnica

### Backend

- **Model**: `PipelineWebhook`
- **Controller CRUD**: `Api::V1::Accounts::PipelineWebhooksController`
- **Controller Público**: `Webhooks::PipelinesController`
- **Job**: `Webhooks::PipelineEventsJob`
- **Service**: `Webhooks::PipelineProcessorService`

### Frontend

- **API Client**: `app/javascript/dashboard/api/pipelineWebhooks.js`
- **Wizard**: `app/javascript/dashboard/routes/dashboard/settings/account/pipelines/components/WebhookWizard.vue`
- **Lista**: `app/javascript/dashboard/routes/dashboard/settings/account/pipelines/components/WebhookList.vue`

### Rotas

- **CRUD**: `/api/v1/accounts/:account_id/pipelines/:pipeline_id/webhooks`
- **Webhook Público**: `/webhooks/pipelines/:token`

## Suporte

Para dúvidas ou problemas, consulte os logs do sistema ou entre em contato com o suporte técnico.

