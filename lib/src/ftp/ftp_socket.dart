// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:io';

import 'package:pure_ftp/src/ftp/extensions/ftp_command_extension.dart';
import 'package:pure_ftp/src/ftp/ftp_commands.dart';
import 'package:pure_ftp/src/ftp/ftp_response.dart';

typedef LogCallback = void Function(dynamic message);

class FtpSocket {
  final String _host;
  final int _port;
  final Duration _timeout;
  final void Function(dynamic message)? _log;
  final SecurityType _securityType;
  final bool _supportIPv6;
  FtpMode _mode;
  FtpTransferType _type;

  late RawSocket _socket;

  FtpSocket({
    required String host,
    int port = 21,
    Duration timeout = const Duration(seconds: 30),
    LogCallback? log,
    FtpMode mode = FtpMode.passive,
    FtpTransferType type = FtpTransferType.auto,
    SecurityType securityType = SecurityType.FTP,
    bool supportIPv6 = false,
  })  : _host = host,
        _port = port,
        _timeout = timeout,
        _log = log,
        _mode = mode,
        _type = type,
        _securityType = securityType,
        _supportIPv6 = supportIPv6;

  /// Connect to the FTP Server with given credentials
  ///
  /// and set the transfer mode
  Future<void> connect(String user, String pass, {String? account}) async {
    _log?.call(
        'Connecting to $_host:$_port with user:$user, pass:${'*' * pass.length}, account:$account');
    try {
      _socket = await RawSocket.connect(
        _host,
        _port,
        timeout: _timeout,
      );
    } catch (e) {
      throw Exception('Could not connect to $_host ($_port):\n$e');
    }
    _log?.call('Connected to $_host:$_port');
    // flush welcome message
    await read();

    // setup secure connection
    if (_securityType.isSecure) {
      if (_securityType.isExplicit) {
        if (!(await FtpCommand.AUTH.writeAndRead(this, ['TLS'])).isSuccessful) {
          if (!(await FtpCommand.AUTH.writeAndRead(this, ['SSL']))
              .isSuccessful) {
            throw Exception(
                'FTPES cannot be applied: the server refused both AUTH TLS and AUTH SSL commands');
          }
        }
      }

      _socket = await RawSecureSocket.secure(
        _socket,
        onBadCertificate: (_) => true,
      );

      await FtpCommand.PBSZ.writeAndRead(this, ['0']);
      await FtpCommand.PROT.writeAndRead(this, ['P']);
    }

    var ftpResponse = await FtpCommand.USER.writeAndRead(this, [user]);
    final passwordRequired = ftpResponse.code == 331;
    if (passwordRequired) {
      ftpResponse = await FtpCommand.PASS.writeAndRead(this, [pass]);
    }
    if (ftpResponse.code == 332) {
      if (account == null) {
        throw Exception('Account required');
      }
      ftpResponse = await FtpCommand.ACCT.writeAndRead(this, [account]);
      if (!ftpResponse.isSuccessful) {
        throw Exception('Wrong Account');
      }
    }
    if (!passwordRequired && !ftpResponse.isSuccessful) {
      throw Exception('Wrong Username');
    }
    if (!ftpResponse.isSuccessful) {
      throw Exception('Wrong Username/password');
    }
    await FtpCommand.TYPE.writeAndRead(this, [_type.type]);
    _log?.call('Logged in');
  }

  /// Closes the connection
  ///
  /// if [safe] is true, the connection will be closed after the server has
  /// confirmed the close command(if the server supports it)
  Future<void> disconnect({bool safe = true}) async {
    _log?.call('Disconnecting from $_host:$_port');
    try {
      if (safe) {
        await writeAndRead(FtpCommand.QUIT.toString());
      }
    } catch (_) {
      // ignore
    } finally {
      await _socket.close();
      _socket.shutdown(SocketDirection.both);
      _log?.call('Disconnected from $_host:$_port');
    }
  }

  /// Fetch the response from the server
  ///
  /// FtpSocket.timeout is the time to wait for the response
  Future<FtpResponse> read() async {
    final res = StringBuffer();
    await Future.doWhile(() async {
      final readMessage = _socket.readMessage();
      if (readMessage != null && readMessage.data.isNotEmpty) {
        res.write(String.fromCharCodes(readMessage.data).trim());
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }).timeout(_timeout, onTimeout: () {
      throw Exception('Timeout reached for Receiving response!');
    });
    final result = res.toString().trimLeft();
    if (result.length < 3) {
      throw Exception('Illegal Reply Exception');
    }
    final lines = result.split('\n');

    if (lines.isNotEmpty && lines.last.length >= 4 && lines.last[3] == '-') {
      return await read();
    }

    var code = -1;
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (line.length >= 3) {
        code = int.tryParse(line.substring(0, 3)) ?? code;
        break;
      }
    }

    if (code == -1) {
      throw Exception('Illegal Reply Exception');
    }
    _log?.call('$_host:$_port< $result');
    return FtpResponse(code: code, message: result);
  }

  /// Send message to the server
  ///
  /// if [command] is true then the message will be sent as a command
  void write(String message, {bool command = true}) {
    _socket.write(utf8.encode('$message${command ? '\r\n' : ''}'));
    if (message.startsWith(FtpCommand.PASS.toString())) {
      _log?.call(
          '$_host:$_port> ${message.substring(0, 5)}${'*' * (message.length - 4)}');
    } else {
      _log?.call('$_host:$_port> $message');
    }
  }

  /// Send message to the server and fetch the response
  ///
  /// instead of [write] this method will call [read] after sending the message
  /// and send only commands
  Future<FtpResponse> writeAndRead(String message) {
    write(message, command: true);
    return read();
  }

  FtpTransferType get type => _type;

  Future<void> setTransferType(FtpTransferType type) async {
    if (_type == type) {
      return;
    }
    await FtpCommand.TYPE.writeAndRead(this, [type.type]);
    _type = type;
  }

// Future<Socket> openTransferChannel() async {
//   if (_mode == FtpMode.passive) {
//     FtpCommand command = _supportIPv6 ? FtpCommand.EPRT : FtpCommand.PASV;
//     final ftpResponse = await command.writeAndRead(this);
//     if (!ftpResponse.isSuccessful) {
//       throw Exception('Could not open transfer channel');
//     }
//     return _socket;
//   } else {
//     //todo check if this is correct
//     final ftpResponse = await FtpCommand.PORT.writeAndRead(this, [
//       _socket.address.address.replaceAll('.', ','),
//       ((_socket.port >> 8) & 0xFF).toString(),
//       (_socket.port & 0xFF).toString()
//     ]);
//     if (!ftpResponse.isSuccessful) {
//       throw Exception('Could not open transfer channel');
//     }
//   }
  // }
}

enum FtpMode {
  passive,
  ;

  final int? activePort;

  const FtpMode({this.activePort});
}

enum FtpTransferType {
  auto('A'),
  ascii('A'),
  binary('I'),
  ;

  final String type;

  const FtpTransferType(this.type);
}

enum SecurityType {
  FTP,
  FTPS,
  FTPES,
  ;

  bool get isSecure => this != SecurityType.FTP;

  bool get isExplicit => this == SecurityType.FTPES;
}
