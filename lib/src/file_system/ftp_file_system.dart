// ignore_for_file: constant_identifier_names

import 'package:pure_ftp/src/file_system/entries/ftp_directory.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_file.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_link.dart';
import 'package:pure_ftp/src/file_system/ftp_entry.dart';
import 'package:pure_ftp/src/ftp/extensions/ftp_command_extension.dart';
import 'package:pure_ftp/src/ftp/ftp_commands.dart';
import 'package:pure_ftp/src/ftp/ftp_socket.dart';
import 'package:pure_ftp/src/ftp/utils/data_parser_utils.dart';

class FtpFileSystem {
  final _rootPath = '/';
  final FtpSocket _socket;
  late FtpDirectory _currentDirectory;
  ListType listType = ListType.LIST;

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

  Future<bool> testDirectory(String path) async {
    final currentPath = _currentDirectory.path;
    bool testResult = false;
    try {
      testResult = await changeDirectory(path);
    } finally {
      await changeDirectory(currentPath);
    }
    return testResult;
  }

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
      listType.command.write(_socket, [dir.path]);
      //will be closed by the transfer channel
      // ignore: close_sinks
      final socket = await socketFuture;
      final response = await _socket.read();

      // wait 125 || 150 and >200 that indicates the end of the transfer
      final bool transferCompleted =
          response.isSuccessful || response.code == 125 || response.code == 150;
      if (!transferCompleted) {
        if (response.code == 500 && listType == ListType.MLSD) {
          throw Exception('MLSD command not supported by server');
        }
        throw Exception('Error while listing directory');
      }
      final List<int> data = [];
      await socket.listen(data.addAll).asFuture();
      final listData = String.fromCharCodes(data);
      log?.call(listData);
      final parseListDirResponse =
          DataParserUtils.parseListDirResponse(listData, listType, this);
      var mainPath = dir.path;
      if (mainPath.endsWith('/')) {
        mainPath = mainPath.substring(0, mainPath.length - 1);
      }
      final remappedEntries = parseListDirResponse.map((e, v) {
        if (e is FtpDirectory) {
          return MapEntry(e.copyWith('${mainPath}/${e.name}'), v);
        } else if (e is FtpFile) {
          return MapEntry(e.copyWith('${mainPath}/${e.name}'), v);
        } else if (e is FtpLink) {
          return MapEntry(
              e.copyWith(
                '${mainPath}/${e.name}',
                e.linkTargetPath,
              ),
              v);
        } else {
          throw Exception('Unknown type');
        }
      });
      result.addAll(remappedEntries.keys);
    });
    return result;
  }
}

enum ListType {
  LIST(FtpCommand.LIST),
  MLSD(FtpCommand.MLSD),
  ;

  final FtpCommand command;

  const ListType(this.command);
}