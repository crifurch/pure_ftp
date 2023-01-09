// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:pure_ftp/pure_ftp.dart';
import 'package:pure_ftp/src/ftp/extensions/ftp_command_extension.dart';
import 'package:pure_ftp/src/ftp/utils/data_parser_utils.dart';
import 'package:pure_ftp/src/socket/common/client_raw_socket.dart';
import 'package:pure_ftp/src/socket/common/client_socket.dart';

typedef LogCallback = void Function(dynamic message);

class FtpSocket {
  final String _host;
  final int _port;
  final Duration _timeout;
  final void Function(dynamic message)? _log;
  final SecurityType _securityType;
  bool supportIPv6;
  FtpTransferMode transferMode;
  FtpTransferType _transferType;

  late ClientRawSocket _socket;

  FtpSocket({
    required String host,
    int? port,
    Duration timeout = const Duration(seconds: 30),
    LogCallback? log,
    FtpTransferMode transferMode = FtpTransferMode.passive,
    FtpTransferType transferType = FtpTransferType.auto,
    SecurityType securityType = SecurityType.FTP,
    bool supportIPv6 = false,
  })  : _host = host,
        _port = securityType == SecurityType.FTPS ? port ?? 990 : port ?? 21,
        _timeout = timeout,
        _log = log,
        transferMode = transferMode,
        _transferType = transferType,
        _securityType = securityType,
        supportIPv6 = supportIPv6;

  /// Connect to the FTP Server with given credentials
  ///
  /// and set the transfer mode
  Future<void> connect(String user, String pass, {String? account}) async {
    _log?.call(
        'Connecting to $_host:$_port with user:$user, pass:${'*' * pass.length}, account:$account');
    try {
      _socket = await ClientRawSocket.connect(
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
      try {
        _socket = await _socket.secureSocket(ignoreCertificateErrors: true);
      } on HandshakeException {
        if (!_securityType.isExplicit) {
          throw Exception('Check if the server supports implicit FTPS'
              ' and that port $_port is correct(990 for FTPS)');
        } else {
          rethrow;
        }
      }
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
    await FtpCommand.TYPE.writeAndRead(this, [_transferType.type]);
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
      await _socket.shutdown(ClientSocketDirection.readWrite);
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
      if (readMessage != null && readMessage.isNotEmpty) {
        res.write(String.fromCharCodes(readMessage).trim());
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

  FtpTransferType get transferType => _transferType;

  Future<void> setTransferType(FtpTransferType type) async {
    if (transferType == type) {
      return;
    }
    await FtpCommand.TYPE.writeAndRead(this, [type.type]);
    _transferType = type;
  }

  Future<void> openTransferChannel(
    FutureOr Function(FutureOr<ClientSocket> socket, LogCallback? log) doStuff,
  ) async {
    if (transferMode == FtpTransferMode.passive) {
      final passiveCommand = supportIPv6 ? FtpCommand.EPSV : FtpCommand.PASV;
      final ftpResponse = await passiveCommand.writeAndRead(this);
      if (!ftpResponse.isSuccessful) {
        throw Exception('Could not open transfer channel');
      }
      final port = DataParserUtils.parsePort(ftpResponse, isIPV6: supportIPv6);
      final ClientSocket dataSocket =
          await ClientSocket.connect(_host, port, timeout: _timeout);
      try {
        await doStuff(dataSocket, _log);
      } finally {
        await dataSocket.close(ClientSocketDirection.readWrite);
      }
      return;
    }
    //active mode
    final server = await ServerSocket.bind(InternetAddress.anyIPv4,
        transferMode.port ?? Random().nextInt(10000) + 10000);

    _log?.call('Listening on ${server.address.address}:${server.port}');

    final ftpResponse = await FtpCommand.PORT.writeAndRead(this, [
      [
        transferMode.host!.replaceAll('.', ','),
        ((server.port >> 8) & 0xFF).toString(),
        (server.port & 0xFF).toString()
      ].join(',')
    ]);
    if (!ftpResponse.isSuccessful) {
      await server.close();
      throw Exception('Could not open transfer channel');
    }
    try {
      // todo uncomment after abstraction on host socket
      //await doStuff(server.first.timeout(_timeout), _log);
    } finally {
      await server.close();
    }
  }
}

class FtpTransferMode {
  static const FtpTransferMode passive = FtpTransferMode._();
  final String? host;
  final int? port;

  /// Creates an active FtpTransferMode
  /// [host] is the host to connect from ftp server
  /// [port] is the port to use for the active mode
  /// if [port] is null a random port will be used
  ///
  /// if you want to use passive mode use [FtpTransferMode.passive]
  const FtpTransferMode.active({required this.host, this.port})
      : assert(port == null || port > 0);

  const FtpTransferMode._()
      : port = -1,
        host = null;
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
