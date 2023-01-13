import 'dart:io';

import 'package:pure_ftp/pure_ftp.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_link.dart';
import 'package:pure_ftp/src/file_system/ftp_file_system.dart';
import 'package:pure_ftp/src/ftp/ftp_socket.dart';
import 'package:yaml/yaml.dart';

void main() async {
  var configFile = File('test_connection2.yml');
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
  await ftpSocket
      .connect(
    config['username'],
    config['password'],
    account: config['account'],
  )
      .then((value) {
    print('Connected');
  });

  final fs = FtpFileSystem(socket: ftpSocket);

  await fs.init();

  await fs.listDirectoryNames().then(print);

  await _getDirList(fs);

  try {
    fs.listType = ListType.MLSD;
    await _getDirList(fs);
  } catch (e) {
    // maybe server doesn't support MLSD
    print(e);
  }

  await ftpSocket.disconnect();
}

Future<void> _getDirList(FtpFileSystem fs) async {
  final list = await fs.listDirectory();
  list.forEach(print);
  for (final entry in list) {
    if (entry is FtpLink) {
      print('LinkTarget: ${entry.path} -> ${await entry.linkTarget}');
    }
  }
}
