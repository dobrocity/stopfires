import 'package:corbado_auth/corbado_auth.dart';
import 'package:stopfires/providers/auth_provider.dart';
import 'package:stopfires/config.dart';
import 'package:stopfires/screens/helper.dart';
import 'package:stopfires/widgets/filled_text_button.dart';
import 'package:stopfires/widgets/outlined_text_button.dart';
import 'package:stopfires/widgets/passkey_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:overlay_support/overlay_support.dart';

class PasskeyListPage extends HookConsumerWidget {
  const PasskeyListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corbado = ref.watch(corbadoProvider);
    final passkeys = ref.watch(passkeysProvider).value ?? [];

    final isLoading = useState<bool>(false);
    final error = useState<String?>(null);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final maybeError = error.value;
        if (maybeError != null) {
          showNotificationError(context, maybeError);
        }
      });

      return null;
    }, [error.value]);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app_name)),
      body: Stack(
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.check_your_passkeys,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Column(
                          children: passkeys
                              .map(
                                (p) => SizedBox(
                                  width: double.infinity,
                                  child: PasskeyCard(
                                    passkey: p,
                                    onDelete: (String credentialID) async {
                                      if (isLoading.value) {
                                        return;
                                      }
                                      isLoading.value = true;
                                      error.value = null;

                                      try {
                                        await corbado.deletePasskey(
                                          credentialID: credentialID,
                                        );

                                        showSimpleNotification(
                                          Text(
                                            context
                                                .l10n
                                                .passkey_has_been_deleted_successfully,
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          leading: const Icon(
                                            Icons.check,
                                            color: Colors.green,
                                          ),
                                          background: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        );
                                      } on CorbadoError catch (e) {
                                        error.value = e.translatedError;
                                      } catch (e) {
                                        error.value = e.toString();
                                      } finally {
                                        isLoading.value = false;
                                      }
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledTextButton(
                            onTap: () async {
                              if (isLoading.value) {
                                return;
                              }

                              isLoading.value = true;
                              error.value = null;

                              try {
                                await corbado.appendPasskey();
                                showSimpleNotification(
                                  Text(
                                    context
                                        .l10n
                                        .passkey_has_been_created_successfully,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  leading: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                  background: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                );
                              } on CorbadoError catch (e) {
                                error.value = e.translatedError;
                              } catch (e) {
                                error.value = e.toString();
                              } finally {
                                isLoading.value = false;
                              }
                            },
                            content: context.l10n.add_passkey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedTextButton(
                            onTap: context.pop,
                            content: context.l10n.back,
                          ),
                        ),
                      ],
                    ),
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
