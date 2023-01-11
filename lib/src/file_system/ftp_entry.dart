import 'package:meta/meta.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_directory.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_file.dart';
import 'package:pure_ftp/src/file_system/ftp_file_system.dart';
import 'package:pure_ftp/src/ftp/exceptions/ftp_exception.dart';

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
    throw FtpException('Cannot cast to $T');
  }

  @override
  String toString() {
    return 'FtpEntry{name: $name, path: $path}';
  }
}
