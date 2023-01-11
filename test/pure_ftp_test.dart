import 'dart:io';

import 'package:pure_ftp/pure_ftp.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_directory.dart';
import 'package:pure_ftp/src/file_system/ftp_file_system.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() async {
  var configFile = File('test_connection.yml');
  if (!configFile.existsSync()) {
    configFile = File('default_connection.yml');
  }
  final config = loadYaml(await configFile.readAsString());
  final ftpSocket = FtpSocket(
    host: config['host'],
    port: config['port'],
    timeout: const Duration(seconds: 30),
    log: print,
  );
  final fs = FtpFileSystem(socket: ftpSocket);
  test('connection test', () async {
    await ftpSocket
        .connect(
      config['username'],
      config['password'],
      account: config['account'],
    )
        .then((value) {
      print('Connected');
    });
  });

  test('directory operations test', () async {
    var ftpDirectory = FtpDirectory(
      path: '/test',
      fs: fs,
    );
    var boolResponse = await ftpDirectory.create();
    expect(boolResponse, true);
    var dirResponse = await ftpDirectory.rename('test1');
    expect(dirResponse.path, '/test1');
    ftpDirectory = dirResponse;
    dirResponse = await ftpDirectory.move('/test2');
    expect(dirResponse.path, '/test2');
    boolResponse = await dirResponse.delete();
    expect(boolResponse, true);
  });

  test('file system test', () async {
    final result = await fs.listDirectory();
    result.forEach(print);
  });

  if (config['active_host'] != null)
    test('file system test in active mode', () async {
      ftpSocket.transferMode = FtpTransferMode.active(
        host: config['active_host'],
        port: int.tryParse(config['active_port'].toString()),
      );
      await fs.listDirectory();
    });

  ftpSocket.transferMode = FtpTransferMode.passive;

  test('disconnect test', () async {
    await ftpSocket.disconnect();
  });
}
