import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/main.dart' as app;

void main() {
  test('palette guard: legacy olive/mustard variants are absent from runtime UI sources', () {
    final runtimeDir = Directory('lib');
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
      '0xFF22C55E',
      '#22C55E',
      '#10B981',
      '#047857',
      '#065F46',
      '0xFFF7F7F7',
      '#F7F7F7',
      '#F6F7F5',
      '#f6f7f5',
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

  test('palette guard: WhatsApp is the only general UI primary', () {
    expect(app.AppColors.primary.value, 0xFF25D366);
    expect(app.AppColors.accent, app.AppColors.primary);
    expect(app.AppColors.beanGreenLight.value, 0xFFE5F9EC);
  });

  test('palette guard: transport identities keep their separate historic colors', () {
    expect(app.AppColors.networkGreen.value, 0xFF00B140);
    expect(app.AppColors.ter.value, 0xFF8B4513);
    expect(app.AppColors.brt, app.AppColors.networkGreen);
    expect(app.AppColors.ddd, app.AppColors.networkGreen);
    expect(app.AppColors.aftu, app.AppColors.networkGreen);
    expect(app.AppColors.tata, app.AppColors.networkGreen);
    final String source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('color: AppColors.networkGreen, shape: BoxShape.circle'));
  });

  test('palette guard: countdown and action green are exactly WhatsApp green', () {
    expect(app.AppColors.beanGreen.value, 0xFF25D366);
    expect(app.AppColors.success, app.AppColors.beanGreen);
    expect(app.AppColors.accent, app.AppColors.beanGreen);
  });

  test('Trajet guard: navigation selection is a solid WhatsApp-green tab', () {
    final String source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('indicatorColor: AppColors.beanGreen,'));
    expect(source, contains('selectedIcon: Icon(Icons.alt_route_rounded, color: Colors.white)'));
    expect(source, contains('? Colors.white\n                : AppColors.textSecondary(dark)'));
  });

  test('Trajet guard: search fields and displayed departure times use WhatsApp green', () {
    final String source = File('lib/main.dart').readAsStringSync();
    expect(source, contains("_buildInputField(controller: _fromCtrl, label: 'Départ', icon: Icons.my_location, color: AppColors.beanGreen, dark: dark)"));
    expect(source, contains("_buildInputField(controller: _toCtrl, label: 'Destination', icon: Icons.location_on, color: AppColors.beanGreen, dark: dark)"));
    expect(source, contains('Icon(Icons.access_time, size: 12, color: AppColors.beanGreen)'));
    expect(source, contains('color: AppColors.beanGreen))]),'));
  });

  test('release identity is bumped to force installed PWA refresh', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String webIndex = File('web/index.html').readAsStringSync();
    expect(pubspec, contains('version: 9.3.3+18'));
    expect(webIndex, contains('content="#25D366"'));
    expect(webIndex, contains('20261125-whatsapp-green-05'));
  });

  test('web shell uses the generated Flutter bootstrap and refreshes its cache key', () {
    final String source = File('web/index.html').readAsStringSync();
    expect(
      source,
      contains('flutter_bootstrap.js?v=20261125-whatsapp-green-05'),
    );
    expect(source, contains('manifest.json?v=20261125-whatsapp-green-05'));
    expect(source, contains('content="#25D366"'));
    expect(source, isNot(contains('flutter.js?v=')));
    expect(source, isNot(contains('_flutter.loader.loadEntrypoint')));
  });
}
