import 'dart:io';

import 'package:pure_ftp/pure_ftp.dart';
import 'package:pure_ftp/src/path/ftp_directory.dart';
import 'package:pure_ftp/src/path/ftp_file_system.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() async {
  final config = loadYaml(await File('default_connection.yml').readAsString());
  final ftpSocket = FtpSocket(
    host: config['host'],
    port: config['port'] ?? 21,
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

  test('disconnect test', () async {
    await ftpSocket.disconnect();
  });
}
