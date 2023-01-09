import 'package:meta/meta.dart';
import 'package:pure_ftp/pure_ftp.dart';
import 'package:pure_ftp/src/path/ftp_directory.dart';

@immutable
abstract class FtpEntry {
  final String path;
  @protected
  final FtpSocket socket;

  const FtpEntry({
    required this.path,
    required this.socket,
  });

  FtpDirectory get parent => FtpDirectory(
      path: path.split('/').sublist(0, path.split('/').length - 1).join('/'),
      socket: socket);

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
}
