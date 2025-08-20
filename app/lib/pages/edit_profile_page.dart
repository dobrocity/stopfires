import 'package:corbado_auth/corbado_auth.dart';
import 'package:stopfires/auth_provider.dart';
import 'package:stopfires/config.dart';
import 'package:stopfires/screens/helper.dart';
import 'package:stopfires/widgets/filled_text_button.dart';
import 'package:stopfires/widgets/outlined_text_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:overlay_support/overlay_support.dart';

class EditProfilePage extends HookConsumerWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final corbado = ref.watch(corbadoProvider);

    final fullName = useTextEditingController(
      text: user.value!.corbado.username,
    );

    final email = useTextEditingController(text: user.value!.corbado.email);

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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.edit_profile,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextField(
                        controller: fullName,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: context.l10n.full_name,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextField(
                        controller: email,
                        enabled: false,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: context.l10n.email,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledTextButton(
                        isLoading: isLoading.value,
                        onTap: () async {
                          if (isLoading.value) {
                            return;
                          }

                          isLoading.value = true;
                          error.value = null;

                          try {
                            await corbado.changeUsername(
                              fullName: fullName.text,
                            );

                            showSimpleNotification(
                              Text(
                                context
                                    .l10n
                                    .full_name_has_been_changed_successfully,
                                style: TextStyle(color: Colors.white),
                              ),
                              leading: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              background: Theme.of(context).colorScheme.primary,
                            );
                          } on CorbadoError catch (e) {
                            error.value = e.translatedError;
                          } catch (e) {
                            error.value = e.toString();
                          } finally {
                            isLoading.value = false;
                          }
                        },
                        content: context.l10n.save_changes,
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
        ],
      ),
    );
  }
}
