// Utilities to build a PIX EMV payload (TLV), compute CRC16 and generate a QR data URL.
// Usage: import { buildPixQr } from 'web/src/utils/pix';
//
// buildPixQr({ pixKey, merchantName, merchantCity, amount, txid }) => { payload, qrDataUrl }

import qrcode from 'qrcode';

type PixOpts = {
  pixKey: string; // chave PIX (e.g., email, cpf/cnpj, telefone, EVP)
  merchantName: string; // nome do recebedor (até 25 chars recomendado)
  merchantCity: string; // cidade do recebedor (até 15 chars recomendado)
  amount?: number | string; // valor em BRL, ex: 123.45 or "123.45". Omitir para pagamento sem valor fixo
  txid?: string; // identificador de transação (até 25 chars recomendado)
};

function tlv(id: string, value: string): string {
  const len = String(value.length).padStart(2, '0');
  return id + len + value;
}

// CRC16-CCITT (poly 0x1021), initial 0xFFFF, output hex uppercase 4 chars
function crc16(buf: string): string {
  // Process as bytes (ASCII)
  let crc = 0xffff;
  for (let i = 0; i < buf.length; i++) {
    crc ^= buf.charCodeAt(i) << 8;
    for (let j = 0; j < 8; j++) {
      if ((crc & 0x8000) !== 0) crc = ((crc << 1) ^ 0x1021) & 0xffff;
      else crc = (crc << 1) & 0xffff;
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}

function sanitizeMerchantName(name: string): string {
  // EMV recommends up to 25 chars. We'll uppercase and trim.
  return name.toUpperCase().slice(0, 25);
}

function sanitizeMerchantCity(city: string): string {
  return city.toUpperCase().slice(0, 15);
}

function formatAmount(amount?: number | string): string | undefined {
  if (amount === undefined || amount === null || amount === '') return undefined;
  // Ensure dot decimal with two places
  const num = typeof amount === 'string' ? Number(amount.replace(',', '.')) : Number(amount);
  if (Number.isNaN(num)) return undefined;
  return num.toFixed(2);
}

export async function buildPixQr(opts: PixOpts): Promise<{ payload: string; qrDataUrl: string }> {
  const { pixKey, merchantName, merchantCity, amount, txid } = opts;

  // 00 - Payload Format Indicator
  let payload = tlv('00', '01');

  // 26 - Merchant Account Information (BR.GOV.BCB.PIX)
  // subfields: 00 - GUI, 01 - chave, (optionally) 02 - info adicional/txid
  const mai00 = tlv('00', 'BR.GOV.BCB.PIX');
  const mai01 = tlv('01', String(pixKey));
  const maiInner = mai00 + mai01 + (txid ? tlv('02', String(txid)) : '');
  payload += tlv('26', maiInner);

  // 52 - Merchant Category Code (default 0000)
  payload += tlv('52', '0000');

  // 53 - Transaction Currency (986 = BRL)
  payload += tlv('53', '986');

  // 54 - Amount (optional)
  const amt = formatAmount(amount);
  if (amt) payload += tlv('54', amt);

  // 58 - Country
  payload += tlv('58', 'BR');

  // 59 - Merchant Name
  payload += tlv('59', sanitizeMerchantName(merchantName || '')); 

  // 60 - Merchant City
  payload += tlv('60', sanitizeMerchantCity(merchantCity || '')); 

  // 62 - Additional Data Field Template (used for txid/ref label)
  // subfield 05 is commonly used for txid
  if (txid) {
    const adf05 = tlv('05', String(txid));
    const adf = tlv('62', adf05);
    payload += adf;
  }

  // 63 - CRC (placeholder + computed)
  const crcPlaceholder = '6304';
  const payloadForCrc = payload + crcPlaceholder;
  const crc = crc16(payloadForCrc);
  const full = payloadForCrc + crc;

  // Generate QR data URL
  const qrDataUrl = await qrcode.toDataURL(full, { errorCorrectionLevel: 'M' });

  return { payload: full, qrDataUrl };
}

export { tlv, crc16 };
