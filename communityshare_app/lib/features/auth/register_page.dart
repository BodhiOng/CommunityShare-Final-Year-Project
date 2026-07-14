import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../constants.dart';
import '../../widgets/app_forms.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _recipientTypeController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  String _selectedRole = 'recipient';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _errorMessage = '';

  bool get _isRecipient => _selectedRole == 'recipient';
  bool get _isHub => _selectedRole == 'hub';

  void _updateState(VoidCallback fn) {
    if (!mounted) {
      return;
    }
    setState(fn);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _recipientTypeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _updateState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      await _functions.httpsCallable('registerUser').call({
        'fullName': _fullNameController.text.trim(),
        'email': email,
        'password': password,
        'role': _selectedRole,
        if (_isRecipient) 'recipientType': _recipientTypeController.text.trim(),
      });

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (!mounted) {
        return;
      }

      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.auth, (route) => false);
    } on FirebaseFunctionsException catch (error) {
      _updateState(() => _errorMessage = _functionErrorMessage(error));
    } on FirebaseAuthException catch (error) {
      _updateState(() => _errorMessage = _authErrorMessage(error.code));
    } catch (error) {
      debugPrint('Registration failure: $error');
      _updateState(() {
        _errorMessage = 'Unable to create your account right now.';
      });
    } finally {
      _updateState(() => _isLoading = false);
    }
  }

  String _functionErrorMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'already-exists':
        return 'An account already exists for this email.';
      case 'invalid-argument':
        return error.message ?? 'Please review the form details and try again.';
      case 'unavailable':
        return 'Signup is temporarily unavailable. Please try again.';
      default:
        return error.message ?? 'Unable to create your account right now.';
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
        return 'The new account was created, but automatic sign-in failed.';
      case 'network-request-failed':
        return 'Account created, but sign-in needs a stable network connection.';
      default:
        return 'Account created, but sign-in could not be completed.';
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
                constraints: const BoxConstraints(maxWidth: 540),
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
                                  'Create account',
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
                          const SizedBox(height: AppSpacing.xl),
                          AppTextField(
                            controller: _fullNameController,
                            label: 'Full Name',
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Enter your full name.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
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
                          const SizedBox(height: AppSpacing.md),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              prefixIcon: Icon(
                                Icons.admin_panel_settings_outlined,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'donor',
                                child: Text('Donor'),
                              ),
                              DropdownMenuItem(
                                value: 'recipient',
                                child: Text('Recipient'),
                              ),
                              DropdownMenuItem(
                                value: 'hub',
                                child: Text('Community Hub'),
                              ),
                            ],
                            onChanged:
                                _isLoading
                                    ? null
                                    : (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setState(() {
                                        _selectedRole = value;
                                      });
                                    },
                          ),
                          if (_isRecipient) ...[
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              controller: _recipientTypeController,
                              label: 'Recipient Type',
                              hint: 'Individual, Family, NGO, Shelter...',
                              prefixIcon: const Icon(Icons.groups_2_outlined),
                              validator: (value) {
                                if (!_isRecipient) {
                                  return null;
                                }
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Enter the recipient type.';
                                }
                                return null;
                              },
                            ),
                          ],
                          if (_isHub) ...[
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'Hub details can be completed later from your profile while the account is inactive.',
                              style: TextStyle(
                                color: AppColors.mist,
                                height: 1.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _passwordController,
                            label: 'Password',
                            obscureText: _obscurePassword,
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').length < 6) {
                                return 'Use at least 6 characters.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            obscureText: _obscureConfirmPassword,
                            prefixIcon: const Icon(Icons.lock_reset_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return 'Passwords do not match.';
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
                          const SizedBox(height: AppSpacing.lg),
                          AppPrimaryButton(
                            label: 'Create account',
                            isLoading: _isLoading,
                            onPressed: _register,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
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
