import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class UserProfileScreen extends StatelessWidget {
  final String userName;
  final String userEmail;
  final bool isVerified;

  const UserProfileScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.isVerified = false,
  });

  // Dummy reviews
  List<Map<String, dynamic>> get _dummyReviews => [
    {'name': 'Priya S', 'rating': 5.0, 'comment': 'Excellent driver! Very punctual and safe.', 'tags': ['⏰ Punctual', '🚗 Safe Driver'], 'date': '15 May 2026'},
    {'name': 'Ravi K', 'rating': 4.0, 'comment': 'Good ride, clean vehicle and friendly.', 'tags': ['🧹 Clean Vehicle', '😊 Friendly'], 'date': '10 May 2026'},
    {'name': 'Meena R', 'rating': 5.0, 'comment': 'Best ride sharing experience!', 'tags': ['🗺️ Knows Route', '💬 Good Communicator'], 'date': '02 May 2026'},
    {'name': 'Kumar A', 'rating': 3.0, 'comment': 'Decent ride, slightly late.', 'tags': ['⏳ Late'], 'date': '25 Apr 2026'},
  ];

  double get _avgRating => _dummyReviews.fold(0.0, (sum, r) => sum + (r['rating'] as double)) / _dummyReviews.length;

  Map<int, int> get _ratingDistribution {
    final dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _dummyReviews) {
      final rating = (r['rating'] as double).round();
      dist[rating] = (dist[rating] ?? 0) + 1;
    }
    return dist;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        title: const Text('User Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(children: [

          // Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(children: [
              Stack(children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(userName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                if (isVerified)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.verified_rounded, color: Color(0xFF1A73E8), size: 20),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                ],
              ]),
              Text(userEmail, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),

              // Rating Summary
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_avgRating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: List.generate(5, (i) => Icon(
                        i < _avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFF59E0B), size: 20))),
                    Text('${_dummyReviews.length} reviews',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ]),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Rating Distribution
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rating Breakdown', style: TextStyle(fontWeight: FontWeight.bold, color: tp, fontSize: 15)),
                  const SizedBox(height: 12),
                  ...List.generate(5, (i) {
                    final star = 5 - i;
                    final count = _ratingDistribution[star] ?? 0;
                    final pct = _dummyReviews.isEmpty ? 0.0 : count / _dummyReviews.length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Text('$star', style: TextStyle(color: ts, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                              valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$count', style: TextStyle(color: ts, fontSize: 12)),
                      ]),
                    );
                  }),
                ]),
              ),

              const SizedBox(height: 16),

              // Reviews List
              Text('Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
              const SizedBox(height: 12),

              ..._dummyReviews.map((review) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                      child: Text((review['name'] as String)[0],
                          style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(review['name'] as String,
                          style: TextStyle(fontWeight: FontWeight.w600, color: tp, fontSize: 13)),
                      Text(review['date'] as String, style: TextStyle(fontSize: 11, color: ts)),
                    ])),
                    Row(children: List.generate(5, (i) => Icon(
                        i < (review['rating'] as double).round() ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFF59E0B), size: 16))),
                  ]),
                  if ((review['comment'] as String).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(review['comment'] as String, style: TextStyle(color: tp, fontSize: 13, height: 1.4)),
                  ],
                  if ((review['tags'] as List).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 4,
                      children: (review['tags'] as List<String>).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(tag, style: const TextStyle(fontSize: 10, color: Color(0xFF1A73E8))),
                      )).toList(),
                    ),
                  ],
                ]),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}
