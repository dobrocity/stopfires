import 'package:corbado_auth/corbado_auth.dart';
import 'package:stopfires/config.dart';
import 'package:stopfires/screens/helper.dart';
import 'package:stopfires/widgets/filled_text_button.dart';
import 'package:stopfires/widgets/outlined_text_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class EmailEditScreen extends HookWidget
    implements CorbadoScreen<EmailVerifyBlock> {
  @override
  final EmailVerifyBlock block;

  const EmailEditScreen(this.block, {super.key});

  @override
  Widget build(BuildContext context) {
    final email = block.data.email;

    final emailController = useTextEditingController(text: email);

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
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Text(
            context.l10n.edit_email_address,
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            context.l10n.insert_new_email_address,
            style: TextStyle(fontSize: 20),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextField(
            controller: emailController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: context.l10n.email_address,
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
              await block.updateEmail(emailController.text);
            },
            content: context.l10n.edit_email,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedTextButton(
            onTap: block.navigateToVerifyEmail,
            content: context.l10n.back,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
