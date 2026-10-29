/// The student level table every pack needs: ten levels, each worth +1 study
/// efficiency over the one before. Without it the "LV n Student" box reads
/// "LV 0" and "0 / MAX", and levelling never helps. The Workshop template
/// carries the same table in `levels.json`.
const _names = ['Novice', 'Learner', 'Diligent', 'Scholar', 'Adept', 'Expert', 'Master', 'Sage', 'Prodigy', 'Legend'];

/// Cumulative exp for each level; an E-tier study block is worth 100 and each
/// tier above adds 100 more.
const _exp = [0, 500, 1500, 3000, 5000, 7500, 10500, 14000, 18000, 23000];

List<Map<String, dynamic>> defaultStudyLevels() => [
  for (var i = 0; i < _names.length; i++) {'level': i + 1, 'name': _names[i], 'exp': _exp[i], 'plusStat': i},
];

/// Adds the default `study` table to a `levels.json` document that has none.
/// A table the pack already has, and every other key, is left as it is.
/// Returns the document and whether it changed.
(Map<String, dynamic>, bool) ensureStudyLevels(Map<String, dynamic> root) {
  final study = root['study'];
  if (study is List && study.isNotEmpty) return (root, false);
  if (study is Map && (study['levels'] as List?)?.isNotEmpty == true) return (root, false);
  return ({...root, 'study': defaultStudyLevels()}, true);
}
