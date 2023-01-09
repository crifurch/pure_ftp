import 'dart:io';

import 'package:pure_ftp/pure_ftp.dart';
import 'package:pure_ftp/src/ftp/ftp_socket.dart';
import 'package:yaml/yaml.dart';

void main() async {
  final config = loadYaml(await File('default_connection.yml').readAsString());
  final ftpSocket = FtpSocket(
    host: config['host'],
    port: config['port'],
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
