import 'package:pure_ftp/src/extensions/ftp_directory_extensions.dart';
import 'package:pure_ftp/src/ftp/extensions/ftp_command_extension.dart';
import 'package:pure_ftp/src/ftp/ftp_commands.dart';
import 'package:pure_ftp/src/path/ftp_entry.dart';
import 'package:pure_ftp/src/path/ftp_file_system.dart';

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
        throw Exception('Parent directory does not exist');
      }
    }
    // TODO: implement create
    throw UnimplementedError();
  }

  @override
  Future<bool> delete({bool recursive = false}) async {
    final response = await FtpCommand.DELE.writeAndRead(_fs.socket, [path]);
    return response.isSuccessful;
  }

  @override
  Future<bool> exists() {
    // TODO: implement exists
    throw UnimplementedError();
  }

  @override
  // TODO: implement isDirectory
  bool get isDirectory => throw UnimplementedError();

  @override
  Future<FtpEntry> move(String newPath) async {
    final newFile = newPath.startsWith(_fs.rootDirectory.path)
        ? FtpFile(path: newPath, fs: _fs)
        : parent.getChildFile(newPath);
    if (newFile.path == path) {
      return this;
    }
    if (!await newFile.parent.exists()) {
      throw Exception('Parent directory of new file does not exist');
    }

    // TODO: implement move
    throw UnimplementedError();
  }

  @override
  Future<FtpEntry> rename(String newName) => move(newName);
}
