-- Script para verificar o resultado da migration de backfill de conversation_id

-- 1. Estatísticas gerais
SELECT 
  COUNT(*) FILTER (WHERE conversation_id IS NOT NULL) as deals_com_conversa,
  COUNT(*) FILTER (WHERE conversation_id IS NULL) as deals_sem_conversa,
  COUNT(*) as total_deals,
  ROUND(100.0 * COUNT(*) FILTER (WHERE conversation_id IS NOT NULL) / NULLIF(COUNT(*), 0), 2) as percentual_associado
FROM deals;

-- 2. Deals sem conversa (podem ser importados ou sem contact válido)
SELECT 
  id,
  title,
  contact_id,
  created_at,
  CASE 
    WHEN contact_id IS NULL THEN 'Sem contato'
    ELSE 'Contato sem conversas'
  END as motivo
FROM deals 
WHERE conversation_id IS NULL
LIMIT 10;

-- 3. Verificar integridade das associações (conversation deve pertencer ao mesmo contact)
SELECT 
  d.id as deal_id,
  d.contact_id as deal_contact_id,
  c.contact_id as conversation_contact_id,
  CASE 
    WHEN d.contact_id = c.contact_id THEN '✓ OK'
    ELSE '✗ ERRO'
  END as status
FROM deals d
INNER JOIN conversations c ON d.conversation_id = c.id
WHERE d.conversation_id IS NOT NULL
LIMIT 10;

-- 4. Deals por pipeline com associação de conversa
SELECT 
  p.name as pipeline,
  COUNT(*) as total_deals,
  COUNT(*) FILTER (WHERE d.conversation_id IS NOT NULL) as com_conversa,
  ROUND(100.0 * COUNT(*) FILTER (WHERE d.conversation_id IS NOT NULL) / NULLIF(COUNT(*), 0), 2) as percentual
FROM deals d
LEFT JOIN pipelines p ON d.pipeline_id = p.id
GROUP BY p.name
ORDER BY total_deals DESC;

