import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/trip_model.dart';
import '../../utils/app_icon_colors.dart';

class RatingReviewScreen extends StatefulWidget {
  final TripModel trip;
  final String revieweeEmail;
  final String revieweeName;

  const RatingReviewScreen({super.key, required this.trip, required this.revieweeEmail, required this.revieweeName});
  @override
  State<RatingReviewScreen> createState() => _RatingReviewScreenState();
}

class _RatingReviewScreenState extends State<RatingReviewScreen> {
  double _rating = 0;
  final _commentCtrl = TextEditingController();
  final List<String> _selectedTags = [];
  bool _isSubmitting = false;
  bool _submitted = false;

  final List<String> _positiveTags = ['😊 Friendly', '⏰ Punctual', '🚗 Safe Driver', '🧹 Clean Vehicle', '💬 Communicator', '🗺️ Knows Route'];
  final List<String> _negativeTags = ['⏳ Late', '😤 Rude', '💨 Fast Driver', '📵 No Communication'];

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Please select a rating!'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16)));
      return;
    }
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() { _isSubmitting = false; _submitted = true; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final border = isDark ? const Color(0xFF2D2D44) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
          title: const Text('Rate & Review', style: TextStyle(fontWeight: FontWeight.bold))),
      body: _submitted
      // Success state — star_rating lottie
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Lottie.asset('assets/animations/star_rating.json',
            width: 180, height: 180, repeat: false,
            errorBuilder: (_, __, ___) => const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 80)),
        const SizedBox(height: 16),
        Text('Review Submitted!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tp)),
        const SizedBox(height: 8),
        Text('Thank you for your feedback!', style: TextStyle(color: ts)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => Icon(
                i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: const Color(0xFFF59E0B), size: 32))),
        const SizedBox(height: 28),
        ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
            child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      ]))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // User info
          Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
              child: Row(children: [
                CircleAvatar(radius: 28, backgroundColor: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                    child: Text(widget.revieweeName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.revieweeName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
                  Text(widget.revieweeEmail, style: TextStyle(fontSize: 12, color: ts)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.directions_car, color: Color(0xFF1A73E8), size: 13),
                    const SizedBox(width: 4),
                    Text('Trip: ${widget.trip.tripCode}', style: const TextStyle(color: Color(0xFF1A73E8), fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ])),
              ])),
          const SizedBox(height: 24),

          // Star rating
          Text('Your Rating', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 12),
          Center(child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                    onTap: () => setState(() => _rating = i + 1.0),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                            i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: const Color(0xFFF59E0B),
                            size: i < _rating ? 52 : 44))))),
            const SizedBox(height: 6),
            Text(_rating == 0 ? 'Tap a star' : _rating == 1 ? '😞 Poor' : _rating == 2 ? '😐 Fair'
                : _rating == 3 ? '🙂 Good' : _rating == 4 ? '😊 Very Good' : '🌟 Excellent!',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: _rating == 0 ? ts : const Color(0xFFF59E0B))),
          ])),
          const SizedBox(height: 24),

          // Tags
          Text('Quick Tags', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8,
              children: [..._positiveTags, ..._negativeTags].map((tag) {
                final sel = _selectedTags.contains(tag);
                final isPos = _positiveTags.contains(tag);
                return GestureDetector(
                    onTap: () => setState(() => sel ? _selectedTags.remove(tag) : _selectedTags.add(tag)),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                            color: sel ? (isPos ? const Color(0xFF22C55E) : const Color(0xFFEF4444)) : (isDark ? const Color(0xFF252538) : const Color(0xFFF5F7FA)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? (isPos ? const Color(0xFF22C55E) : const Color(0xFFEF4444)) : border)),
                        child: Text(tag, style: TextStyle(fontSize: 12, color: sel ? Colors.white : tp, fontWeight: sel ? FontWeight.w600 : FontWeight.normal))));
              }).toList()),
          const SizedBox(height: 24),

          // Comment
          Text('Write a Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tp)),
          const SizedBox(height: 10),
          TextFormField(
              controller: _commentCtrl, maxLines: 4, maxLength: 300,
              style: TextStyle(color: tp, fontSize: 14),
              decoration: InputDecoration(
                  hintText: 'Share your experience...',
                  hintStyle: TextStyle(color: ts, fontSize: 13),
                  filled: true, fillColor: card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2)),
                  counterStyle: TextStyle(color: ts, fontSize: 11))),
          const SizedBox(height: 28),

          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(Icons.star_rounded, color: appIconColor(Icons.star_rounded)),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Review'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}