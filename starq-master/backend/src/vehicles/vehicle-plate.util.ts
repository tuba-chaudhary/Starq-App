export const INDIAN_STATE_CODES = new Set([
  'AN', 'AP', 'AR', 'AS', 'BR', 'CG', 'CH', 'DD', 'DL', 'DN',
  'GA', 'GJ', 'HP', 'HR', 'JH', 'JK', 'KA', 'KL', 'LA', 'LD',
  'MH', 'ML', 'MN', 'MP', 'MZ', 'NL', 'OD', 'OR', 'PB', 'PY',
  'RJ', 'SK', 'TN', 'TR', 'TS', 'UK', 'UA', 'UP', 'WB',
]);

export const STANDARD_PLATE_REGEX = /^([A-Z]{2})(?:([0-9][A-Z])|([0-9]{1,2}))([A-Z]{0,3})([0-9]{1,4})$/;
export const BHARAT_SERIES_REGEX = /^([0-9]{2})BH([0-9]{4})([A-Z]{1,2})$/;

export function isValidVehiclePlate(value: string): boolean {
  if (!value || typeof value !== 'string') return false;
  const raw = value.trim();
  if (/[^a-zA-Z0-9\s\-_]/.test(raw)) return false;

  const cleaned = raw.replace(/[\s\-_]+/g, '').toUpperCase();
  if (cleaned.length < 5 || cleaned.length > 15) return false;

  if (BHARAT_SERIES_REGEX.test(cleaned)) return true;

  const match = cleaned.match(STANDARD_PLATE_REGEX);
  if (!match) return false;

  const stateCode = match[1];
  return INDIAN_STATE_CODES.has(stateCode);
}

export function normalizeVehiclePlate(value: string): string {
  const raw = (value || '').trim();
  const cleaned = raw.replace(/[\s\-_]+/g, '').toUpperCase();

  const bhMatch = cleaned.match(BHARAT_SERIES_REGEX);
  if (bhMatch) {
    return `${bhMatch[1]} BH ${bhMatch[2]} ${bhMatch[3]}`.trim();
  }

  const stdMatch = cleaned.match(STANDARD_PLATE_REGEX);
  if (stdMatch) {
    const state = stdMatch[1] || '';
    const rto = stdMatch[2] || stdMatch[3] || '';
    const series = stdMatch[4] || '';
    const num = stdMatch[5] || '';
    if (series) {
      return `${state} ${rto} ${series} ${num}`.trim();
    } else {
      return `${state} ${rto} ${num}`.trim();
    }
  }

  return raw.toUpperCase().replace(/\s+/g, ' ');
}
