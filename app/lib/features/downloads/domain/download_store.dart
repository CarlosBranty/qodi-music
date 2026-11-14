/// Port for offline track files (native only; absent on web).
abstract interface class DownloadStore {
  /// Absolute path of the downloaded file, or null.
  Future<String?> localPath(String trackId);

  Future<Set<String>> downloadedIds();

  /// Downloads [url] for [trackId]; [extension] is the file extension.
  Future<void> download(
    String trackId,
    Uri url,
    String extension, {
    void Function(double progress)? onProgress,
  });

  Future<void> delete(String trackId);

  Future<int> totalBytes();
}
