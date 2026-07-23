import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

/// Shown once, right after a Supreme Admin (role='admin') logs in — the only
/// role with access to both models, so it's the only one that needs to pick
/// where to start. Every other role's homeRoute goes straight to their one
/// model; nothing else routes through here.
class ModelChooserPage extends StatelessWidget {
  const ModelChooserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('WHICH MODEL?',
                    style: GoogleFonts.chivo(
                        fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Signed in as Supreme Admin — pick where to start.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 280,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      adminAuth.chooseModel();
                      context.go('/');
                    },
                    icon: const Icon(Icons.restaurant),
                    label: const Text('GYM MODEL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: GoogleFonts.chivo(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 280,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      adminAuth.chooseModel();
                      context.go('/subs');
                    },
                    icon: const Icon(Icons.soup_kitchen),
                    label: const Text('SUBSCRIPTION MODEL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: GoogleFonts.chivo(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => adminAuth.logout(),
                  child: Text('LOG OUT',
                      style: GoogleFonts.inter(color: Colors.grey[700])),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
