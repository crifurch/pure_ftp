import 'dart:io';

import 'package:pure_ftp/pure_ftp.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() async {
  final config = loadYaml(await File('default_connection.yml').readAsString());
  test('connection test', () async {
    final ftpSocket = FtpSocket(
      host: config['host'],
      port: config['port'] ?? 21,
      timeout: const Duration(seconds: 30),
      log: print,
    );
    await ftpSocket
        .connect(
      config['username'],
      config['password'],
      account: config['account'],
    )
        .then((value) {
      print('Connected');
    });
    await ftpSocket.disconnect();
  });
}
