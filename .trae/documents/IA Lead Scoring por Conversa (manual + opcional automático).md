## Objetivo
- Avaliar se um lead é qualificado com base nas mensagens da conversa e gerar uma nota (0–100).
- Persistir o resultado e rotular a conversa com `Score XX` (criando o label quando necessário).

## Alinhamento com a estrutura atual de IA
- Reutilizar a integração existente (`integrations/openai`) e o padrão de prompts em arquivo.
- Criar um documento de prompt do agente em `lib/integrations/openai/openai_prompts/lead_scoring.md` com instruções e exemplos, similar ao usado em “Analisar conversas com IA”.
- Adicionar novo evento `lead_scoring` em `Integrations::Openai::ProcessorService` que lê o prompt do arquivo e força `response_format: json_object`.

## Backend
1. Endpoint
- `POST /api/v1/accounts/:account_id/conversations/:conversation_id/lead_scoring`
- Retorna `202 Accepted` e enfileira job; idempotente quando já houver `lead_scored_at` (configurável).

2. Job/Serviço
- `LeadScoringJob` chama `LeadScoringService`.
- `LeadScoringService` monta contexto (mensagens não-atividade, idioma, inbox, labels atuais), usa `ProcessorService.lead_scoring`.
- Persistência:
  - `custom_attributes`: `lead_score` (int), `lead_qualified` (bool), `lead_scored_at` (timestamp), `lead_reasons` (array/string).
  - Labels: cria/usa `Score ${score}`; opcional: `Lead: Qualificado` / `Lead: Não qualificado`.

3. Salvaguardas de custo (opcional auto)
- Flag por conta `auto_lead_scoring_enabled` (default off).
- Threshold mínimo: ≥ N mensagens/≥ M palavras.
- Rate limit: 1x por conversa a cada 24h; não roda se já houver `lead_scored_at`.

## Frontend
1. Botão de ação
- Em `MoreActions.vue`, adicionar “Analisar lead (IA)” com ícone.
- Ao clicar: chama o endpoint; mostra toast “Análise iniciada”; desabilita reenvio enquanto aguarda.

2. Exibição do resultado
- Mostrar `lead_score` e qualificação no header (chip) e/ou na sidebar “Informação da conversa”.
- Sem mudanças no Kanban agora; poderá ser estendido para filtros/ordenar por score.

## Prompt do agente (documento)
- Estrutura:
  - Objetivo, critérios (BANT/qualificação mínima), confidencialidade/privacidade.
  - Input esperado (trechos recentes da conversa; idioma).
  - Output JSON rígido: `{ qualified: boolean, score: number, reasons: string[], risk_flags: string[] }`.
  - Exemplos curtos em PT-BR/EN para consistência.

## Segurança/Privacidade
- Não enviar anexos binários; só texto/assuntos.
- Respeitar permissões de usuário e escopo de conta.

## Testes
- Unidade: serviço com mock OpenAI; parsing/persistência.
- Integração: endpoint → job → atualização de atributos/labels.
- UI: botão e estados de loading; render do score.

## Entregáveis
- Arquivo de prompt `lead_scoring.md`.
- Evento `lead_scoring` no processor.
- Endpoint + job + serviço.
- UI: botão e exibição do resultado.

Se aprovado, implemento a Fase 1 (botão manual + persistência) usando exatamente essa estrutura e deixo a configuração de auto como opcional para etapa seguinte.

## Qual fluxo escolho?
- “Nota privada” é o mais direto e robusto, pois:
  - Usa o que já existe (push/email por mensagem).
  - Mostra o contexto na conversa para quem abrir.
