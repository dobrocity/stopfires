import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stopfires/config.dart';
import 'package:stopfires/router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

class LocationConsentResult {
  final bool trackingEnabled;
  final bool backgroundEnabled;
  final bool approximateOnly; // if true, you should configure reduced accuracy
  final int retentionDays; // for Firestore TTL policy

  const LocationConsentResult({
    required this.trackingEnabled,
    required this.backgroundEnabled,
    required this.approximateOnly,
    required this.retentionDays,
  });
}

class LocationConsentScreen extends StatefulWidget {
  /// Shown as the document title in the header.
  final String? title;

  /// Your privacy policy URL (required for stores + trust).
  final Uri? privacyPolicyUrl;

  /// Optional terms of service URL.
  final Uri? termsUrl;

  /// Human-readable org/app name shown in the copy.
  final String? appName;

  /// Default retention period in days (used to preselect in the UI).
  final int defaultRetentionDays;

  /// Called when user declines (use to pop or disable features).
  final VoidCallback? onDecline;

  /// If true, the background switch is hidden (e.g., for MVP).
  final bool hideBackgroundOption;

  /// If true, the approximate/precise toggle is hidden.
  final bool hideApproximateToggle;

  const LocationConsentScreen({
    super.key,
    this.title,
    this.appName,
    this.privacyPolicyUrl,
    this.onDecline,
    this.termsUrl,
    this.defaultRetentionDays = 30,
    this.hideBackgroundOption = false,
    this.hideApproximateToggle = false,
  });

  @override
  State<LocationConsentScreen> createState() => _LocationConsentScreenState();
}

class _LocationConsentScreenState extends State<LocationConsentScreen> {
  bool _agreeCore = false; // main “I agree”
  bool _enableTracking = true; // master switch
  bool _enableBackground = false; // background collection
  bool _approximateOnly = false; // reduced accuracy preference
  late int _retentionDays;

  @override
  void initState() {
    super.initState();
    _retentionDays = widget.defaultRetentionDays;
  }

  Future<void> _open(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.could_not_open_link)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAccept = _agreeCore && _enableTracking;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? context.l10n.location_consent_title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Header card
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.my_location,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.help_improve_app_location(
                          widget.appName ?? 'stopfires.org',
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // What we collect
            _Section(
              title: context.l10n.what_we_collect,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bullet(context.l10n.gps_coordinates),
                  _Bullet(context.l10n.timestamp_and_accuracy),
                  _Bullet(context.l10n.speed_and_heading),
                  _Bullet(context.l10n.hashed_region),
                ],
              ),
            ),

            // How we use it
            _Section(
              title: context.l10n.how_we_use_it,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bullet(context.l10n.show_current_position),
                  _Bullet(context.l10n.generate_trip_history),
                  _Bullet(context.l10n.enable_background_updates),
                ],
              ),
            ),

            // Controls
            _Section(
              title: context.l10n.your_choices,
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: Text(context.l10n.enable_location_tracking),
                    subtitle: Text(context.l10n.can_pause_later),
                    value: _enableTracking,
                    onChanged: (v) => setState(() => _enableTracking = v),
                  ),
                  if (!widget.hideBackgroundOption)
                    SwitchListTile.adaptive(
                      title: Text(context.l10n.allow_background_updates),
                      subtitle: Text(
                        AppLocalizations.of(
                          context,
                        )!.required_android_foreground,
                      ),
                      value: _enableBackground,
                      onChanged: _enableTracking
                          ? (v) => setState(() => _enableBackground = v)
                          : null,
                    ),
                  if (!widget.hideApproximateToggle)
                    SwitchListTile.adaptive(
                      title: Text(context.l10n.use_approximate_location),
                      subtitle: Text(context.l10n.lower_precision_privacy),
                      value: _approximateOnly,
                      onChanged: _enableTracking
                          ? (v) => setState(() => _approximateOnly = v)
                          : null,
                    ),
                  ListTile(
                    title: Text(context.l10n.data_retention),
                    subtitle: Text(context.l10n.trip_history_storage),
                    trailing: DropdownButton<int>(
                      value: _retentionDays,
                      onChanged: (v) =>
                          setState(() => _retentionDays = v ?? _retentionDays),
                      items: [
                        DropdownMenuItem(
                          value: 7,
                          child: Text(context.l10n.days_7),
                        ),
                        DropdownMenuItem(
                          value: 14,
                          child: Text(context.l10n.days_14),
                        ),
                        DropdownMenuItem(
                          value: 30,
                          child: Text(context.l10n.days_30),
                        ),
                        DropdownMenuItem(
                          value: 90,
                          child: Text(context.l10n.days_90),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Legal
            _Section(
              title: context.l10n.privacy,
              child: Wrap(
                spacing: 12,
                children: [
                  if (widget.privacyPolicyUrl != null)
                    TextButton.icon(
                      onPressed: () => _open(widget.privacyPolicyUrl!),
                      icon: const Icon(Icons.privacy_tip_outlined),
                      label: Text(context.l10n.privacy_policy),
                    ),
                  if (widget.termsUrl != null)
                    TextButton.icon(
                      onPressed: () => _open(widget.termsUrl!),
                      icon: const Icon(Icons.description_outlined),
                      label: Text(context.l10n.terms_of_service),
                    ),
                ],
              ),
            ),

            // Agree checkbox
            CheckboxListTile(
              value: _agreeCore,
              onChanged: (v) => setState(() => _agreeCore = v ?? false),
              title: Text(context.l10n.i_agree_to_above),
              subtitle: Text(context.l10n.can_change_settings),
            ),

            const SizedBox(height: 8),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDecline,
                    child: Text(context.l10n.decline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canAccept
                        ? () {
                            context.push(Routes.sharedMap);
                          }
                        : null,
                    child: Text(context.l10n.accept_continue),
                  ),
                ),
              ],
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
