import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('palette guard: legacy olive/mustard variants are absent from runtime UI sources', () {
    final runtimeFiles = <String>[
      '../lib/main.dart',
      '../lib/services/data_service.dart',
    ];

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
    ];

    for (final relativePath in runtimeFiles) {
      final source = File(relativePath).readAsStringSync().toUpperCase();
      for (final token in forbidden) {
        expect(
          source.contains(token.toUpperCase()),
          isFalse,
          reason: '$token réintroduit dans $relativePath',
        );
      }
    }
  });
}
