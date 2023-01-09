import 'package:meta/meta.dart';
import 'package:pure_ftp/src/path/ftp_directory.dart';
import 'package:pure_ftp/src/path/ftp_file.dart';
import 'package:pure_ftp/src/path/ftp_file_system.dart';

@immutable
abstract class FtpEntry {
  final String path;
  @protected
  final FtpFileSystem _fs;

  const FtpEntry({
    required this.path,
    required FtpFileSystem fs,
  }) : _fs = fs;

  FtpDirectory get parent => FtpDirectory(
      path: path.split('/').sublist(0, path.split('/').length - 1).join('/'),
      fs: _fs);

  String get name => path.split('/').last;

  bool get isDirectory;

  bool get isFile => !isDirectory;

  Future<bool> exists();

  Future<bool> create({bool recursive = false});

  Future<bool> delete({bool recursive = false});

  Future<FtpEntry> rename(String newName);

  Future<bool> copy(String newPath);

  Future<FtpEntry> move(String newPath);

  @override
  String toString() {
    return 'FtpEntry{name: $name, path: $path}';
  }

  T as<T extends FtpEntry>() {
    if (T == FtpEntry) {
      return this as T;
    }
    if (T == FtpDirectory) {
      return this as T;
    }
    if (T == FtpFile) {
      return this as T;
    }
    throw Exception('Cannot cast to $T');
  }
}
