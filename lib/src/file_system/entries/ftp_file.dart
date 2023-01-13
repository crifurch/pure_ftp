import 'package:pure_ftp/src/extensions/ftp_directory_extensions.dart';
import 'package:pure_ftp/src/file_system/ftp_entry.dart';
import 'package:pure_ftp/src/file_system/ftp_file_system.dart';
import 'package:pure_ftp/src/ftp/exceptions/ftp_exception.dart';
import 'package:pure_ftp/src/ftp/extensions/ftp_command_extension.dart';
import 'package:pure_ftp/src/ftp/ftp_commands.dart';

class FtpFile extends FtpEntry {
  final FtpFileSystem _fs;

  const FtpFile({
    required super.path,
    required super.fs,
  }) : _fs = fs;

  @override
  Future<bool> copy(String newPath) {
    // TODO: implement copy
    throw UnimplementedError();
  }

  @override
  Future<bool> create({bool recursive = false}) async {
    if (!await parent.exists()) {
      if (recursive) {
        await parent.create(recursive: true);
      } else {
        throw FtpException('Parent directory does not exist');
      }
    }
    return _fs.uploadFile(this, []);
  }

  @override
  Future<bool> delete({bool recursive = false}) async {
    final response = await FtpCommand.DELE.writeAndRead(_fs.socket, [path]);
    return response.isSuccessful;
  }

  @override
  Future<bool> exists() async {
    final response = await FtpCommand.SIZE.writeAndRead(_fs.socket, [path]);
    return response.isSuccessful;
  }

  @override
  // TODO: implement isDirectory
  bool get isDirectory => throw UnimplementedError();

  @override
  Future<FtpFile> move(String newPath) async {
    final newFile = newPath.startsWith(_fs.rootDirectory.path)
        ? FtpFile(path: newPath, fs: _fs)
        : parent.getChildFile(newPath);
    if (newFile.path == path) {
      return this;
    }
    if (!await newFile.parent.exists()) {
      throw FtpException('Parent directory of new file does not exist');
    }
    final response = await FtpCommand.RNFR.writeAndRead(_fs.socket, [path]);
    if (!response.isSuccessful) {
      throw FtpException('Cannot move file');
    }
    final response2 =
        await FtpCommand.RNTO.writeAndRead(_fs.socket, [newFile.path]);
    if (!response2.isSuccessful) {
      throw FtpException('Cannot move file');
    }
    return newFile;
  }

  @override
  Future<FtpFile> rename(String newName) async {
    if (newName.contains('/')) {
      throw FtpException('New name cannot contain path separator');
    }
    final newFile = parent.getChildFile(newName);
    if (newFile.path == path) {
      return this;
    }
    if (!await newFile.parent.exists()) {
      throw FtpException('Parent directory of new file does not exist');
    }
    final response = await FtpCommand.RNFR.writeAndRead(_fs.socket, [path]);
    if (!response.isSuccessful) {
      throw FtpException('Cannot rename file');
    }
    final response2 =
        await FtpCommand.RNTO.writeAndRead(_fs.socket, [newFile.path]);
    if (!response2.isSuccessful) {
      throw FtpException('Cannot rename file');
    }
    return newFile;
  }

  FtpFile copyWith(String path) {
    return FtpFile(
      path: path,
      fs: _fs,
    );
  }

  @override
  String toString() {
    return 'FtpFile(path: $path)';
  }
}
