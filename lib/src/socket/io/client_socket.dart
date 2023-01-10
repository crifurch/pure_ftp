import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:pure_ftp/src/socket/common/client_socket.dart';

class ClientSocketImpl extends ClientSocket {
  late Socket _socket;

  ClientSocketImpl();

  ClientSocketImpl.fromSocket(this._socket);

  Future<void> connect(String host, int port, {Duration? timeout}) async {
    _socket = await Socket.connect(host, port, timeout: timeout);
  }

  @override
  Future<void> close(ClientSocketDirection how) async {
    if (how == ClientSocketDirection.read ||
        how == ClientSocketDirection.readWrite) {
      return _socket.destroy();
    }
    if (how == ClientSocketDirection.write ||
        how == ClientSocketDirection.readWrite) {
      await _socket.flush();
      return _socket.close();
    }
  }

  @override
  void write(List<int> data, [int offset = 0, int? count]) {
    _socket.add(
      data.sublist(
        offset,
        offset + (count ?? data.length - offset),
      ),
    );
  }

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _socket.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
}
