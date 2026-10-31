export function readCommerceConfig(source = process.env) {
  const currency = source.STORE_CURRENCY ?? 'USD';
  const shippingFeeInCents = Number(source.SHIPPING_FEE_CENTS ?? 0);
  if (!/^[A-Z]{3}$/.test(currency) || !Number.isSafeInteger(shippingFeeInCents) || shippingFeeInCents < 0 || shippingFeeInCents > 1000000) throw new Error('Invalid store configuration.');
  const methods = {};
  for (const [method, key] of [['PAYMOB_CARD', 'PAYMOB_CARD_INTEGRATION_ID'], ['PAYMOB_WALLET', 'PAYMOB_WALLET_INTEGRATION_ID']]) {
    if (/^[1-9]\d*$/.test(source[key] ?? '') && Number.isSafeInteger(Number(source[key]))) methods[method] = Number(source[key]);
  }
  const httpsUrl = (value) => {
    try { const url = new URL(value); return url.protocol === 'https:' && !url.username && !url.password && !url.hash && !url.search; }
    catch { return false; }
  };
  // There is deliberately no live-mode path in this application.
  const enabled = source.PAYMOB_ENABLED === 'true' && source.PAYMOB_MODE === 'test' &&
    /^sk_test_/.test(source.PAYMOB_SECRET_KEY ?? '') && /^pk_test_/.test(source.PAYMOB_PUBLIC_KEY ?? '') &&
    Boolean(source.PAYMOB_HMAC_SECRET) && /^[1-9]\d*$/.test(source.PAYMOB_OWNER_ID ?? '') &&
    source.PAYMOB_CURRENCY === currency && Object.keys(methods).length > 0 &&
    httpsUrl(source.PAYMOB_NOTIFICATION_URL) && httpsUrl(source.PAYMOB_RETURN_URL);
  return { currency, shippingFeeInCents, paymob: {
    enabled, methods: enabled ? methods : {}, secret: source.PAYMOB_SECRET_KEY,
    publicKey: source.PAYMOB_PUBLIC_KEY, hmacSecret: source.PAYMOB_HMAC_SECRET,
    ownerId: source.PAYMOB_OWNER_ID, notificationUrl: source.PAYMOB_NOTIFICATION_URL,
    returnUrl: source.PAYMOB_RETURN_URL,
  } };
}
