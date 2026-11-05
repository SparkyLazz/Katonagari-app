import 'package:drift/drift.dart';
import '../database/app_database.dart';

class GoalRepository {
  final AppDatabase _db;
  const GoalRepository(this._db);

  Stream<List<Goal>> watchAll() => _db.watchGoals();

  Future<int> add(GoalsCompanion entry) =>
      _db.into(_db.goals).insert(entry);

  Future<bool> update(GoalsCompanion entry) =>
      _db.update(_db.goals).replace(entry);

  Future<int> delete(int id) =>
      (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();

  /// Top-up: adds [amount] to savedAmount, capped at targetAmount.
  /// Reads the current row instead of trusting [goal], which may be a stale
  /// snapshot from when the sheet was opened.
  Future<void> topUp(Goal goal, double amount) {
    return _db.transaction(() async {
      final current = await (_db.select(_db.goals)
            ..where((g) => g.id.equals(goal.id)))
          .getSingleOrNull();
      if (current == null) return;
      final newSaved =
          (current.savedAmount + amount).clamp(0.0, current.targetAmount);
      await (_db.update(_db.goals)..where((g) => g.id.equals(goal.id)))
          .write(GoalsCompanion(savedAmount: Value(newSaved)));
    });
  }
}