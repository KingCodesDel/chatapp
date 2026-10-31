/// Cloudinary can serve a still frame of any uploaded video: swap the file
/// extension for .jpg (and ask for a small width). Free, no extra packages.
String videoThumbUrl(String videoUrl, {int width = 520}) {
  var url = videoUrl.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '.jpg');
  if (url.contains('/upload/')) {
    url = url.replaceFirst('/upload/', '/upload/so_0,w_$width,c_limit/');
  }
  return url;
}

String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}
