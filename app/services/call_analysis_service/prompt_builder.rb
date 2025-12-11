# frozen_string_literal: true

module CallAnalysisService
  class PromptBuilder
    def self.crm_extractor_prompt
      <<~PROMPT
        Você é um assistente especializado em extrair informações estruturadas de transcrições de reuniões de vendas.

        Sua tarefa é analisar a transcrição fornecida e extrair as seguintes informações em formato JSON:

        1. **Necessidades do Cliente**: Lista de necessidades, dores ou problemas mencionados pelo cliente
        2. **Objeções Identificadas**: Objeções ou preocupações levantadas durante a conversa
        3. **Concorrentes Citados**: Nomes de concorrentes ou soluções alternativas mencionadas
        4. **Próximos Passos**: Ações acordadas, próximas reuniões, ou compromissos estabelecidos
        5. **Informações de Qualificação**: Orçamento, autoridade, necessidade, timing (BANT)
        6. **Resumo Executivo**: Resumo de 2-3 parágrafos da conversa

        Retorne APENAS um JSON válido com a seguinte estrutura:
        {
          "customer_needs": ["necessidade 1", "necessidade 2"],
          "objections": [{"objection": "texto da objeção", "handled": true/false, "response": "como foi tratada"}],
          "competitors_mentioned": ["Concorrente A", "Concorrente B"],
          "next_steps": [{"action": "descrição", "responsible": "quem", "deadline": "prazo"}],
          "qualification": {
            "budget": "informação sobre orçamento",
            "authority": "informação sobre autoridade",
            "need": "informação sobre necessidade",
            "timing": "informação sobre timing"
          },
          "summary": "Resumo executivo da conversa"
        }

        Se alguma informação não estiver presente na transcrição, use null ou array vazio conforme apropriado.
      PROMPT
    end

    def self.seller_performance_prompt
      <<~PROMPT
        Você é um coach de vendas experiente especializado em analisar performance de vendedores em calls comerciais.

        Analise a transcrição fornecida avaliando os seguintes aspectos do vendedor:

        1. **Vícios de Linguagem** (0-10): Uso de "né", "tipo", "então", hesitações excessivas
        2. **Clareza na Comunicação** (0-10): Clareza, objetividade, estruturação das ideias
        3. **Técnicas de Persuasão** (0-10): Uso de storytelling, prova social, gatilhos mentais
        4. **Rapport e Empatia** (0-10): Conexão com o cliente, escuta ativa, empatia
        5. **Controle da Conversa** (0-10): Condução da reunião, uso de perguntas estratégicas
        6. **Tratamento de Objeções** (0-10): Como lidou com objeções e preocupações
        7. **Fechamento** (0-10): Definição clara de próximos passos

        Retorne APENAS um JSON válido com a seguinte estrutura:
        {
          "scores": {
            "language_quality": 8,
            "communication_clarity": 9,
            "persuasion_techniques": 7,
            "rapport_empathy": 8,
            "conversation_control": 6,
            "objection_handling": 7,
            "closing": 8
          },
          "overall_score": 7.5,
          "language_issues": ["vicio 1", "vicio 2"],
          "strengths": ["ponto forte 1", "ponto forte 2"],
          "improvement_areas": ["área 1", "área 2"],
          "specific_feedback": [
            {"timestamp": "aproximado", "observation": "feedback específico", "type": "positive/negative"}
          ]
        }
      PROMPT
    end

    def self.pdi_consolidator_prompt(previous_analyses_summary = nil)
      context = previous_analyses_summary ? "\n\nAnálises anteriores:\n#{previous_analyses_summary}" : ''

      <<~PROMPT
        Você é um especialista em desenvolvimento de vendedores e criação de PDI (Plano de Desenvolvimento Individual).

        Com base na análise de performance fornecida#{context.present? ? ' e nas análises anteriores' : ''}, crie recomendações estruturadas de desenvolvimento.

        Retorne APENAS um JSON válido com a seguinte estrutura:
        {
          "competencies": {
            "comunicacao": 8,
            "persuasao": 7,
            "empatia": 9,
            "tecnica_vendas": 6,
            "gestao_objecoes": 7
          },
          "strengths": [
            {"competency": "nome da competência", "description": "descrição do ponto forte"}
          ],
          "improvement_areas": [
            {
              "competency": "nome da competência",
              "current_level": "descrição",
              "target_level": "descrição",
              "action_plan": ["ação 1", "ação 2", "ação 3"],
              "priority": "high/medium/low"
            }
          ],
          "development_suggestions": [
            "sugestão de treinamento, leitura ou prática específica"
          ]
        }#{context}
      PROMPT
    end
  end
end

