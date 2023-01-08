import 'package:pure_ftp/src/ftp/ftp_commands.dart';
import 'package:pure_ftp/src/ftp/ftp_response.dart';
import 'package:pure_ftp/src/ftp/ftp_socket.dart';

extension FtpCommandExtension on FtpCommand {
  void write(FtpSocket socket, [List<dynamic>? args]) {
    socket.write([
      name,
      ...?args?.map((e) => e.toString()),
    ].join(' '));
  }

  Future<FtpResponse> writeAndRead(FtpSocket socket, [List<dynamic>? args]) {
    write(socket, args);
    return socket.read();
  }
}
