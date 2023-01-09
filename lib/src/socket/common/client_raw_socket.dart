import 'dart:async';

import '../io/client_raw_socket.dart'
if (dart.html) '../io/client_raw_socket.dart';

abstract class ClientRawSocket {
  static Future<ClientRawSocket> connect(String host, int port,
      {Duration? timeout}) async {
    final result = ClientRawSocketImpl();
    await result.connect(host, port, timeout: timeout);
    return result;
  }

  Future<ClientRawSocket> secureSocket({bool ignoreCertificateErrors = false});

  List<int>? readMessage();

  void write(List<int> data, [
    int offset = 0,
    int? count,
  ]);

  Future<void> close();

  Future<void> shutdown(ClientSocketDirection how);
}

enum ClientSocketDirection {
  read,
  write,
  readWrite,
}
