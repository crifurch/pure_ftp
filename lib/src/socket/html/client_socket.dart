import 'dart:async';
import 'dart:typed_data';

import 'package:pure_ftp/src/socket/common/client_socket.dart';

class ClientSocketImpl extends ClientSocket {
  Future<void> connect(String host, int port, {Duration? timeout}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> close(ClientSocketDirection how) {
    // TODO: implement close
    throw UnimplementedError();
  }

  @override
  void write(
    List<int> data, [
    int offset = 0,
    int? count,
  ]) {
    // TODO: implement write
  }

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // TODO: implement listen
    throw UnimplementedError();
  }
}
