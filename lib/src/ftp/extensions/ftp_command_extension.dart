import 'package:pure_ftp/src/ftp/ftp_commands.dart';
import 'package:pure_ftp/src/ftp/ftp_response.dart';
import 'package:pure_ftp/src/ftp/ftp_socket.dart';

extension FtpCommandExtension on FtpCommand {
  void write(FtpSocket socket, [List<String>? args]) {
    socket.write([
      name,
      ...?args?.map((e) => e.toString()),
    ].join(' '));
  }

  Future<FtpResponse> writeAndRead(FtpSocket socket, [List<String>? args]) {
    write(socket, args);
    return socket.read();
  }
}
