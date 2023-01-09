import 'package:pure_ftp/pure_ftp.dart';
import 'package:pure_ftp/src/ftp/extensions/ftp_command_extension.dart';
import 'package:pure_ftp/src/path/ftp_entry.dart';
import 'package:pure_ftp/src/path/ftp_file_system.dart';

class FtpDirectory extends FtpEntry {
  final FtpFileSystem _fs;

  const FtpDirectory({
    required super.path,
    required super.fs,
  }) : _fs = fs;

  @override
  FtpDirectory get parent {
    if (isRoot) {
      throw Exception('Root directory has no parent');
    }
    return super.parent;
  }

  @override
  bool get isDirectory => true;

  bool get isRoot => _fs.isRoot(this);

  @override
  String get path => super.path.isEmpty ? '/' : super.path;

  @override
  Future<bool> exists() async {
    final response = await FtpCommand.CWD.writeAndRead(_fs.socket, [path]);
    await FtpCommand.CWD.writeAndRead(_fs.socket, [_fs.currentDirectory]);
    return response.isSuccessful;
  }

  @override
  Future<bool> create({bool recursive = false}) async {
    final response = await FtpCommand.MKD.writeAndRead(_fs.socket, [path]);
    return response.isSuccessful || response.code == 550;
  }

  @override
  Future<bool> delete({bool recursive = false}) async {
    if (!await exists()) {
      return true;
    }
    final response = await FtpCommand.RMD.writeAndRead(_fs.socket, [path]);
    //todo remove recursive if is not empty
    return response.isSuccessful;
  }

  @override
  Future<FtpDirectory> rename(String newName) async {
    if (isRoot) {
      throw Exception('Cannot rename root directory');
    }
    if (newName.contains('/')) {
      throw Exception('New name cannot contain path separator');
    }
    if (!await exists()) {
      throw Exception('Directory does not exist');
    }
    var response = await FtpCommand.RNFR.writeAndRead(_fs.socket, [path]);
    if (response.code != 350) {
      throw Exception('Could not rename directory');
    }

    var newPath = '${parent.path}/$newName';
    //todo search another way
    if (newPath.startsWith('//')) {
      newPath = newPath.substring(1);
    }
    response = await FtpCommand.RNTO.writeAndRead(_fs.socket, [
      newPath,
    ]);
    if (!response.isSuccessful) {
      throw Exception('Could not rename directory');
    }
    return FtpDirectory(path: newPath, fs: _fs);
  }

  @override
  Future<bool> copy(String newPath) async {
    if (!await exists()) {
      return false;
    }
    //todo implements copy
    return false;
  }

  @override
  Future<FtpDirectory> move(String newPath) async {
    if (!await exists()) {
      throw Exception('Directory does not exist');
    }
    if (newPath == path) {
      return this;
    }
    if (!newPath.startsWith('/')) {
      throw Exception(
          'New path must be absolute, to rename use rename(new name)');
    }
    final newDirectory = FtpDirectory(path: newPath, fs: _fs).parent;
    if (!await newDirectory.exists()) {
      throw Exception('directory does not exist: ${newDirectory.path}');
    }
    var response = await FtpCommand.RNFR.writeAndRead(_fs.socket, [path]);
    if (response.code != 350) {
      throw Exception('Could not move directory');
    }
    response = await FtpCommand.RNTO.writeAndRead(_fs.socket, [
      newPath,
    ]);
    if (!response.isSuccessful) {
      throw Exception('Could not move directory');
    }
    return FtpDirectory(path: newPath, fs: _fs);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is FtpDirectory && other.path == path && other._fs == _fs;
  }

  @override
  int get hashCode => path.hashCode ^ _fs.hashCode;

  FtpDirectory copyWith(String path) {
    return FtpDirectory(
      path: path,
      fs: _fs,
    );
  }
}
