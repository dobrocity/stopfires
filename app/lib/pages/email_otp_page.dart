import 'package:stopfires/auth_provider.dart';
import 'package:stopfires/pages/base_page.dart';
import 'package:stopfires/widgets/filled_text_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:otp_text_field/otp_text_field.dart';
import 'package:otp_text_field/style.dart';

class EmailOTPPage extends StatefulHookConsumerWidget {
  final String email;

  const EmailOTPPage({super.key, required this.email});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => EmailOTPPageState();
}

class EmailOTPPageState extends ConsumerState<EmailOTPPage> {
  final controller = OtpFieldController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Add a delay to ensure the widget is fully built before setting focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Add a small delay to ensure the OTP field is ready
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            try {
              controller.setFocus(0);
            } catch (e) {
              // Fallback: try to focus using the focus node
              _focusNode.requestFocus();
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final code = useState('');
    final errorMessage = useState<String?>(null);
    final isLoading = useState<bool>(false);

    return BasePage(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            Text(
              'Enter code',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'We just sent you a one time code to ${widget.email}. The code expires shortly, so please enter it soon.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),
            OTPTextField(
              controller: controller,
              length: 6,
              width: MediaQuery.of(context).size.width,
              fieldWidth: 45,
              style: Theme.of(context).textTheme.headlineMedium!,
              textFieldAlignment: MainAxisAlignment.spaceAround,
              fieldStyle: FieldStyle.box,
              otpFieldStyle: OtpFieldStyle(
                borderColor: Theme.of(context).colorScheme.primary,
                enabledBorderColor: Theme.of(context).colorScheme.primary,
              ),
              outlineBorderRadius: 20,
              contentPadding: const EdgeInsets.all(10),
              onChanged: (txt) {
                code.value = txt;
              },
              onCompleted: (pin) {
                // Handle completion
                code.value = pin;
              },
              keyboardType: TextInputType.number,
              inputFormatter: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 10),
            errorMessage.value != null
                ? Text(
                    errorMessage.value!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : Container(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledTextButton(
                content: 'Continue',
                isLoading: isLoading.value,
                onTap: () async {
                  // Clear focus before proceeding
                  _focusNode.unfocus();

                  isLoading.value = true;
                  final maybeError = await authService.finishLoginWithEmailOTP(
                    code.value,
                  );
                  if (maybeError != null) {
                    isLoading.value = false;
                    errorMessage.value = maybeError;
                    return;
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                // Clear focus before navigation
                _focusNode.unfocus();
                context.pop();
              },
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  'Back',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
