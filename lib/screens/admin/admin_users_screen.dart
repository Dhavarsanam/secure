import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/firestore_service.dart';
import '../../models/trip_model.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';
import '../trip/safety_score_screen.dart';

// Fully dynamic — every user shown here comes live from Firestore's
// `users` collection (see FirestoreService.allUsersStream). There is no
// hardcoded/demo user list and no duplicate rows: Firestore document IDs
// are unique, so each user appears exactly once.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  final _firestoreService = FirestoreService();
  String _search = '';
  String _filter = 'All';
  final List<String> _filters = ['All', 'Verified', 'Unverified', 'Blocked'];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<UserModel> _applyFilters(List<UserModel> users) => users.where((u) {
    final matchSearch = _search.isEmpty ||
        u.fullName.toLowerCase().contains(_search.toLowerCase()) ||
        u.email.toLowerCase().contains(_search.toLowerCase());
    final matchFilter = _filter == 'All' ||
        (_filter == 'Verified' && u.isVerified && !u.isBlocked) ||
        (_filter == 'Unverified' && !u.isVerified && !u.isBlocked) ||
        (_filter == 'Blocked' && u.isBlocked);
    return matchSearch && matchFilter;
  }).toList();

  Future<void> _toggleVerified(UserModel user) async {
    final ok = await _firestoreService.setUserVerified(user.uid, !user.isVerified);
    if (!ok && mounted) _showSnack('Could not update verification status', const Color(0xFFEF4444));
  }

  Future<void> _toggleBlocked(UserModel user) async {
    final ok = await _firestoreService.setUserBlocked(user.uid, !user.isBlocked);
    if (!ok && mounted) _showSnack('Could not update block status', const Color(0xFFEF4444));
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF0F4FF);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      body: StreamBuilder<List<UserModel>>(
        stream: _firestoreService.allUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(children: [
              _appBar(0, isDark),
              Expanded(child: Center(child: Text('Failed to load users', style: TextStyle(color: ts)))),
            ]);
          }
          if (!snapshot.hasData) {
            return Column(children: [
              _appBar(0, isDark),
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))),
            ]);
          }

          final users = snapshot.data!;
          final filtered = _applyFilters(users);

          return Column(children: [
            _appBar(users.length, isDark),
            Container(color: card, padding: const EdgeInsets.all(12), child: Column(children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: TextStyle(color: ts, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: appIconColor(Icons.search)),
                  suffixIcon: _search.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: appIconColor(Icons.clear)),
                      onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); }) : null,
                  filled: true, fillColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(height: 32, child: ListView(scrollDirection: Axis.horizontal,
                  children: _filters.map((f) => Padding(padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f, style: TextStyle(fontSize: 12, color: _filter == f ? Colors.white : tp,
                            fontWeight: _filter == f ? FontWeight.w600 : FontWeight.normal)),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                        backgroundColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F7FA),
                        selectedColor: const Color(0xFF7C3AED),
                        checkmarkColor: Colors.white, side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ))).toList())),
            ])),

            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  Text('${filtered.length} users found', style: TextStyle(fontSize: 12, color: ts)),
                ])),

            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('No users match this search/filter', style: TextStyle(color: ts, fontSize: 13)))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final user = filtered[i];
                  return _UserCard(
                    key: ValueKey(user.uid),
                    user: user,
                    card: card, tp: tp, ts: ts,
                    firestoreService: _firestoreService,
                    onTap: () => _showUserDetail(context, user, tp, ts, card),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _appBar(int totalCount, bool isDark) => AppBar(
    backgroundColor: const Color(0xFF7C3AED),
    foregroundColor: Colors.white,
    automaticallyImplyLeading: false,
    title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)),
    actions: [
      Container(margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
          child: Text('$totalCount users', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
    ],
  );

  void _showUserDetail(BuildContext context, UserModel user, Color tp, Color ts, Color card) {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheetCtx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ts, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            CircleAvatar(radius: 32, backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)))),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(user.fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tp)),
              if (user.isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, color: Color(0xFF1A73E8), size: 18)],
            ]),
            Text(user.email, style: TextStyle(color: ts, fontSize: 13)),
            Text(user.phoneNumber, style: TextStyle(color: ts, fontSize: 12)),
            const SizedBox(height: 16),
            FutureBuilder<List<TripModel>>(
              future: _firestoreService.userTrips(user.uid),
              builder: (context, snap) {
                final trips = snap.data ?? [];
                final completed = trips.where((t) => t.status == TripStatus.completed).length;
                final cancelled = trips.where((t) => t.status == TripStatus.cancelled).length;
                final score = SafetyScore.calculateFromCounts(
                  total: trips.length,
                  completed: completed,
                  cancelled: cancelled,
                  contactsCount: user.emergencyContacts.length,
                  locationOn: user.isLocationSharing,
                );
                return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _DetailStat(label: 'Trips', value: snap.connectionState == ConnectionState.waiting ? '…' : '${trips.length}', color: const Color(0xFF1A73E8)),
                  _DetailStat(label: 'Safety', value: snap.connectionState == ConnectionState.waiting ? '…' : '${score.overall.round()}', color: const Color(0xFF22C55E)),
                  _DetailStat(label: 'Joined', value: DateFormat('dd MMM yyyy').format(user.createdAt), color: const Color(0xFF7C3AED)),
                ]);
              },
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  await _toggleBlocked(user);
                },
                icon: Icon(user.isBlocked ? Icons.lock_open_rounded : Icons.block_rounded, color: const Color(0xFFEF4444)),
                label: Text(user.isBlocked ? 'Unblock' : 'Block', style: const TextStyle(color: Color(0xFFEF4444))),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFEF4444)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  await _toggleVerified(user);
                },
                icon: Icon(user.isVerified ? Icons.cancel_outlined : Icons.verified_rounded, color: appIconColor(Icons.verified_rounded)),
                label: Text(user.isVerified ? 'Unverify' : 'Verify'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
            ]),
            const SizedBox(height: 8),
          ]),
        ));
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final Color card, tp, ts;
  final FirestoreService firestoreService;
  final VoidCallback onTap;
  const _UserCard({super.key, required this.user, required this.card, required this.tp, required this.ts, required this.firestoreService, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: user.isBlocked ? card.withValues(alpha: 0.5) : card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
            border: user.isBlocked ? Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)) : null),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(radius: 22, backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED), fontSize: 16))),
            if (user.isVerified) Positioned(bottom: 0, right: 0,
                child: Container(padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF1A73E8), size: 12))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(user.fullName, style: TextStyle(fontWeight: FontWeight.w600, color: user.isBlocked ? ts : tp, fontSize: 14), overflow: TextOverflow.ellipsis)),
              if (user.isBlocked) ...[const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Blocked', style: TextStyle(color: Color(0xFFEF4444), fontSize: 9, fontWeight: FontWeight.bold)))],
            ]),
            Text(user.email, style: TextStyle(fontSize: 11, color: ts), overflow: TextOverflow.ellipsis),
          ])),
          FutureBuilder<int>(
            future: firestoreService.userTripCount(user.uid),
            builder: (context, snap) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(snap.hasData ? '${snap.data} trips' : '… trips', style: TextStyle(fontSize: 11, color: ts)),
              Text(DateFormat('dd MMM yyyy').format(user.createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _DetailStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
  ]);
}