/// Default study books: one per subject per tier. Tier E..S is stored as
/// `bookRank` "1".."6"; the numbers are kss16's (see
/// docs/BASELINE-DEFAULTS-2026-10-28.md). With the engine's default
/// `study.studyWeight` 3, an E book gives 5 x 3 = 15 per study block.
class BookTier {
  const BookTier(this.letter, this.rank, this.power, this.doneCount);

  final String letter;
  final String rank;
  final int power;
  final int doneCount;
}

const bookTiers = [
  BookTier('E', '1', 5, 8),
  BookTier('D', '2', 7, 11),
  BookTier('C', '3', 10, 13),
  BookTier('B', '4', 15, 16),
  BookTier('A', '5', 22, 21),
  BookTier('S', '6', 35, 31),
];

/// Synchronizes books with the current subjects: drops books assigned to a
/// removed subject and adds missing tiers. Retained books are left untouched.
/// Returns the updated document and how many books were added (not removed).
(Map<String, dynamic>, int) ensureSubjectBooks(
  Map<String, dynamic> root,
  List<String> subjects,
) {
  final existing = root['books'] as List? ?? const [];
  final active = subjects.toSet();
  final books = [
    for (final book in existing)
      if (!(book is Map &&
          book['subject'] is String &&
          !active.contains(book['subject'])))
        book,
  ];
  final removed = existing.length - books.length;
  final have = <String>{
    for (final b in books)
      if (b is Map) '${b['subject']}|${b['bookRank']}',
  };
  var nextId =
      1 +
      existing.fold<int>(0, (m, b) {
        final id = b is Map ? b['id'] : null;
        return id is int && id > m ? id : m;
      });

  var added = 0;
  for (final subject in active) {
    for (final tier in bookTiers) {
      if (have.contains('$subject|${tier.rank}')) continue;
      books.add({
        'id': nextId++,
        'name': 'Book ${tier.letter}',
        'subject': subject,
        'power': tier.power,
        'doneCount': tier.doneCount,
        'bookRank': tier.rank,
      });
      added++;
    }
  }
  return added == 0 && removed == 0
      ? (root, 0)
      : ({...root, 'books': books}, added);
}
