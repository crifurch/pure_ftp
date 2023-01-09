// ignore_for_file: constant_identifier_names

import 'package:pure_ftp/src/ftp/extensions/ftp_command_extension.dart';
import 'package:pure_ftp/src/ftp/ftp_commands.dart';
import 'package:pure_ftp/src/ftp/ftp_socket.dart';
import 'package:pure_ftp/src/path/ftp_directory.dart';
import 'package:pure_ftp/src/path/ftp_entry.dart';

class FtpFileSystem {
  final _rootPath = '/';
  final FtpSocket _socket;
  late FtpDirectory _currentDirectory;
  final _fileSystemInfo = <String, dynamic>{};
  ListCommand listCommand = ListCommand.LIST;

  FtpFileSystem({
    required FtpSocket socket,
  }) : _socket = socket {
    _currentDirectory = rootDirectory;
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

  Future<bool> changeDirectoryHome() async {
    final response = await FtpCommand.CWD.writeAndRead(_socket, ['~']);
    if (response.isSuccessful) {
      _currentDirectory = rootDirectory;
      return true;
    }
    return false;
  }

  Future<List<FtpEntry>> listDirectory([FtpDirectory? directory]) async {
    final dir = directory ?? _currentDirectory;
    final result = <FtpEntry>[];
    await _socket.openTransferChannel((socketFuture, log) async {
      listCommand.command.write(_socket, [dir.path]);
      //will be closed by the transfer channel
      // ignore: close_sinks
      final socket = await socketFuture;
      final response = await _socket.read();

      // wait 125 || 150 and >200 that indicates the end of the transfer
      final bool transferCompleted =
          response.isSuccessful || response.code == 125 || response.code == 150;
      if (!transferCompleted) {
        throw Exception('Error while listing directory');
      }
      final List<int> data = [];
      await socket.listen(data.addAll).asFuture();

      //todo parse response
      log?.call(String.fromCharCodes(data));
    });
    return result;
  }
}

enum ListCommand {
  LIST(FtpCommand.LIST),
  MLSD(FtpCommand.MLSD),
  ;

  final FtpCommand command;

  const ListCommand(this.command);
}
