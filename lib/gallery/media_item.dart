class MediaItem {
  const MediaItem({
    required this.id,
    required this.createdAt,
    required this.isVideo,
  });
  final String id;
  final DateTime createdAt;
  final bool isVideo;
}
