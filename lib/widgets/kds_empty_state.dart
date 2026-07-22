import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared "nothing here" state for the subscription chef/delivery views.
class KdsEmptyState extends StatelessWidget {
  final String message;
  const KdsEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.done_all, size: 64, color: Colors.green),
            const SizedBox(height: 12),
            Text(message,
                style: GoogleFonts.chivo(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700])),
          ],
        ),
      );
}
