import 'package:pure_ftp/src/file_system/ftp_directory.dart';
import 'package:pure_ftp/src/file_system/ftp_file.dart';

extension FtpDirectoryGet on FtpDirectory {
  FtpDirectory getChildDir(String path) => copyWith(
        '${this.path}'
        '${this.path.endsWith('/') || path.startsWith('/') ? '' : '/'}'
        '$path',
      );

  FtpFile getChildFile(String path) => getChildDir(path).as();
}
