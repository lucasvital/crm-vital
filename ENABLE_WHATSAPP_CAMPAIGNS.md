# Como Habilitar Campanhas WhatsApp

## Problema
A opção de WhatsApp não aparece no menu de campanhas porque a feature flag `whatsapp_campaign` não está habilitada na conta.

## Solução

### Opção 1: Via Console do Rails (Recomendado)

1. Abra o console do Rails:
```bash
rails console
```

2. Encontre a conta que precisa ter a feature flag habilitada:
```ruby
# Listar todas as contas
Account.all

# Ou encontrar uma conta específica
account = Account.find_by(name: "Nome da Conta")
# ou
account = Account.find(1) # substitua 1 pelo ID da conta
```

3. Habilite a feature flag:
```ruby
account.enable_features!(:whatsapp_campaign)
```

4. Verifique se foi habilitada:
```ruby
account.feature_enabled?(:whatsapp_campaign)
# Deve retornar: true
```

### Opção 2: Via API da Plataforma

Se você tiver acesso à API da plataforma, pode habilitar a feature flag usando:

```bash
curl -X PUT \
  https://seu-dominio.com/platform/api/v1/accounts/{account_id} \
  -H 'Content-Type: application/json' \
  -H 'api_access_token: SEU_TOKEN' \
  -d '{
    "features": {
      "whatsapp_campaign": true
    }
  }'
```

### Opção 3: Via Super Admin (se disponível)

Se você tiver acesso ao painel de Super Admin, pode habilitar a feature flag através da interface administrativa.

## Verificação

Após habilitar a feature flag:

1. Recarregue a página do dashboard
2. Vá para o menu de Campanhas
3. A opção "WhatsApp" deve aparecer junto com "Live chat" e "SMS"

## Notas Importantes

- A feature flag `whatsapp_campaign` está definida em `config/features.yml` como `enabled: false` por padrão
- Cada conta precisa ter a feature flag habilitada individualmente
- A feature flag precisa estar habilitada para que:
  - A opção apareça no menu
  - As rotas de WhatsApp funcionem
  - As campanhas de WhatsApp possam ser criadas e executadas

## Referências

- Arquivo de rotas: `app/javascript/dashboard/routes/dashboard/campaigns/campaigns.routes.js`
- Modelo de Account: `app/models/account.rb`
- Módulo Featurable: `app/models/concerns/featurable.rb`
- Feature flags: `config/features.yml`

