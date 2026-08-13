import 'dart:convert';
import 'dart:io';

import '../models/download_metadata.dart';

abstract interface class MetadataStore {
  Future<void> save(DownloadMetadata metadata);
  Future<DownloadMetadata?> read(String taskId);
  Future<void> delete(String taskId);
  Future<List<DownloadMetadata>> readAll();
}

class JsonMetadataStore implements MetadataStore {
  final Directory storageDirectory;

  JsonMetadataStore(this.storageDirectory);

  File _getFile(String taskId) {
    return File('${storageDirectory.path}/$taskId.meta.json');
  }

  @override
  Future<void> save(DownloadMetadata metadata) async {
    final file = _getFile(metadata.taskId);
    final jsonString = jsonEncode(metadata.toJson());
    await file.writeAsString(jsonString, flush: true);
  }

  @override
  Future<DownloadMetadata?> read(String taskId) async {
    final file = _getFile(taskId);
    if (!file.existsSync()) return null;

    try {
      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return DownloadMetadata.fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> delete(String taskId) async {
    final file = _getFile(taskId);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  @override
  Future<List<DownloadMetadata>> readAll() async {
    final List<DownloadMetadata> allMetadata = [];
    if (!storageDirectory.existsSync()) return allMetadata;

    final files = storageDirectory.listSync().whereType<File>();
    for (final file in files) {
      if (file.path.endsWith('.meta.json')) {
        try {
          final jsonString = await file.readAsString();
          allMetadata.add(DownloadMetadata.fromJson(jsonDecode(jsonString)));
        } catch (_) {}
      }
    }
    return allMetadata;
  }
}
