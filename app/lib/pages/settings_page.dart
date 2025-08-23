import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stopfires/config.dart';
import 'package:stopfires/router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // What we collect
            _Section(
              title: l10n.what_we_collect,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bullet(l10n.gps_coordinates),
                  _Bullet(l10n.timestamp_and_accuracy),
                  _Bullet(l10n.speed_and_heading),
                  _Bullet(l10n.hashed_region),
                ],
              ),
            ),

            // How we use it
            _Section(
              title: l10n.how_we_use_it,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bullet(l10n.show_current_position),
                  _Bullet(l10n.generate_trip_history),
                  _Bullet(l10n.enable_background_updates),
                ],
              ),
            ),

            // Settings Actions
            _Section(
              title: l10n.settings,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.key),
                    title: Text(l10n.passkey_list),
                    subtitle: Text(l10n.check_your_passkeys),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.push(Routes.passkeyList),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: body)),
        ],
      ),
    );
  }
}
