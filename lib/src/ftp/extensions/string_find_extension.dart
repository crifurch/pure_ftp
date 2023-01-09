extension StringFindExtension on String {
  String find(String start, String end) {
    final startIndex = indexOf(start);
    final endIndex = lastIndexOf(end);
    return substring(startIndex + start.length, endIndex);
  }
}
