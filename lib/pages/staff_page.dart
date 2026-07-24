import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/staff_admin_provider.dart';

const _roleLabels = {
  'admin': 'Admin (full access)',
  'gym_manager': 'Gym manager',
  'sub_manager': 'Subscription manager',
  'gym_chef': 'Gym kitchen (KDS)',
  'gym_delivery': 'Gym delivery',
  'subs_chef': 'Subscription kitchen',
  'subs_delivery': 'Subscription delivery',
};

/// Staff access management: invite staff, assign a role, revoke/reactivate
/// their login, and reset passwords. Admin-only (see router.dart's guard).
class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  @override
  void initState() {
    super.initState();
    context.read<StaffAdminProvider>().fetchStaff();
  }

  void _toast(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? Colors.green[700] : Colors.red[700],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<StaffAdminProvider>();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('STAFF ACCESS',
            style: GoogleFonts.chivo(fontSize: 22, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: p.fetchStaff,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _inviteDialog,
        icon: const Icon(Icons.person_add),
        label: Text('ADD STAFF',
            style: GoogleFonts.chivo(fontWeight: FontWeight.w800)),
      ),
      body: p.isLoading && p.staff.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : p.staff.isEmpty
              ? Center(
                  child: Text('No staff accounts yet',
                      style: GoogleFonts.chivo(
                          fontSize: 16, color: Colors.grey[600])),
                )
              : RefreshIndicator(
                  onRefresh: p.fetchStaff,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: p.staff.length,
                    itemBuilder: (_, i) => _StaffCard(
                      profile: p.staff[i],
                      onRevoke: () => _revokeDialog(p.staff[i]),
                      onReactivate: () => _roleDialog(
                        title: 'Reactivate access',
                        confirmLabel: 'REACTIVATE',
                        initialRole: 'gym_manager',
                        onConfirm: (role) => context
                            .read<StaffAdminProvider>()
                            .reactivate(p.staff[i]['id'] as String, role),
                      ),
                      onChangeRole: () => _roleDialog(
                        title: 'Change role',
                        confirmLabel: 'SAVE',
                        initialRole: p.staff[i]['role'] as String,
                        onConfirm: (role) => context
                            .read<StaffAdminProvider>()
                            .changeRole(p.staff[i]['id'] as String, role),
                      ),
                      onResetPassword: () => _resetPasswordDialog(p.staff[i]),
                    ),
                  ),
                ),
    );
  }

  Future<void> _inviteDialog() async {
    final email = TextEditingController();
    final password = TextEditingController();
    String role = 'gym_manager';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add staff member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Login email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: password,
                decoration: const InputDecoration(
                    labelText: 'Password (min 8 characters)'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: _roleLabels.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => role = v ?? role),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('CREATE')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final err = await context.read<StaffAdminProvider>().invite(
          email: email.text.trim(),
          password: password.text,
          role: role,
        );
    _toast(err ?? 'Staff account created ✅', ok: err == null);
  }

  Future<void> _revokeDialog(Map<String, dynamic> profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke access?'),
        content: Text(
            'This disables ${profile['email']}\'s login immediately. '
            'You can reactivate it later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('REVOKE'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await context
        .read<StaffAdminProvider>()
        .revoke(profile['id'] as String);
    _toast(err ?? 'Access revoked', ok: err == null);
  }

  Future<void> _roleDialog({
    required String title,
    required String confirmLabel,
    required String initialRole,
    required Future<String?> Function(String role) onConfirm,
  }) async {
    String role = initialRole;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(title),
          content: DropdownButtonFormField<String>(
            initialValue: role,
            items: _roleLabels.entries
                .map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => role = v ?? role),
            decoration: const InputDecoration(labelText: 'Role'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final err = await onConfirm(role);
    _toast(err ?? 'Done ✅', ok: err == null);
  }

  Future<void> _resetPasswordDialog(Map<String, dynamic> profile) async {
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: password,
          decoration:
              const InputDecoration(labelText: 'New password (min 8 chars)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('RESET')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await context
        .read<StaffAdminProvider>()
        .resetPassword(profile['id'] as String, password.text);
    _toast(err ?? 'Password updated', ok: err == null);
  }
}

class _StaffCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onRevoke, onReactivate, onChangeRole, onResetPassword;

  const _StaffCard({
    required this.profile,
    required this.onRevoke,
    required this.onReactivate,
    required this.onChangeRole,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final role = profile['role'] as String?;
    final revoked = role == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (profile['email'] ?? '').toString(),
                    style: GoogleFonts.chivo(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: revoked ? Colors.red[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    revoked ? 'REVOKED' : 'ACTIVE',
                    style: GoogleFonts.chivo(
                        fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              revoked ? 'Access revoked' : (_roleLabels[role] ?? role),
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800]),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: revoked
                  ? [
                      ElevatedButton.icon(
                        onPressed: onReactivate,
                        icon: const Icon(Icons.check, size: 16),
                        label: Text('REACTIVATE',
                            style: GoogleFonts.chivo(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white),
                      ),
                    ]
                  : [
                      TextButton(
                        onPressed: onResetPassword,
                        child: const Text('RESET PASSWORD'),
                      ),
                      TextButton(
                        onPressed: onChangeRole,
                        child: const Text('CHANGE ROLE'),
                      ),
                      TextButton(
                        onPressed: onRevoke,
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('REVOKE'),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
