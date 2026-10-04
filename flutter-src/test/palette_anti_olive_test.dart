import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('palette guard: legacy olive/mustard variants are absent from runtime UI sources', () {
    final runtimeDir = Directory('../lib');
    expect(runtimeDir.existsSync(), isTrue, reason: 'Le dossier lib du package Flutter doit exister.');

    const forbidden = <String>[
      'ColorScheme.fromSeed',
      'colorSchemeSeed',
      'Colors.olive',
      'Colors.amber',
      'Colors.lime',
      'Colors.yellow',
      '0xFF808000',
      '#808000',
      '0xFFFFAB00',
      '#FFAB00',
      '0xFF00875A',
      '#00875A',
      '0xFF00A651',
      '#00A651',
      '0xFF9E9D24',
      '#9E9D24',
      '0xFF827717',
      '#827717',
      '0xFF6B8E23',
      '#6B8E23',
    ];

    final runtimeFiles = runtimeDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    expect(runtimeFiles, isNotEmpty);

    for (final file in runtimeFiles) {
      final source = file.readAsStringSync().toUpperCase();
      for (final token in forbidden) {
        expect(
          source.contains(token.toUpperCase()),
          isFalse,
          reason: '$token réintroduit dans ${file.path}',
        );
      }
    }
  });
}
