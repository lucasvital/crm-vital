# Instruções para Rodar a Migration

## Opção 1: Via Coolify (Recomendado para Produção)

1. Acesse o terminal do container Rails no Coolify
2. Execute:
```bash
bundle exec rails db:migrate
```

## Opção 2: Via Make (Ambiente Local)

```bash
make db_migrate
```

## Opção 3: Direto via Rails Console no Coolify

Se precisar fazer manualmente:

```ruby
# Abra o console Rails
bundle exec rails console

# Execute os comandos SQL diretamente
ActiveRecord::Base.connection.execute("ALTER TABLE portals ADD COLUMN is_global BOOLEAN NOT NULL DEFAULT false")
ActiveRecord::Base.connection.execute("CREATE INDEX index_portals_on_is_global ON portals (is_global)")
ActiveRecord::Base.connection.execute("ALTER TABLE portals ALTER COLUMN account_id DROP NOT NULL")
```

## Verificar se a migration foi aplicada

```bash
bundle exec rails db:migrate:status
```

Ou no console Rails:
```ruby
Portal.column_names.include?('is_global')
# Deve retornar true
```

## Após rodar a migration

Reinicie o servidor Rails para que as mudanças tenham efeito.
