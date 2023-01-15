import 'package:meta/meta.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_directory.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_file.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_link.dart';
import 'package:pure_ftp/src/file_system/ftp_file_system.dart';

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

  bool get isAbsolute => path.startsWith('/');

  bool get isDirectory;

  bool get isFile => !isDirectory;

  Future<bool> exists();

  Future<bool> create({bool recursive = false});

  Future<bool> delete({bool recursive = false});

  Future<FtpEntry> rename(String newName);

  Future<bool> copy(String newPath);

  Future<FtpEntry> move(String newPath);

  T as<T extends FtpEntry>() {
    switch (T) {
      case FtpDirectory:
        return FtpDirectory(path: path, fs: _fs) as T;
      case FtpFile:
        return FtpFile(path: path, fs: _fs) as T;
      case FtpLink:
        return FtpLink(
          path: path,
          fs: _fs,
          linkTarget: '__unknown__${path.hashCode ^ _fs.hashCode}',
        ) as T;
      default:
        throw UnsupportedError('Cannot cast to $T');
    }
  }

  @override
  String toString() {
    return 'FtpEntry{name: $name, path: $path}';
  }
}
