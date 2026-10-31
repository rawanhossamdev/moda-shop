import { AuthError } from './auth.service.js';

export const addressFields = { fullName: [2, 120], mobile: [1, 30], governorate: [2, 100], city: [2, 100],
  streetAddress: [5, 500], buildingDetails: [1, 200], deliveryNotes: [0, 1000] };
export function addressInput(body) {
  const result = {};
  for (const [key, [min, max]] of Object.entries(addressFields)) {
    const value = body?.[key] ?? (min === 0 ? '' : null);
    if (typeof value !== 'string' || value.trim().length < min || value.trim().length > max || /[\x00-\x1f\x7f]/.test(value)) {
      throw new AuthError(400, 'INVALID_ADDRESS', 'Complete the required address fields.');
    }
    result[key] = value.trim();
  }
  const mobile = result.mobile.replace(/[ ()-]/g, '');
  if (!/^(?:0|\+20|0020)1[0125]\d{8}$/.test(mobile)) {
    throw new AuthError(400, 'INVALID_MOBILE', 'Enter a valid Egyptian mobile number, such as 01012345678.');
  }
  result.mobile = mobile.startsWith('0') && !mobile.startsWith('0020') ? `+20${mobile.slice(1)}`
    : mobile.replace(/^0020/, '+20');
  if (body?.isDefault !== undefined && typeof body.isDefault !== 'boolean') {
    throw new AuthError(400, 'INVALID_ADDRESS', 'Default address must be true or false.');
  }
  if (body?.isDefault !== undefined) result.isDefault = body.isDefault;
  return result;
}

export const addressSnapshot = (value) => Object.fromEntries(Object.keys(addressFields).map(key => [key, value[key]]));
