import 'package:pure_ftp/src/ftp/ftp_response.dart';

abstract class DataParserUtils {
  /// Parse the Passive Mode Port from the Servers [response]
  ///
  /// port format (|||xxxxx|) if [isIPV6] is true
  ///
  /// format 227 Entering Passive Mode (192,168,8,36,8,75) if [isIPV6] is false
  static int parsePort(
    FtpResponse response, {
    required bool isIPV6,
  }) {
    if (!response.isSuccessful) {
      throw Exception('Could not parse port from response: $response');
    }
    return isIPV6 ? _parsePortEPSV(response) : _parsePortPASV(response);
  }

  /// Parse the Passive Mode Port from the Servers [response]
  ///
  /// port format (|||xxxxx|)
  static int _parsePortEPSV(FtpResponse response) {
    final message = response.message;
    final iParOpen = message.indexOf('(');
    final iParClose = message.indexOf(')');

    if (iParClose > -1 && iParOpen > -1) {
      message.substring(iParOpen + 4, iParClose - 1);
    }
    return int.parse(message);
  }

  /// Parse the Passive Mode Port from the Servers [response]
  ///
  /// format 227 Entering Passive Mode (192,168,8,36,8,75).
  static int _parsePortPASV(FtpResponse response) {
    final message = response.message;
    final iParOpen = message.indexOf('(');
    final iParClose = message.indexOf(')');

    final sParameters = message.substring(iParOpen + 1, iParClose);
    final lstParameters = sParameters.split(',');

    final iPort1 = int.parse(lstParameters[lstParameters.length - 2]);
    final iPort2 = int.parse(lstParameters[lstParameters.length - 1]);

    return (iPort1 << 8) + iPort2;
  }
}
