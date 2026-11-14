import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qodi_music/core/config/settings_store.dart';
import 'package:qodi_music/features/update/domain/app_update.dart';
import 'package:qodi_music/features/update/ui/update_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/l10n.dart';

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

Set<String> _placeholders(String text) =>
    RegExp(r'\{([A-Za-z]\w*)\s*[,}]').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  group('ARB files', () {
    final enArb = _arb('app_en.arb');
    final esArb = _arb('app_es.arb');
    final keys = enArb.keys.where((k) => !k.startsWith('@')).toList();

    test('every key of app_en.arb exists in app_es.arb with a non-empty value', () {
      expect(keys, isNotEmpty);
      for (final k in keys) {
        expect(esArb[k], isA<String>(), reason: 'missing Spanish key "$k"');
        expect((esArb[k] as String).trim(), isNotEmpty, reason: 'empty Spanish value for "$k"');
        expect((enArb[k] as String).trim(), isNotEmpty, reason: 'empty English value for "$k"');
      }
      expect(esArb.keys.where((k) => !k.startsWith('@')).toSet(), keys.toSet(), reason: 'no Spanish-only keys');
    });

    test('Spanish strings use the same placeholders as English', () {
      for (final k in keys) {
        expect(_placeholders(esArb[k] as String), _placeholders(enArb[k] as String), reason: k);
      }
    });
  });

  group('plurals', () {
    test('English', () {
      expect(en.songCount(1), '1 Song');
      expect(en.songCount(0), '0 Songs');
      expect(en.songCount(12), '12 Songs');
      expect(en.songCountLower(1), '1 song');
      expect(en.songCountLower(3), '3 songs');
      expect(en.albumCount(1), '1 album');
      expect(en.albumCount(2), '2 albums');
      expect(en.importedSongs(1), 'Imported 1 song');
      expect(en.importedSongs(4), 'Imported 4 songs');
      expect(en.librarySynced(1), 'Library synced (1 change)');
      expect(en.librarySynced(7), 'Library synced (7 changes)');
    });

    test('Spanish', () {
      expect(es.songCount(1), '1 canción');
      expect(es.songCount(0), '0 canciones');
      expect(es.songCount(12), '12 canciones');
      expect(es.albumCount(1), '1 álbum');
      expect(es.albumCount(5), '5 álbumes');
      expect(es.importedSongs(1), 'Se importó 1 canción');
      expect(es.importedSongs(4), 'Se importaron 4 canciones');
      expect(es.downloadingSongs(2), 'Descargando 2 canciones');
      expect(es.channelCount(6), '6 canales');
    });
  });

  test('interpolation keeps the argument order', () {
    expect(en.lastChecked('You have the latest version', 'Nov 14, 2026 12:00'),
        'You have the latest version · checked Nov 14, 2026 12:00');
    expect(es.transcodedFrom('OPUS 128', 'FLAC 24/96'), 'OPUS 128 · desde FLAC 24/96');
    expect(es.updateQuestion('1.0.0', '1.1.0'), 'Hay una actualización disponible (v1.0.0 → v1.1.0)');
  });

  test('quality badges: Hi-Res stays, Lossless is translated', () {
    expect((en.qualityHiRes, en.qualityLossless), ('Hi-Res', 'Lossless'));
    expect((es.qualityHiRes, es.qualityLossless), ('Hi-Res', 'Sin pérdida'));
  });

  group('device locale', () {
    test('es* → Spanish, en* → English, anything else → English', () {
      expect(resolveAppLocale([const Locale('es', 'MX')]), const Locale('es'));
      expect(resolveAppLocale([const Locale('es')]), const Locale('es'));
      expect(resolveAppLocale([const Locale('fr'), const Locale('es', 'AR')]), const Locale('es'));
      expect(resolveAppLocale([const Locale('en', 'US'), const Locale('es')]), const Locale('en'));
      expect(resolveAppLocale([const Locale('de')]), const Locale('en'));
      expect(resolveAppLocale(null), const Locale('en'));
      expect(resolveAppLocale(const []), const Locale('en'));
    });

    test('forced languages map to fixed locales', () {
      expect(AppLanguage.system.locale, isNull);
      expect(AppLanguage.en.locale, const Locale('en'));
      expect(AppLanguage.es.locale, const Locale('es'));
    });
  });

  test('language preference persists in the settings store (default: system)', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    expect(store.language, AppLanguage.system);
    await store.setLanguage(AppLanguage.es);
    expect(SettingsStore(await SharedPreferences.getInstance()).language, AppLanguage.es);
    SharedPreferences.setMockInitialValues({'language': 'klingon'});
    expect(SettingsStore(await SharedPreferences.getInstance()).language, AppLanguage.system);
  });

  test('the persisted update result is shown in the active language', () {
    expect(describeUpdateResult(en, UpdateResultCode.upToDate), 'You have the latest version');
    expect(describeUpdateResult(es, UpdateResultCode.upToDate), 'Tienes la versión más reciente');
    expect(describeUpdateResult(es, '${UpdateResultCode.availablePrefix}0.3.0'), 'La versión 0.3.0 está disponible');
    expect(describeUpdateResult(es, UpdateResultCode.failed), 'No se pudo buscar actualizaciones');
    // Text stored by versions before the codes is shown as it is.
    expect(describeUpdateResult(es, 'Could not check for updates'), 'Could not check for updates');
  });
}
