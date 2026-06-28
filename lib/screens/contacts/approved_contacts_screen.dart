import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_icon_colors.dart';

class ApprovedContactsScreen extends StatefulWidget {
  const ApprovedContactsScreen({super.key});

  @override
  State<ApprovedContactsScreen> createState() => _ApprovedContactsScreenState();
}

class _ApprovedContactsScreenState extends State<ApprovedContactsScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Contact'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Enter email address',
              prefixIcon: Icon(Icons.email_outlined, color: appIconColor(Icons.email_outlined)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Invalid email';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { _emailController.clear(); Navigator.pop(context); },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              final email = _emailController.text.trim();
              final success = await context.read<AuthProvider>().addContact(email);
              if (!mounted) return;
              Navigator.pop(context);
              _emailController.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? 'Contact added!' : 'Already added or error'),
                  backgroundColor: success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final contacts = auth.currentUser?.approvedContacts ?? [];
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        title: const Text('Approved Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A73E8),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Contact', style: TextStyle(color: Colors.white)),
        onPressed: _showAddDialog,
      ),
      body: contacts.isEmpty
          ? Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.people_outline, size: 64, color: appIconColor(Icons.people_outline)),
          const SizedBox(height: 16),
          Text('No approved contacts yet', style: TextStyle(color: ts, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Add contacts to share your location\nand send SOS alerts',
              style: TextStyle(color: ts, fontSize: 13), textAlign: TextAlign.center),
        ]),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final email = contacts[index];
          final initial = email[0].toUpperCase();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                child: Text(initial, style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
              ),
              title: Text(email, style: TextStyle(color: tp, fontWeight: FontWeight.w500)),
              subtitle: Text('Approved contact', style: TextStyle(color: ts, fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444)),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Remove Contact'),
                      content: Text('Remove $email from approved contacts?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    await context.read<AuthProvider>().removeContact(email);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
