import 'dart:async';
import 'dart:typed_data';

import 'package:pure_ftp/src/file_system/entries/ftp_file.dart';
import 'package:pure_ftp/src/file_system/ftp_file_system.dart';
import 'package:pure_ftp/src/ftp/exceptions/ftp_exception.dart';
import 'package:pure_ftp/src/ftp/extensions/ftp_command_extension.dart';
import 'package:pure_ftp/src/ftp/ftp_commands.dart';
import 'package:pure_ftp/src/ftp/ftp_socket.dart';
import 'package:pure_ftp/src/socket/common/client_raw_socket.dart';

class FtpTransfer {
  final FtpSocket _socket;

  FtpTransfer({
    required FtpSocket socket,
  }) : _socket = socket;

  Stream<List<int>> downloadFileStream(FtpFile file) {
    final stream = StreamController<List<int>>();
    unawaited(_socket.openTransferChannel((socketFuture, log) async {
      FtpCommand.RETR.write(
        _socket,
        [file.path],
      );
      //will be closed by the transfer channel
      // ignore: close_sinks
      final socket = await socketFuture;
      final response = await _socket.read();

      // wait 125 || 150 and >200 that indicates the end of the transfer
      final bool transferCompleted = response.isSuccessfulForDataTransfer;
      if (!transferCompleted) {
        throw FtpException('Error while downloading file');
      }
      var total = 0;
      await socket.listen(
        (event) {
          stream.add(event);
          log?.call('Downloaded ${total += event.length} bytes');
        },
      ).asFuture();
      await _socket.read();
      await stream.close();
    }, (error, stackTrace) {
      stream.addError(error, stackTrace);
      stream.close();
    }));
    return stream.stream;
  }

  Future<bool> uploadFileStream(FtpFile file, Stream<List<int>> data,
          {OnSendProgress? onSendProgress}) =>
      _socket.openTransferChannel((socketFuture, log) async {
        FtpCommand.STOR.write(
          _socket,
          [file.path],
        );
        //will be closed by the transfer channel
        // ignore: close_sinks
        final socket = await socketFuture;
        final response = await _socket.read();

        // wait 125 || 150 and >200 that indicates the end of the transfer
        final bool transferCompleted = response.isSuccessfulForDataTransfer;
        if (!transferCompleted) {
          throw FtpException('Error while uploading file');
        }
        var total = 0;
        final transform = data.transform<Uint8List>(
          StreamTransformer.fromHandlers(
            handleData: (event, sink) {
              sink.add(Uint8List.fromList(event));
              total += event.length;
              onSendProgress?.call(total);
              log?.call('Uploaded ${total} bytes');
            },
          ),
        );
        await socket.addSteam(transform);
        await socket.flush;
        await socket.close(ClientSocketDirection.readWrite);
        final response2 = await _socket.read();
        return response2.isSuccessful;
      });
}
