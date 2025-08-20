import 'package:flutter/material.dart';
import 'package:stopfires/l10n/app_localizations.dart';

String getProjectID() {
  return "pro-8309560514880320811";
}

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
