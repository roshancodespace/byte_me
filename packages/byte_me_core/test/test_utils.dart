import 'dart:io';

File getDumpFile(String filename) {
  final currentPath = Directory.current.path;
  final dumpsDir = Directory('$currentPath/test/dumps');
  if (!dumpsDir.existsSync()) {
    dumpsDir.createSync(recursive: true);
  }
  return File('${dumpsDir.path}/$filename');
}
