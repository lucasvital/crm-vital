import InboxesAPI from 'dashboard/api/inboxes';

/**
 * Para números brasileiros, retorna o variante alternativo (com↔sem o 9º dígito).
 * Ex: "5511987654321" (13 dígitos) → "551187654321" (12 dígitos), e vice-versa.
 * Retorna null se não for aplicável.
 */
export const getBrazilianPhoneAlternate = digits => {
  if (!digits || !digits.startsWith('55')) return null;
  const ddd = digits.slice(2, 4);
  const rest = digits.slice(4);
  if (digits.length === 13 && rest[0] === '9') {
    return '55' + ddd + rest.slice(1);
  }
  if (digits.length === 12) {
    return '55' + ddd + '9' + rest;
  }
  return null;
};

/**
 * Verifica qual variante do número brasileiro está registrada no WhatsApp via Baileys.
 * Tenta o número principal; se não existir, tenta o variante (com/sem 9).
 *
 * @param {number} inboxId - ID da inbox WhatsApp Baileys
 * @param {string} phoneNumber - número no formato internacional (+5511987654321 ou só dígitos)
 * @returns {Promise<string>} - número confirmado (apenas dígitos) pronto para ser usado como sourceId
 */
export const resolveWhatsAppPhone = async (inboxId, phoneNumber) => {
  const digits = phoneNumber.replace(/\D/g, '');

  try {
    const { data } = await InboxesAPI.checkOnWhatsApp(inboxId, digits);
    if (data?.exists) return digits;
  } catch {
    // Se o endpoint falhar, usa o número original sem bloquear o fluxo
    return digits;
  }

  const alternate = getBrazilianPhoneAlternate(digits);
  if (!alternate) return digits;

  try {
    const { data } = await InboxesAPI.checkOnWhatsApp(inboxId, alternate);
    if (data?.exists) {
      return alternate;
    }
  } catch {
    // Se o segundo check também falhar, usa o original
  }

  return digits;
};
