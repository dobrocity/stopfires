import 'package:corbado_auth/corbado_auth.dart';
import 'package:stopfires/auth_provider.dart';
import 'package:stopfires/config.dart';
import 'package:stopfires/screens/email_edit.dart';
import 'package:stopfires/screens/email_verify_otp.dart';
import 'package:stopfires/screens/login_init.dart';
import 'package:stopfires/screens/passkey_append.dart';
import 'package:stopfires/screens/passkey_verify.dart';
import 'package:stopfires/screens/signup_init.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AuthPage extends HookConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corbadoAuth = ref.watch(corbadoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app_name)),
      body: Stack(
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: CorbadoAuthComponent(
                  corbadoAuth: corbadoAuth,
                  components: CorbadoScreens(
                    signupInit: SignupInitScreen.new,
                    loginInit: LoginInitScreen.new,
                    emailVerifyOtp: EmailVerifyOtpScreen.new,
                    passkeyAppend: PasskeyAppendScreen.new,
                    passkeyVerify: PasskeyVerifyScreen.new,
                    emailEdit: EmailEditScreen.new,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
