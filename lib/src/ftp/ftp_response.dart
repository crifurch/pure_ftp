import 'package:meta/meta.dart';

@immutable
class FtpResponse {
  final int _code;
  final String _message;

  const FtpResponse({
    required int code,
    required String message,
  })  : _code = code,
        _message = message;

  int get code => _code;

  bool get isSuccessful => _code >= 200 && _code < 300;

  String get message => _message;

  @override
  String toString() {
    return 'FtpResponse{_code: $_code, _message: $_message}';
  }
}
