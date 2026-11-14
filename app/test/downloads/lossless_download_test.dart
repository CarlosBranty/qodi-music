import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/core/config/core_providers.dart';
import 'package:qodi_music/features/downloads/ui/downloads_controller.dart';

import '../support/fakes.dart';
import '../support/fixtures.dart';

void main() {
  test('Apple Lossless downloads are saved as FLAC; other formats keep their extension', () async {
    final store = FakeDownloadStore();
    final c = ProviderContainer(overrides: [
      downloadStoreProvider.overrideWithValue(store),
      mediaUrlsProvider.overrideWithValue(NoCoverUrls()),
    ]);
    addTearDown(c.dispose);
    final downloads = c.read(downloadsControllerProvider.notifier);

    await downloads.download(track('alac', format: 'm4a', lossless: true));
    await downloads.download(track('aac', format: 'm4a'));
    await downloads.download(track('mp3'));

    expect(store.extensions, {'alac': 'flac', 'aac': 'm4a', 'mp3': 'mp3'});
    expect(c.read(downloadsControllerProvider).ids, {'alac', 'aac', 'mp3'});
  });
}
