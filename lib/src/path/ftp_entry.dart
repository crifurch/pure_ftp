import 'package:meta/meta.dart';

@immutable
abstract class FtpEntry {
  final String name;
  final String path;

  const FtpEntry({
    required this.name,
    required this.path,
  });

  bool get isDirectory;

  bool get isFile => !isDirectory;

  Future<bool> exists();

  Future<bool> create({bool recursive = false});

  Future<bool> delete({bool recursive = false});

  Future<bool> rename(String newName);

  Future<bool> copy(String newPath);

  Future<bool> move(String newPath);

  @override
  String toString() {
    return 'FtpEntry{name: $name, path: $path}';
  }
}
