import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/ui/composants.dart';

// La version du profil (#73) suit celle de pubspec.yaml.
void main() {
  test('versionApp = version de pubspec.yaml', () {
    final ligne = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(ligne.split(':').last.trim().split('+').first, versionApp);
  });
}
