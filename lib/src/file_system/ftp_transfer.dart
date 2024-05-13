import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:pure_ftp/src/file_system/entries/ftp_file.dart';
import 'package:pure_ftp/src/ftp/exceptions/ftp_exception.dart';
import 'package:pure_ftp/src/ftp/extensions/ftp_command_extension.dart';
import 'package:pure_ftp/src/ftp/ftp_commands.dart';
import 'package:pure_ftp/src/ftp/ftp_socket.dart';
import 'package:pure_ftp/src/socket/common/client_raw_socket.dart';

typedef OnTransferProgress = Function(int bytes, int total, double percents);

class FtpTransfer {
  final FtpSocket _socket;

  FtpTransfer({
    required FtpSocket socket,
  }) : _socket = socket;

  Stream<List<int>> downloadFileStream(
    FtpFile file, {
    OnTransferProgress? onReceiveProgress,
  }) {
    final stream = StreamController<List<int>>();
    unawaited(_socket.openTransferChannel((socketFuture, log) async {
      final fileSize = await file.size();
      FtpCommand.RETR.write(
        _socket,
        [file.path],
      );
      //will be closed by the transfer channel
      final socket = await socketFuture;
      final response = await _socket.read();

      // wait 125 || 150 and >200 that indicates the end of the transfer
      final bool transferCompleted = response.isSuccessfulForDataTransfer;
      if (!transferCompleted) {
        throw FtpException('Error while downloading file');
      }
      var downloaded = 0;
      await socket.listen(
        (event) {
          stream.add(event);
          downloaded += event.length;
          final total = max(fileSize, downloaded);
          onReceiveProgress?.call(downloaded, total, downloaded / total * 100);
          log?.call('Downloaded ${downloaded} of ${total} bytes');
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

  Future<bool> uploadFileStream(
    FtpFile file,
    Stream<List<int>> data,
    int fileSize, {
    OnTransferProgress? onUploadProgress,
  }) =>
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
        var uploaded = 0;
        final transform = data.transform<Uint8List>(
          StreamTransformer.fromHandlers(
            handleData: (event, sink) {
              sink.add(Uint8List.fromList(event));
              uploaded += event.length;
              final total = max(fileSize, uploaded);
              onUploadProgress?.call(uploaded, total, uploaded / total * 100);
              log?.call('Downloaded ${uploaded} of ${total} bytes');
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
