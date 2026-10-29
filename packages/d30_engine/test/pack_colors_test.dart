import 'package:d30_engine/d30_engine.dart';
import 'package:test/test.dart';

void main() {
  test('pack palettes are loaded and rejected consistently with the game', () {
    final manifest = <String, dynamic>{
      'calendar': {
        'startDate': 'DATE_2023101600',
        'endDate': 'DATE_2023111600',
      },
    };
    expect(
      PackManifest.fromJson(manifest).colorScheme.color('accent'),
      0xFFFF8B55,
    );
    final pack = PackManifest.fromJson({
      ...manifest,
      'colorScheme': {
        'preset': 'lavender',
        'colors': {'iconBackground': '#123456'},
      },
    });
    expect(pack.colorScheme.preset, 'lavender');
    expect(pack.colorScheme.color('iconBackground'), 0xFF123456);
    expect(
      pack.colorScheme.color('accent'),
      isNot(const PackColorScheme().color('accent')),
    );
    for (final invalid in [
      false,
      {'preset': 'unknown'},
      {
        'colors': {'accent': 'orange'},
      },
      {
        'colors': {'panel': '#AAFFFFFF'},
      },
    ]) {
      expect(
        () => PackManifest.fromJson({...manifest, 'colorScheme': invalid}),
        throwsA(isA<PackFormatException>()),
      );
    }
  });
}
