import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

/// Lets a Supreme Admin (the only role with access to both models) jump
/// straight to the other model's dashboard without going back through the
/// /choose-model screen. Renders nothing for any other role, since every
/// other role is confined to exactly one model anyway.
class ModelSwitcher extends StatelessWidget {
  final String current; // 'gym' or 'subscription'
  const ModelSwitcher({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    if (adminAuth.role != 'admin') return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Switch model',
      icon: const Icon(Icons.swap_horiz, color: Colors.black87),
      onSelected: (v) => context.go(v == 'gym' ? '/' : '/subs'),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'gym',
          checked: current == 'gym',
          child: const Text('GYM MODEL'),
        ),
        CheckedPopupMenuItem(
          value: 'subscription',
          checked: current == 'subscription',
          child: const Text('SUBSCRIPTION MODEL'),
        ),
      ],
    );
  }
}
