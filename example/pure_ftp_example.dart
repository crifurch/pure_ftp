import 'dart:io';

import 'package:pure_ftp/pure_ftp.dart';
import 'package:pure_ftp/src/ftp/ftp_socket.dart';
import 'package:yaml/yaml.dart';

void main() async {
  //you can default_connection.yml file in root folder
  final config = loadYaml(await File('test_connection.yml').readAsString());
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
}
