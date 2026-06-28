import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';

class AdminUser {
  final String id, name, email, phone, joinDate;
  final bool isVerified, isBlocked;
  final int totalTrips;
  final double safetyScore;

  const AdminUser({
    required this.id, required this.name, required this.email,
    required this.phone, required this.joinDate,
    this.isVerified = false, this.isBlocked = false,
    this.totalTrips = 0, this.safetyScore = 0.0,
  });
}

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _filter = 'All';
  final List<String> _filters = ['All', 'Verified', 'Unverified', 'Blocked'];

  final List<AdminUser> _users = const [
    AdminUser(id: 'u001', name: 'Nisha Fathima', email: 'nisha@fcw.edu', phone: '+91 98765 43210', joinDate: '01 Jan 2026', isVerified: true, totalTrips: 12, safetyScore: 88),
    AdminUser(id: 'u002', name: 'Priya Sundaram', email: 'priya@example.com', phone: '+91 87654 32109', joinDate: '05 Jan 2026', isVerified: true, totalTrips: 8, safetyScore: 92),
    AdminUser(id: 'u003', name: 'Ayesha Khan', email: 'ayesha@gmail.com', phone: '+91 76543 21098', joinDate: '10 Jan 2026', isVerified: false, totalTrips: 3, safetyScore: 75),
    AdminUser(id: 'u004', name: 'Meena Ravi', email: 'meena@yahoo.com', phone: '+91 65432 10987', joinDate: '15 Jan 2026', isVerified: true, totalTrips: 20, safetyScore: 95),
    AdminUser(id: 'u005', name: 'Kavitha S', email: 'kavitha@fcw.edu', phone: '+91 54321 09876', joinDate: '20 Jan 2026', isVerified: false, totalTrips: 1, safetyScore: 60),
    AdminUser(id: 'u006', name: 'Riya Menon', email: 'riya@gmail.com', phone: '+91 43210 98765', joinDate: '25 Jan 2026', isVerified: false, isBlocked: true, totalTrips: 0, safetyScore: 0),
    AdminUser(id: 'u007', name: 'Divya Lakshmi', email: 'divya@fcw.edu', phone: '+91 32109 87654', joinDate: '01 Feb 2026', isVerified: true, totalTrips: 15, safetyScore: 90),
    AdminUser(id: 'u008', name: 'Saranya K', email: 'saranya@gmail.com', phone: '+91 21098 76543', joinDate: '05 Feb 2026', isVerified: false, totalTrips: 5, safetyScore: 72),
  ];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<AdminUser> get _filtered => _users.where((u) {
    final matchSearch = _search.isEmpty ||
        u.name.toLowerCase().contains(_search.toLowerCase()) ||
        u.email.toLowerCase().contains(_search.toLowerCase());
    final matchFilter = _filter == 'All' ||
        (_filter == 'Verified' && u.isVerified && !u.isBlocked) ||
        (_filter == 'Unverified' && !u.isVerified && !u.isBlocked) ||
        (_filter == 'Blocked' && u.isBlocked);
    return matchSearch && matchFilter;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF0F4FF);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Container(margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: Text('${_users.length} users', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
      body: Column(children: [
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
              Text('${_filtered.length} users found', style: TextStyle(fontSize: 12, color: ts)),
            ])),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _filtered.length,
            itemBuilder: (context, i) {
              final user = _filtered[i];
              return _UserCard(user: user, card: card, tp: tp, ts: ts,
                  onTap: () => _showUserDetail(context, user, tp, ts, card));
            },
          ),
        ),
      ]),
    );
  }

  void _showUserDetail(BuildContext context, AdminUser user, Color tp, Color ts, Color card) {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ts, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            CircleAvatar(radius: 32, backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                child: Text(user.name[0], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)))),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(user.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tp)),
              if (user.isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, color: Color(0xFF1A73E8), size: 18)],
            ]),
            Text(user.email, style: TextStyle(color: ts, fontSize: 13)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _DetailStat(label: 'Trips', value: '${user.totalTrips}', color: const Color(0xFF1A73E8)),
              _DetailStat(label: 'Safety', value: '${user.safetyScore.round()}', color: const Color(0xFF22C55E)),
              _DetailStat(label: 'Joined', value: user.joinDate, color: const Color(0xFF7C3AED)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.block_rounded, color: Color(0xFFEF4444)),
                label: const Text('Block', style: TextStyle(color: Color(0xFFEF4444))),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFEF4444)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.verified_rounded, color: appIconColor(Icons.verified_rounded)),
                label: const Text('Verify'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
            ]),
            const SizedBox(height: 8),
          ]),
        ));
  }
}

class _UserCard extends StatelessWidget {
  final AdminUser user;
  final Color card, tp, ts;
  final VoidCallback onTap;
  const _UserCard({required this.user, required this.card, required this.tp, required this.ts, required this.onTap});

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
                child: Text(user.name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED), fontSize: 16))),
            if (user.isVerified) Positioned(bottom: 0, right: 0,
                child: Container(padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF1A73E8), size: 12))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(user.name, style: TextStyle(fontWeight: FontWeight.w600, color: user.isBlocked ? ts : tp, fontSize: 14)),
              if (user.isBlocked) ...[const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Blocked', style: TextStyle(color: Color(0xFFEF4444), fontSize: 9, fontWeight: FontWeight.bold)))],
            ]),
            Text(user.email, style: TextStyle(fontSize: 11, color: ts)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${user.totalTrips} trips', style: TextStyle(fontSize: 11, color: ts)),
            Text('Score: ${user.safetyScore.round()}', style: const TextStyle(fontSize: 11, color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
          ]),
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
