import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../widgets/app_forms.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';

  void _updateState(VoidCallback fn) {
    if (!mounted) {
      return;
    }
    setState(fn);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _updateState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    final email = _emailController.text.trim();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _updateState(() {
        _successMessage =
            'If an account exists for $email, a password reset link has been sent.';
      });
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        _updateState(() {
          _successMessage =
              'If an account exists for $email, a password reset link has been sent.';
        });
      } else {
        _updateState(() => _errorMessage = _errorFor(error.code));
      }
    } catch (error) {
      debugPrint('Password reset failure: $error');
      _updateState(() {
        _errorMessage = 'Unable to send the reset link right now.';
      });
    } finally {
      _updateState(() => _isLoading = false);
    }
  }

  String _errorFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'network-request-failed':
        return 'A network connection is required to send the reset link.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return 'Unable to send the reset link right now.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.night, AppColors.forest],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed:
                                    _isLoading
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              const Expanded(
                                child: Text(
                                  'Recover password',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'Enter the email address tied to your CommunityShare account.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.mist,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AppTextField(
                            controller: _emailController,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                            ),
                            validator: (value) {
                              final email = (value ?? '').trim();
                              if (email.isEmpty) {
                                return 'Enter your email.';
                              }
                              if (!RegExp(
                                r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(email)) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          if (_errorMessage.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.coral.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                border: Border.all(
                                  color: AppColors.coral.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Text(
                                _errorMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.white),
                              ),
                            ),
                          ],
                          if (_successMessage.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.mint.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                border: Border.all(
                                  color: AppColors.mint.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                _successMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.white),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          AppPrimaryButton(
                            label: 'Send reset link',
                            isLoading: _isLoading,
                            onPressed: _sendResetLink,
                            icon: const Icon(Icons.mark_email_read_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
