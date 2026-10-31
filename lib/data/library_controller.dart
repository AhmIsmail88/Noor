import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'media_item.dart';
import 'media_import_store.dart';

enum LibraryFilter { all, favorites, recent }

/// Persistent library: imported media, resume positions, history, favorites.
/// Stored as a small JSON file (see docs/adr/0001-json-library-store.md).
class LibraryController extends ChangeNotifier {
  LibraryController.forFile(this._file);

  final File _file;
  final Map<String, MediaItem> _items = {};
  Timer? _saveTimer;
  Future<void> _writeChain = Future.value();
  bool _readOnly = false;
  bool _disposed = false;
  int _revision = 0;
  int _savedRevision = 0;
  VoidCallback? capturePlaybackProgress;

  static Future<LibraryController> open() async {
    final dir = await getApplicationSupportDirectory();
    final c = LibraryController.forFile(
      File('${dir.path}${Platform.pathSeparator}noor_library.json'),
    );
    await c.load();
    if (Platform.isAndroid) {
      final cache = await getTemporaryDirectory();
      // Migration can copy large old imports; never block the first screen.
      unawaited(c.migrateCachedImports(cache));
    }
    return c;
  }

  Future<void> load() async {
    try {
      if (await _file.exists()) {
        final data = jsonDecode(await _file.readAsString());
        if (data is! Map || data['version'] != 1 || data['items'] is! List) {
          _readOnly = true;
          debugPrint(
            'Unsupported library format; preserving the original file.',
          );
          return;
        }
        final list = data['items'];
        if (list is List) {
          for (final e in list) {
            if (e is Map<String, dynamic>) {
              try {
                final item = MediaItem.fromJson(e);
                if (item != null) _items[item.path] = item;
              } catch (error) {
                debugPrint('Skipping invalid library item: $error');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Library file unreadable, starting empty: $e');
      try {
        await _file.rename('${_file.path}.corrupt');
      } catch (_) {
        // If quarantine fails, do not overwrite the only recoverable copy.
        _readOnly = true;
      }
    }
    notifyListeners();
  }

  bool get isEmpty => _items.isEmpty;

  /// Keep the original title and history when the same content is reselected.
  Future<MediaItem> importManagedFile(
    String sourcePath,
    String originalName, {
    MediaItem? previous,
    String? title,
    String? playbackGroup,
  }) async {
    if (_readOnly) throw StateError('Library is read-only');
    final stored = await MediaImportStore(
      Directory(p.join(_file.parent.path, 'media')),
    ).save(File(sourcePath), originalName);
    previous ??= _items.values
        .where((item) => item.contentHash == stored.contentHash)
        .firstOrNull;
    final item = MediaItem(
      path: stored.path,
      title: title ?? titleFromPath(originalName),
      addedAt: previous?.addedAt ?? DateTime.now(),
      sizeBytes: await File(stored.path).length(),
      durationMs: previous?.durationMs ?? 0,
      positionMs: previous?.positionMs ?? 0,
      lastPlayedAt: previous?.lastPlayedAt,
      favorite: previous?.favorite ?? false,
      contentHash: stored.contentHash,
      playbackGroup: playbackGroup ?? previous?.playbackGroup,
    );
    if (previous != null) _items.remove(previous.path);
    _items[item.path] = item;
    _scheduleSave();
    await flush();
    if (!_disposed) notifyListeners();
    return item;
  }

  /// Preserve existing cache copies before Android is allowed to evict them.
  Future<void> migrateCachedImports(Directory cache) async {
    if (_readOnly) return;
    for (final item in _items.values.toList()) {
      if (!p.isWithin(cache.absolute.path, File(item.path).absolute.path)) {
        continue;
      }
      try {
        await importManagedFile(
          item.path,
          p.basename(item.path),
          previous: item,
          title: item.title,
        );
      } catch (error) {
        // Leave the original record intact so a missing file can be reselected.
        debugPrint('Media migration failed: $error');
      }
    }
  }

  bool _pruning = false;
  Future<void> pruneMissingDownloads({
    Future<bool?> Function(String path)? exists,
  }) async {
    if (_pruning || _readOnly) return;
    _pruning = true;
    try {
      for (final item
          in _items.values.where((item) => item.isDownload).toList()) {
        final present = exists == null
            ? await File(item.path).exists()
            : await exists(item.path);
        if (present == false) remove(item.path);
      }
      await flush();
    } finally {
      _pruning = false;
    }
  }

  MediaItem? findByPath(String path) => _items[path];

  /// Items that were started but not finished, most recent first.
  List<MediaItem> get continueWatching {
    final list =
        _items.values
            .where(
              (i) =>
                  i.lastPlayedAt != null &&
                  i.positionMs > 5000 &&
                  !i.isFinished,
            )
            .toList()
          ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    return list.take(10).toList();
  }

  List<MediaItem> query(String text, LibraryFilter filter) {
    Iterable<MediaItem> list = _items.values;
    switch (filter) {
      case LibraryFilter.favorites:
        list = list.where((i) => i.favorite);
      case LibraryFilter.recent:
        list = list.where((i) => i.lastPlayedAt != null);
      case LibraryFilter.all:
        break;
    }
    final q = text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((i) => i.title.toLowerCase().contains(q));
    }
    final out = list.toList();
    if (filter == LibraryFilter.recent) {
      out.sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    } else {
      out.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }
    return out;
  }

  MediaItem importPath(
    String path, {
    String? title,
    bool isDownload = false,
    bool isAudio = false,
    String? savedLocation,
    int? sizeBytes,
  }) {
    final existing = _items[path];
    if (existing != null) return existing;
    int? size = sizeBytes;
    try {
      size = File(path).lengthSync();
    } catch (_) {}
    final item = MediaItem(
      path: path,
      title: title ?? titleFromPath(path),
      addedAt: DateTime.now(),
      sizeBytes: size,
      isDownload: isDownload,
      isAudio: isAudio,
      savedLocation: savedLocation,
    );
    _items[path] = item;
    _scheduleSave();
    notifyListeners();
    return item;
  }

  Future<void> groupSelection(List<MediaItem> items) async {
    if (items.length < 2) return;
    final group = 'selection-${DateTime.now().microsecondsSinceEpoch}';
    for (final item in items) {
      item.playbackGroup = group;
    }
    _scheduleSave();
    await flush();
  }

  void saveProgress(
    String path, {
    required int positionMs,
    required int durationMs,
    bool notify = true,
  }) {
    final item = _items[path];
    if (item == null) return;
    item.durationMs = durationMs < 0 ? 0 : durationMs;
    item.positionMs = positionMs.clamp(0, item.durationMs);
    item.lastPlayedAt = DateTime.now();
    _scheduleSave();
    if (notify) notifyListeners();
  }

  void toggleFavorite(String path) {
    final item = _items[path];
    if (item == null) return;
    item.favorite = !item.favorite;
    _scheduleSave();
    notifyListeners();
  }

  void remove(String path) {
    if (_items.remove(path) != null) {
      _scheduleSave();
      notifyListeners();
    }
  }

  /// Lets callers that saved with `notify: false` (e.g. from dispose)
  /// trigger a rebuild later, outside the framework's locked phase.
  void refresh() {
    if (!_disposed) notifyListeners();
  }

  void _scheduleSave() {
    _revision++;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), flush);
  }

  Future<void> flush() {
    _saveTimer?.cancel();
    _writeChain = _writeChain.then((_) => _write());
    return _writeChain;
  }

  Future<void> _write() async {
    if (_readOnly || _revision == _savedRevision) return;
    final revision = _revision;
    try {
      await _file.parent.create(recursive: true);
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({
          'version': 1,
          'items': _items.values.map((e) => e.toJson()).toList(),
        }),
        flush: true,
      );
      await tmp.rename(_file.path);
      _savedRevision = revision;
    } catch (e) {
      debugPrint('Library save failed: $e');
    }
  }

  @override
  void dispose() {
    unawaited(flush());
    _disposed = true;
    super.dispose();
  }
}
