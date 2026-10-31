import { getDatabase } from '../config/database.js';
import { AuthError } from '../services/auth.service.js';
import { addressSnapshot } from '../services/address.service.js';

export const publicAddress = (value) => ({ id: value.id, ...addressSnapshot(value), isDefault: value.isDefault });
export const missingAddress = () => new AuthError(404, 'ADDRESS_NOT_FOUND', 'This shipping address is not available.');
export function createAddressesRepository(database = getDatabase) {
  // Serialize changes for each account, including concurrent first/default addresses.
  const mutate = (userId, action) => database().$transaction(async tx => {
    await tx.$queryRaw`SELECT "id" FROM "User" WHERE "id" = ${userId}::uuid FOR UPDATE`;
    return action(tx);
  });
  const owned = async (tx, id, userId) => {
    const address = await tx.shippingAddress.findFirst({ where: { id, userId } });
    if (!address) throw missingAddress();
    return address;
  };
  return {
    async list(userId) {
      return (await database().shippingAddress.findMany({ where: { userId }, orderBy: [{ isDefault: 'desc' }, { createdAt: 'asc' }, { id: 'asc' }] })).map(publicAddress);
    },
    save(userId, input, id) {
      return mutate(userId, async tx => {
        const previous = id ? await owned(tx, id, userId) : null;
        const count = await tx.shippingAddress.count({ where: { userId } });
        if (!id && count >= 20) throw new AuthError(400, 'ADDRESS_LIMIT', 'You can save up to 20 shipping addresses.');
        const isDefault = count === 0 || previous?.isDefault === true || input.isDefault === true;
        if (isDefault) await tx.shippingAddress.updateMany({ where: { userId, isDefault: true }, data: { isDefault: false } });
        const data = { ...input, isDefault };
        const saved = id ? await tx.shippingAddress.update({ where: { id }, data })
          : await tx.shippingAddress.create({ data: { ...data, userId } });
        return publicAddress(saved);
      });
    },
    remove(userId, id) {
      return mutate(userId, async tx => {
        const previous = await owned(tx, id, userId);
        await tx.shippingAddress.delete({ where: { id } });
        if (previous.isDefault) {
          const next = await tx.shippingAddress.findFirst({ where: { userId }, orderBy: [{ createdAt: 'asc' }, { id: 'asc' }] });
          if (next) await tx.shippingAddress.update({ where: { id: next.id }, data: { isDefault: true } });
        }
        return { deleted: true };
      });
    },
  };
}
