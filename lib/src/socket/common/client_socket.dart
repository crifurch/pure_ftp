import 'dart:async';
import 'dart:typed_data';

import 'package:pure_ftp/src/socket/common/client_socket_direction.dart';
import 'package:pure_ftp/src/socket/io/client_socket.dart'
    if (dart.html) 'package:pure_ftp/src/socket/html/client_socket.dart';

export 'package:pure_ftp/src/socket/common/client_socket_direction.dart';

abstract class ClientSocket {
  static Future<ClientSocket> connect(String host, int port,
      {Duration? timeout}) async {
    final result = ClientSocketImpl();
    await result.connect(host, port, timeout: timeout);
    return result;
  }

  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  });

  void write(
    List<int> data, [
    int offset = 0,
    int? count,
  ]);

  Future<void> close(ClientSocketDirection how);
}
