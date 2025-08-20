import 'package:corbado_auth/corbado_auth.dart';
import 'package:stopfires/config.dart';
import 'package:stopfires/screens/helper.dart';
import 'package:stopfires/widgets/filled_text_button.dart';
import 'package:stopfires/widgets/outlined_text_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class EmailVerifyOtpScreen extends HookWidget
    implements CorbadoScreen<EmailVerifyBlock> {
  @override
  final EmailVerifyBlock block;

  const EmailVerifyOtpScreen(this.block, {super.key});

  @override
  Widget build(BuildContext context) {
    final otpController = useTextEditingController();

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
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Text(
            context.l10n.verify_email_address,
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            context.l10n.verify_email_address_description(block.data.email),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextField(
            controller: otpController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'XXXXXX',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledTextButton(
            isLoading: block.data.primaryLoading,
            onTap: () async {
              await block.submitOtpCode(otpController.text);
            },
            content: context.l10n.submit,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedTextButton(
            onTap: block.resendEmail,
            content: context.l10n.resend_code,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedTextButton(
            onTap: block.navigateToEditEmail,
            content: context.l10n.change_email,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
