import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/emergency_contact_model.dart';
import '../../utils/app_icon_colors.dart';

const _kPrimary = Color(0xFF1A73E8);
const _kDanger = Color(0xFFEF4444);
const _kSuccess = Color(0xFF22C55E);

const _relations = ['Family', 'Friend', 'Other'];

Color _relationColor(String r) {
  switch (r) {
    case 'Family': return _kDanger;
    case 'Friend': return const Color(0xFF7C3AED);
    default: return const Color(0xFF64748B);
  }
}

class ApprovedContactsScreen extends StatefulWidget {
  const ApprovedContactsScreen({super.key});

  @override
  State<ApprovedContactsScreen> createState() => _ApprovedContactsScreenState();
}

class _ApprovedContactsScreenState extends State<ApprovedContactsScreen> {
  void _showContactDialog({EmergencyContact? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final formKey = GlobalKey<FormState>();
    String relation = existing?.relation ?? 'Family';
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'Edit Contact' : 'Add Contact'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline, color: appIconColor(Icons.person_outline)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimary, width: 2)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    prefixIcon: Icon(Icons.call_outlined, color: appIconColor(Icons.call_outlined)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimary, width: 2)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter a phone number';
                    final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                    if (digits.length < 10) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email (optional)',
                    prefixIcon: Icon(Icons.email_outlined, color: appIconColor(Icons.email_outlined)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimary, width: 2)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerLeft, child: Text('Relation', style: TextStyle(fontSize: 12, color: appIconColor(Icons.family_restroom)))),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: _relations.map((r) {
                  final selected = relation == r;
                  return ChoiceChip(
                    label: Text(r),
                    selected: selected,
                    onSelected: (_) => setDialogState(() => relation = r),
                    selectedColor: _relationColor(r).withValues(alpha: 0.18),
                    labelStyle: TextStyle(color: selected ? _relationColor(r) : null, fontWeight: selected ? FontWeight.w700 : FontWeight.normal),
                    side: BorderSide(color: selected ? _relationColor(r) : Colors.grey.withValues(alpha: 0.3)),
                  );
                }).toList()),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final auth = context.read<AuthProvider>();
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                final success = isEdit
                    ? await auth.updateEmergencyContact(
                    id: existing.id, name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(),
                    email: emailCtrl.text.trim(), relation: relation)
                    : await auth.addEmergencyContact(
                    name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(),
                    email: emailCtrl.text.trim(), relation: relation);
                navigator.pop();
                messenger.showSnackBar(SnackBar(
                  content: Text(success ? (isEdit ? 'Contact updated!' : 'Contact added!') : 'Something went wrong. Try again.'),
                  backgroundColor: success ? _kSuccess : _kDanger,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(16),
                ));
              },
              style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(EmergencyContact contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Contact'),
        content: Text('Remove ${contact.name} from emergency contacts?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kDanger, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AuthProvider>().deleteEmergencyContact(contact.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final contacts = auth.currentUser?.emergencyContacts ?? [];
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        title: const Text('Emergency Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kPrimary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Contact', style: TextStyle(color: Colors.white)),
        onPressed: () => _showContactDialog(),
      ),
      body: contacts.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people_outline, size: 64, color: appIconColor(Icons.people_outline)),
            const SizedBox(height: 16),
            Text('No emergency contacts yet', style: TextStyle(color: ts, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Add contacts so we know who to call\nand alert if you ever hit SOS',
                style: TextStyle(color: ts, fontSize: 13), textAlign: TextAlign.center),
          ]),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final c = contacts[index];
          final rc = _relationColor(c.relation);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
            child: Row(children: [
              CircleAvatar(radius: 22, backgroundColor: rc.withValues(alpha: 0.12),
                  child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                      style: TextStyle(color: rc, fontWeight: FontWeight.bold, fontSize: 16))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(c.name, style: TextStyle(color: tp, fontWeight: FontWeight.w700, fontSize: 14.5), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: rc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(c.relation, style: TextStyle(color: rc, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(c.phone, style: TextStyle(color: ts, fontSize: 12.5)),
                  if (c.email.isNotEmpty) Text(c.email, style: TextStyle(color: ts, fontSize: 11.5)),
                ]),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: appIconColor(Icons.edit_outlined), size: 20),
                onPressed: () => _showContactDialog(existing: c),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: _kDanger, size: 20),
                onPressed: () => _confirmDelete(c),
              ),
            ]),
          );
        },
      ),
    );
  }
}