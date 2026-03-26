import InboxesAPI from 'dashboard/api/inboxes';

/**
 * Para números brasileiros, retorna o variante alternativo (com↔sem o 9º dígito).
 * Ex: "5535991891712" (13 dígitos, com 9) → "553591891712" (12 dígitos, sem 9)
 *     "553591891712"  (12 dígitos, sem 9) → "5535991891712" (13 dígitos, com 9)
 * Retorna null se não for aplicável.
 */
export const getBrazilianPhoneAlternate = digits => {
  if (!digits || !digits.startsWith('55')) return null;
  const ddd = digits.slice(2, 4);
  const rest = digits.slice(4);
  if (digits.length === 13 && rest[0] === '9') {
    // Remove o 9 obrigatório: 55 + DDD + 8 dígitos
    return '55' + ddd + rest.slice(1);
  }
  if (digits.length === 12) {
    // Adiciona o 9 obrigatório: 55 + DDD + 9 + 8 dígitos
    return '55' + ddd + '9' + rest;
  }
  return null;
};

const checkExists = async (inboxId, digits) => {
  try {
    const { data } = await InboxesAPI.checkOnWhatsApp(inboxId, digits);
    return data?.exists === true;
  } catch {
    return null; // null = indeterminado (API falhou)
  }
};

/**
 * Verifica qual variante do número está registrada no WhatsApp via Baileys onWhatsApp.
 *
 * Estratégia para números brasileiros com 13 dígitos (armazenados COM o 9):
 *   1. Testa PRIMEIRO o variante SEM o 9 (problema mais comum: salvo com 9 mas WA é sem 9)
 *   2. Se não encontrar, testa o original COM o 9
 *
 * Para números com 12 dígitos (sem o 9) ou não-brasileiros:
 *   1. Testa o original
 *   2. Se não encontrar, testa com o 9
 *
 * Se o endpoint falhar (não-Baileys ou erro de rede), retorna o número original.
 *
 * @param {number} inboxId  - ID da inbox WhatsApp
 * @param {string} phoneNumber - número (com ou sem +, com ou sem formatação)
 * @returns {Promise<string>} - número confirmado em dígitos para usar como sourceId
 */
export const resolveWhatsAppPhone = async (inboxId, phoneNumber) => {
  const digits = phoneNumber.replace(/\D/g, '');
  const alternate = getBrazilianPhoneAlternate(digits);

  if (!alternate) {
    // Número não-brasileiro ou sem variante: usa como está
    return digits;
  }

  // Para números COM o 9 (13 dígitos): testa SEM o 9 primeiro
  // Razão: a maioria dos problemas é "salvo com 9 mas WA cadastrado sem 9"
  const isWith9 = digits.length === 13;
  const first = isWith9 ? alternate : digits;
  const second = isWith9 ? digits : alternate;

  const firstExists = await checkExists(inboxId, first);
  if (firstExists === null) {
    // API indisponível (inbox não é Baileys ou erro de rede) → usa original
    return digits;
  }
  if (firstExists) return first;

  const secondExists = await checkExists(inboxId, second);
  if (secondExists) return second;

  // Nenhum encontrado no WhatsApp → usa o original para não bloquear
  return digits;
};
