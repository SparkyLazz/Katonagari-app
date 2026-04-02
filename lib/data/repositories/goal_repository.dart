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
  Future<void> topUp(Goal goal, double amount) async {
    final newSaved = (goal.savedAmount + amount).clamp(0.0, goal.targetAmount);
    await update(goal.toCompanion(false).copyWith(
      savedAmount: Value(newSaved),
    ));
  }
}