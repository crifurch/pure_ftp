// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:pure_ftp/src/file_system/entries/ftp_directory.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_file.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_link.dart';
import 'package:pure_ftp/src/file_system/ftp_entry.dart';
import 'package:pure_ftp/src/file_system/ftp_transfer.dart';
import 'package:pure_ftp/src/ftp/exceptions/ftp_exception.dart';
import 'package:pure_ftp/src/ftp/extensions/ftp_command_extension.dart';
import 'package:pure_ftp/src/ftp/extensions/string_find_extension.dart';
import 'package:pure_ftp/src/ftp/ftp_commands.dart';
import 'package:pure_ftp/src/ftp/ftp_socket.dart';
import 'package:pure_ftp/src/ftp/utils/data_parser_utils.dart';

class FtpFileSystem {
  final _rootPath = '/';
  final FtpSocket _socket;
  late final FtpTransfer _transfer;
  late FtpDirectory _currentDirectory;
  ListType listType = ListType.LIST;

  FtpFileSystem({
    required FtpSocket socket,
  }) : _socket = socket {
    _currentDirectory = rootDirectory;
    _transfer = FtpTransfer(socket: _socket);
  }

  Future<void> init() async {
    final response = await FtpCommand.PWD.writeAndRead(_socket);
    if (response.isSuccessful) {
      final path = response.message.find('"', '"');
      _currentDirectory = FtpDirectory(
        path: path,
        fs: this,
      );
    }
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
      if (testResult) {
        await changeDirectory(currentPath);
      }
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
    final result = await _socket
        .openTransferChannel<List<FtpEntry>>((socketFuture, log) async {
      listType.command.write(_socket, [dir.path]);
      //will be closed by the transfer channel
      // ignore: close_sinks
      final socket = await socketFuture;
      final response = await _socket.read();

      // wait 125 || 150 and >200 that indicates the end of the transfer
      final bool transferCompleted = response.isSuccessfulForDataTransfer;
      if (!transferCompleted) {
        if (response.code == 500 && listType == ListType.MLSD) {
          throw FtpException('MLSD command not supported by server');
        }
        throw FtpException('Error while listing directory');
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
          throw FtpException('Unknown type');
        }
      });
      return remappedEntries.keys.toList();
    });
    return result;
  }

  Future<List<String>> listDirectoryNames([FtpDirectory? directory]) =>
      _socket.openTransferChannel<List<String>>((socketFuture, log) async {
        FtpCommand.NLST.write(
          _socket,
          [directory?.path ?? _currentDirectory.path],
        );
        //will be closed by the transfer channel
        // ignore: close_sinks
        final socket = await socketFuture;
        final response = await _socket.read();

        // wait 125 || 150 and >200 that indicates the end of the transfer
        final bool transferCompleted = response.isSuccessfulForDataTransfer;
        if (!transferCompleted) {
          throw FtpException('Error while listing directory names');
        }
        final List<int> data = [];
        await socket.listen(data.addAll).asFuture();
        final listData = String.fromCharCodes(data);
        log?.call(listData);
        return listData
            .split('\n')
            .map((e) => e.trim())
            .where((element) => element.isNotEmpty)
            .toList();
      });

  Stream<List<int>> downloadFileStream(FtpFile file) =>
      _transfer.downloadFileStream(file);

  Future<List<int>> downloadFile(FtpFile file) async {
    final result = <int>[];
    await downloadFileStream(file).listen(result.addAll).asFuture();
    return result;
  }

  Future<bool> uploadFile(FtpFile file, List<int> data,
      [UploadChunkSize chunkSize = UploadChunkSize.kb4]) async {
    final stream = StreamController<List<int>>();
    var result = false;
    try {
      final future = uploadFileFromStream(file, stream.stream);
      if (data.isEmpty) {
        stream.add(data);
      } else {
        for (var i = 0; i < data.length; i += chunkSize.value) {
          final end = i + chunkSize.value;
          final chunk = data.sublist(i, end > data.length ? data.length : end);
          stream.add(chunk);
        }
      }
      await stream.close();
      result = await future;
    } finally {
      await stream.close();
    }
    return result;
  }

  Future<bool> uploadFileFromStream(
      FtpFile file, Stream<List<int>> stream) async {
    return _transfer.uploadFileStream(file, stream);
  }
}

enum ListType {
  LIST(FtpCommand.LIST),
  MLSD(FtpCommand.MLSD),
  ;

  final FtpCommand command;

  const ListType(this.command);
}

enum UploadChunkSize {
  kb1(1024),
  kb2(2048),
  kb4(4096),
  mb1(1024 * 1024),
  mb2(2 * 1024 * 1024),
  mb4(4 * 1024 * 1024),
  ;

  final int value;

  const UploadChunkSize(this.value);

  @override
  String toString() => 'UploadChunkSize(${value}b)';
}
