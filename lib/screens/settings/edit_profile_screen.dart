import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

/// Full editable profile page — the destination for Settings > "View Profile".
/// Reads the signed-in user straight from AuthProvider (single source of
/// truth, no locally duplicated copies) and writes back through
/// AuthProvider.updateProfile() / updateProfileImage() so every other screen
/// that watches AuthProvider (Home, Settings, etc.) updates immediately.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameCtrl = TextEditingController(text: user?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: user?.phoneNumber ?? '');
    _nameCtrl.addListener(_markDirty);
    _phoneCtrl.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage(Color card, Color tp, Color ts) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFF1A73E8)),
              title: Text('Take Photo', style: TextStyle(color: tp, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(bctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF22C55E)),
              title: Text('Choose from Gallery', style: TextStyle(color: tp, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(bctx, ImageSource.gallery),
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: () => Navigator.pop(bctx), child: Text('Cancel', style: TextStyle(color: ts))),
          ]),
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 80);
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      final base64Str = base64Encode(bytes);
      await context.read<AuthProvider>().updateProfileImage(base64Str);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not access camera/gallery. Please check permissions.')));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await context.read<AuthProvider>().updateProfile(
      fullName: _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Profile updated' : 'Could not update profile. Please try again.'),
      backgroundColor: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final user = context.watch<AuthProvider>().currentUser;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A2E);
    final ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final hasPhoto = (user?.profileImageUrl?.isNotEmpty == true);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(children: [
            Center(
              child: GestureDetector(
                onTap: () => _pickProfileImage(card, tp, ts),
                child: Stack(children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                    backgroundImage: hasPhoto ? MemoryImage(base64Decode(user!.profileImageUrl!)) : null,
                    child: hasPhoto
                        ? null
                        : Text((user?.fullName.isNotEmpty == true) ? user!.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF1A73E8), shape: BoxShape.circle, border: Border.all(color: bg, width: 3)),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                onPressed: () => _pickProfileImage(card, tp, ts),
                child: Text(hasPhoto ? 'Change Photo' : 'Add Photo',
                    style: const TextStyle(color: Color(0xFF1A73E8), fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (hasPhoto)
                TextButton(
                  onPressed: () => context.read<AuthProvider>().removeProfileImage(),
                  child: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 24),

            _fieldLabel('Full Name', tp),
            TextFormField(
              controller: _nameCtrl,
              style: TextStyle(color: tp),
              decoration: _inputDecoration(card, ts, Icons.person_outline_rounded),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name cannot be empty' : null,
            ),
            const SizedBox(height: 18),

            _fieldLabel('Phone Number', tp),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: tp),
              decoration: _inputDecoration(card, ts, Icons.phone_outlined),
            ),
            const SizedBox(height: 18),

            _fieldLabel('Email', tp),
            TextFormField(
              enabled: false,
              initialValue: user?.email ?? '',
              style: TextStyle(color: ts),
              decoration: _inputDecoration(card, ts, Icons.email_outlined).copyWith(
                  suffixIcon: Icon(Icons.lock_outline_rounded, size: 16, color: ts),
                  helperText: 'Email is linked to your account and cannot be changed here'),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_dirty && !_saving) ? _save : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    disabledBackgroundColor: const Color(0xFF1A73E8).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, Color tp) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Align(alignment: Alignment.centerLeft, child: Text(text, style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w600))),
  );

  InputDecoration _inputDecoration(Color card, Color ts, IconData icon) => InputDecoration(
    prefixIcon: Icon(icon, color: ts, size: 20),
    filled: true,
    fillColor: card,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5)),
  );
}