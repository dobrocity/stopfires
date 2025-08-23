import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stopfires/config.dart';
import 'package:stopfires/router.dart';

import 'package:url_launcher/url_launcher.dart';

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
  bool _acknowledgeSharing = false; // acknowledge location sharing disclaimer

  Future<void> _open(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.could_not_open_link)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final canAccept = _acknowledgeSharing;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l10n.location_consent_title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Location Sharing Disclaimer - NEW SECTION
            _Section(
              title: l10n.location_sharing_disclaimer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.location_sharing_disclaimer_text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.location_sharing_disclaimer_privacy,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _acknowledgeSharing,
                    onChanged: (v) =>
                        setState(() => _acknowledgeSharing = v ?? false),
                    title: Text(
                      l10n.location_sharing_disclaimer_acknowledge,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            // Legal
            _Section(
              title: l10n.privacy,
              child: Wrap(
                spacing: 12,
                children: [
                  if (widget.privacyPolicyUrl != null)
                    TextButton.icon(
                      onPressed: () => _open(widget.privacyPolicyUrl!),
                      icon: const Icon(Icons.privacy_tip_outlined),
                      label: Text(l10n.privacy_policy),
                    ),
                  if (widget.termsUrl != null)
                    TextButton.icon(
                      onPressed: () => _open(widget.termsUrl!),
                      icon: const Icon(Icons.description_outlined),
                      label: Text(l10n.terms_of_service),
                    ),
                ],
              ),
            ),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDecline ?? () => context.pop(),
                    child: Text(l10n.decline),
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
                    child: Text(l10n.accept_continue),
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
