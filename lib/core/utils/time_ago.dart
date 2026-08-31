// Small shared helper: formats a real DateTime (from Firestore) as a
// relative "x ago" string. Used across the Admin Panel so every screen
// renders live timestamps the same way instead of each re-implementing it.
String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 30) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} mo ago';
  return '${(diff.inDays / 365).floor()} yr ago';
}