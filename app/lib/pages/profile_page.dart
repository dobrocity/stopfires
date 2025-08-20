import 'package:stopfires/auth_provider.dart';
import 'package:stopfires/config.dart';
import 'package:stopfires/router.dart';
import 'package:stopfires/widgets/filled_text_button.dart';
import 'package:stopfires/widgets/outlined_text_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stopfires/widgets/secondary_text_button.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final corbado = ref.watch(corbadoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app_name)),
      body: Stack(
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.welcome,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user.value?.corbado.email ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.l10n.profile_page_description,
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledTextButton(
                        onTap: () => context.push(Routes.locationConsent),
                        content: context.l10n.shared_map,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedTextButton(
                        onTap: () => context.push(Routes.editProfile),
                        content: context.l10n.edit_profile,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedTextButton(
                        onTap: () => context.push(Routes.passkeyList),
                        content: context.l10n.passkey_list,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: SecondaryTextButton(
                        onTap: corbado.signOut,
                        content: context.l10n.sign_out,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
