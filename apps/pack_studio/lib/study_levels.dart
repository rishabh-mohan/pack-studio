/// The student level table every pack needs: ten levels, each worth +1 study
/// efficiency over the one before. Without it the "LV n Student" box reads
/// "LV 0" and "0 / MAX", and levelling never helps. The Workshop template
/// carries the same table in `levels.json`.
const _names = ['Novice', 'Learner', 'Diligent', 'Scholar', 'Adept', 'Expert', 'Master', 'Sage', 'Prodigy', 'Legend'];

/// Cumulative exp for each level; one study block is worth 25.
const _exp = [0, 200, 500, 900, 1400, 2000, 2700, 3500, 4400, 5400];

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
