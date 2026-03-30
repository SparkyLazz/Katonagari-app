import 'package:drift/drift.dart';
import '../database/app_database.dart';

class WalletRepository {
  final AppDatabase _db;
  const WalletRepository(this._db);

  Stream<List<Wallet>> watchAll() =>
      (_db.select(_db.wallets)
            ..orderBy([(w) => OrderingTerm.asc(w.createdAt)]))
          .watch();

  Future<Wallet?> getDefault() =>
      (_db.select(_db.wallets)..limit(1)).getSingleOrNull();

  Future<Wallet?> getById(int id) =>
      (_db.select(_db.wallets)..where((w) => w.id.equals(id)))
          .getSingleOrNull();

  Future<int> add(WalletsCompanion entry) =>
      _db.into(_db.wallets).insert(entry);

  Future<bool> update(WalletsCompanion entry) =>
      _db.update(_db.wallets).replace(entry);

  Future<int> delete(int id) =>
      (_db.delete(_db.wallets)..where((w) => w.id.equals(id))).go();

  /// Adds [delta] to the wallet's current balance.
  /// Pass a positive delta for INCOME, negative for EXPENSE.
  Future<void> adjustBalance(int walletId, double delta) async {
    final wallet = await getById(walletId);
    if (wallet == null) return;
    await update(
      wallet.toCompanion(false).copyWith(
        balance: Value(wallet.balance + delta),
      ),
    );
  }

  /// Returns how many transactions are linked to this wallet.
  Future<int> transactionCount(int walletId) async {
    final rows = await (_db.select(_db.transactions)
          ..where((t) => t.walletId.equals(walletId)))
        .get();
    return rows.length;
  }
}