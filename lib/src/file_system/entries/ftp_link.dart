import 'package:pure_ftp/src/file_system/entries/ftp_directory.dart';
import 'package:pure_ftp/src/file_system/entries/ftp_file.dart';
import 'package:pure_ftp/src/file_system/ftp_entry.dart';
import 'package:pure_ftp/src/file_system/ftp_file_system.dart';

class FtpLink extends FtpEntry {
  final String _linkTarget;
  final FtpFileSystem _fs;

  const FtpLink({
    required String linkTarget,
    required super.path,
    required super.fs,
  })  : _linkTarget = linkTarget,
        _fs = fs;

  @override
  Future<bool> copy(String newPath) {
    //todo implement later
    throw UnsupportedError('Cannot copy a link');
  }

  @override
  Future<bool> create({bool recursive = false}) {
    //todo implement later
    throw UnsupportedError('Cannot create a link');
  }

  @override
  Future<bool> delete({bool recursive = false}) {
    //todo implement later
    throw UnsupportedError('Cannot delete a link');
  }

  @override
  Future<bool> exists() {
    //todo implement later
    throw UnsupportedError('Cannot check if a link exists');
  }

  @override
  bool get isDirectory => false;

  @override
  Future<FtpEntry> move(String newPath) {
    //todo implement later
    throw UnsupportedError('Cannot move a link');
  }

  @override
  Future<FtpEntry> rename(String newName) {
    //todo implement later
    throw UnsupportedError('Cannot rename a link');
  }

  String get linkTargetPath => _linkTarget;

  Future<FtpEntry> get linkTarget async {
    final isDir = await _fs.testDirectory(_linkTarget);
    if (isDir) {
      return FtpDirectory(path: _linkTarget, fs: _fs);
    } else {
      return FtpFile(path: _linkTarget, fs: _fs);
    }
  }

  FtpLink copyWith(String path, String linkTarget) {
    return FtpLink(
      path: path,
      linkTarget: linkTarget,
      fs: _fs,
    );
  }

  @override
  String toString() {
    return 'FtpLink{linkTarget: $_linkTarget, path: $path}';
  }
}
