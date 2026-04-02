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
 * Estratégia: CONFIAR no número armazenado primeiro.
 *   1. Testa o número ORIGINAL (como salvo no contato)
 *   2. Se não encontrar no WhatsApp, testa o variante (com/sem 9)
 *   3. Se nenhum for encontrado ou a API falhar, usa o original
 *
 * Isso garante que números salvos corretamente (com ou sem 9) funcionem sem alteração,
 * e apenas faz a troca quando o número salvo definitivamente não existe no WhatsApp.
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

  // Testa PRIMEIRO o número original (como salvo no contato)
  const originalExists = await checkExists(inboxId, digits);
  if (originalExists === null) {
    // API indisponível (inbox não é Baileys ou erro de rede) → usa original
    return digits;
  }
  if (originalExists) return digits;

  // Original não existe no WhatsApp → tenta o variante (com/sem 9)
  const alternateExists = await checkExists(inboxId, alternate);
  if (alternateExists) return alternate;

  // Nenhum encontrado → usa o original para não bloquear
  return digits;
};
