import 'package:corbado_auth/corbado_auth.dart';
import 'package:stopfires/config.dart';
import 'package:stopfires/screens/helper.dart';
import 'package:stopfires/widgets/filled_text_button.dart';
import 'package:stopfires/widgets/generic_error.dart';
import 'package:stopfires/widgets/outlined_text_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class PasskeyVerifyScreen extends HookWidget
    implements CorbadoScreen<PasskeyVerifyBlock> {
  @override
  final PasskeyVerifyBlock block;

  const PasskeyVerifyScreen(this.block, {super.key});

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final maybeError = block.error;
        if (maybeError != null) {
          showNotificationError(context, maybeError.translatedError);
        }
      });
      return null;
    }, [block.error]);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MaybeGenericError(message: block.error?.translatedError),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Text(
            context.l10n.passkey_verify_title,
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledTextButton(
            isLoading: block.data.primaryLoading,
            onTap: () async {
              await block.passkeyVerify();
            },
            content: context.l10n.passkey_verify_title,
          ),
        ),
        const SizedBox(height: 10),
        if (block.data.preferredFallback != null)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedTextButton(
              onTap: () => block.data.preferredFallback!.onTap(),
              content: block.data.preferredFallback!.label,
            ),
          )
        else
          Container(),
        const SizedBox(height: 10),
      ],
    );
  }
}
