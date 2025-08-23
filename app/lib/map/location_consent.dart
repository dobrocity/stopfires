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
