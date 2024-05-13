import 'dart:async';
import 'dart:convert';

import 'package:pure_ftp/src/file_system/entries/ftp_directory.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_entry.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_file.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_link.dart';
import 'package:pure_ftp/src/file_system/ftp_entry_info.dart';
import 'package:pure_ftp/src/file_system/ftp_transfer.dart';
import 'package:pure_ftp/src/ftp/exceptions/ftp_exception.dart';
import 'package:pure_ftp/src/ftp/extensions/ftp_command_extension.dart';
import 'package:pure_ftp/src/ftp/extensions/string_find_extension.dart';
import 'package:pure_ftp/src/ftp/ftp_commands.dart';
import 'package:pure_ftp/src/ftp/utils/data_parser_utils.dart';
import 'package:pure_ftp/src/main/ftp_client.dart';
import 'package:pure_ftp/utils/list_utils.dart';

export 'package:pure_ftp/src/file_system/ftp_transfer.dart'
    show OnTransferProgress;

typedef DirInfoCache = MapEntry<String, Iterable<FtpEntry>>;

class FtpFileSystem {
  var _rootPath = '/';
  final FtpClient _client;
  late final FtpTransfer _transfer;
  late FtpDirectory _currentDirectory;
  ListType listType = ListType.LIST;
  final List<DirInfoCache> _dirInfoCache = [];

  FtpFileSystem({
    required FtpClient client,
  }) : _client = client {
    _currentDirectory = rootDirectory;
    _transfer = FtpTransfer(socket: _client.socket);
  }

  Future<void> init() async {
    final response = await FtpCommand.PWD.writeAndRead(_client.socket);
    if (response.isSuccessful) {
      final path = response.message.find('"', '"');
      _currentDirectory = FtpDirectory(
        path: path,
        client: _client,
      );
      _rootPath = path;
    }
  }

  bool isRoot(FtpDirectory directory) => directory.path == _rootPath;

  FtpDirectory get currentDirectory => _currentDirectory;

  FtpDirectory get rootDirectory => FtpDirectory(
        path: _rootPath,
        client: _client,
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
    if (path == '..') {
      return await changeDirectoryUp();
    }
    final response = await FtpCommand.CWD.writeAndRead(_client.socket, [path]);
    if (response.isSuccessful) {
      _currentDirectory = FtpDirectory(
        path: path.startsWith(_rootPath) ? path : '$_rootPath$path',
        client: _client,
      );
      return true;
    }
    return false;
  }

  Future<bool> changeDirectoryUp() async {
    if (isRoot(_currentDirectory)) {
      return false;
    }
    final response = await FtpCommand.CDUP.writeAndRead(_client.socket);
    if (response.isSuccessful) {
      _currentDirectory = _currentDirectory.parent;
      return true;
    }
    return false;
  }

  Future<bool> changeDirectoryRoot() async {
    final response =
        await FtpCommand.CWD.writeAndRead(_client.socket, [_rootPath]);
    if (response.isSuccessful) {
      _currentDirectory = rootDirectory;
      return true;
    }
    return false;
  }

  Future<bool> changeDirectoryHome() async {
    final response = await FtpCommand.CWD.writeAndRead(_client.socket, ['~']);
    if (response.isSuccessful) {
      _currentDirectory = rootDirectory;
      return true;
    }
    return false;
  }

  Future<List<FtpEntry>> listDirectory({
    FtpDirectory? directory,
    ListType? override,
  }) async {
    final listType = override ?? this.listType;
    final dir = directory ?? _currentDirectory;
    final result = await _client.socket
        .openTransferChannel<List<FtpEntry>>((socketFuture, log) async {
      listType.command.write(_client.socket, [dir.path]);
      //will be closed by the transfer channel
      // ignore: close_sinks
      final socket = await socketFuture;
      final response = await _client.socket.read();

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
      final listData = utf8.decode(data, allowMalformed: true);
      log?.call(listData);
      final parseListDirResponse =
          DataParserUtils.parseListDirResponse(listData, listType, dir);
      var mainPath = dir.path;
      if (mainPath.endsWith('/')) {
        mainPath = mainPath.substring(0, mainPath.length - 1);
      }
      final remappedEntries = parseListDirResponse.map((e) {
        if (e is FtpDirectory) {
          return e.copyWith(path: '${mainPath}/${e.name}');
        } else if (e is FtpFile) {
          return e.copyWith(path: '${mainPath}/${e.name}');
        } else if (e is FtpLink) {
          return e.copyWith(
            path: '${mainPath}/${e.name}',
          );
        } else {
          throw FtpException('Unknown type');
        }
      });
      _dirInfoCache.add(MapEntry(mainPath, remappedEntries.whereType()));
      return remappedEntries.whereType().toList();
    });
    return result;
  }

  Future<List<String>> listDirectoryNames([FtpDirectory? directory]) =>
      _client.socket
          .openTransferChannel<List<String>>((socketFuture, log) async {
        FtpCommand.NLST.write(
          _client.socket,
          [directory?.path ?? _currentDirectory.path],
        );
        //will be closed by the transfer channel
        // ignore: close_sinks
        final socket = await socketFuture;
        final response = await _client.socket.read();

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

  Stream<List<int>> downloadFileStream(
    FtpFile file, {
    OnTransferProgress? onReceiveProgress,
  }) =>
      _transfer.downloadFileStream(
        file,
        onReceiveProgress: onReceiveProgress,
      );

  Future<List<int>> downloadFile(
    FtpFile file, {
    OnTransferProgress? onReceiveProgress,
  }) async {
    final result = <int>[];
    await downloadFileStream(
      file,
      onReceiveProgress: onReceiveProgress,
    ).listen(result.addAll).asFuture();
    return result;
  }

  Future<bool> uploadFile(
    FtpFile file,
    List<int> data, {
    UploadChunkSize chunkSize = UploadChunkSize.kb4,
    OnTransferProgress? onUploadProgress,
  }) async {
    final stream = StreamController<List<int>>();
    var result = false;
    try {
      final future = uploadFileFromStream(
        file,
        stream.stream,
        data.length,
        onUploadProgress: onUploadProgress,
      );
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
    FtpFile file,
    Stream<List<int>> stream,
    int fileSize, {
    OnTransferProgress? onUploadProgress,
  }) async {
    return _transfer.uploadFileStream(
      file,
      stream,
      fileSize,
      onUploadProgress: onUploadProgress,
    );
  }

  Future<FtpEntryInfo?> getEntryInfo(FtpEntry entry,
      {bool fromCache = true}) async {
    if (entry.info != null) {
      return entry.info;
    }
    assert(
        entry.path != rootDirectory.path, 'Cannot get info for root directory');
    if (fromCache) {
      final cached =
          _dirInfoCache.firstWhereOrNull((e) => e.key == entry.parent.path);
      if (cached != null) {
        return cached.value.firstWhereOrNull((e) => e.name == entry.name)!.info;
      }
    }
    //todo: finish it
    // final dir = entry.parent;
    // final entries = await listDirectory(directory: dir);
    throw UnimplementedError();
  }

  FtpFileSystem copy() {
    final ftpFileSystem = FtpFileSystem(client: _client.clone());
    ftpFileSystem._currentDirectory = _currentDirectory;
    ftpFileSystem._rootPath = _rootPath;
    ftpFileSystem.listType = listType;
    return ftpFileSystem;
  }

  void clearCache() {
    _dirInfoCache.clear();
  }
}

enum ListType {
  // ignore: constant_identifier_names
  LIST(FtpCommand.LIST),
  // ignore: constant_identifier_names
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
