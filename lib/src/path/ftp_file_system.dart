import 'package:pure_ftp/pure_ftp.dart';
import 'package:pure_ftp/src/ftp/extensions/ftp_command_extension.dart';
import 'package:pure_ftp/src/ftp/extensions/string_find_extension.dart';
import 'package:pure_ftp/src/path/ftp_directory.dart';

class FtpFileSystem {
  final _rootPath = '/';
  final FtpSocket _socket;
  late FtpDirectory _currentDirectory;
  final _fileSystemInfo = <String, dynamic>{};

  FtpFileSystem({
    required FtpSocket socket,
  }) : _socket = socket {
    _currentDirectory = FtpDirectory(
      path: _rootPath,
      fs: this,
    );
  }

  bool isRoot(FtpDirectory directory) => directory.path == _rootPath;

  FtpSocket get socket => _socket;

  FtpDirectory get currentDirectory => _currentDirectory;

  FtpDirectory get rootDirectory => FtpDirectory(
        path: _rootPath,
        fs: this,
      );

  Future<bool> changeDirectory(String path) async {
    final response = await FtpCommand.CWD.writeAndRead(_socket, [path]);
    if (response.isSuccessful) {
      _currentDirectory = FtpDirectory(
        path: path.startsWith(_rootPath) ? path : '$_rootPath$path',
        fs: this,
      );
      return true;
    }
    return false;
  }

  Future<String> _fetchCurrentDirectory() async {
    final response = await FtpCommand.PWD.writeAndRead(socket);
    if (response.isSuccessful) {
      final path = response.message.find('"', '"');
      return path;
    }
    throw Exception('Could not get current directory');
  }

  Future<bool> changeDirectoryUp() async {
    if (isRoot(_currentDirectory)) {
      return false;
    }
    final response = await FtpCommand.CDUP.writeAndRead(_socket);
    if (response.isSuccessful) {
      _currentDirectory = _currentDirectory.parent;
      return true;
    }
    return false;
  }

  Future<bool> changeDirectoryRoot() async {
    final response = await FtpCommand.CWD.writeAndRead(_socket, [_rootPath]);
    if (response.isSuccessful) {
      _currentDirectory = rootDirectory;
      return true;
    }
    return false;
  }
}
