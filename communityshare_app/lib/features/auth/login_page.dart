import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_router.dart';
import '../../app/user_role.dart';
import '../../app/user_role_resolver.dart';
import '../../constants.dart';
import '../../widgets/app_forms.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  void _updateState(VoidCallback fn) {
    if (!mounted) {
      return;
    }
    setState(fn);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _updateState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user == null || !mounted) {
        return;
      }

      final role = await UserRoleResolver.resolve(user);

      if (!mounted) return;
      final route = role == UserRole.donor
          ? AppRoutes.shell
          : AppRoutes.shell;
      final arguments = role == UserRole.donor
          ? const AppShellArguments(role: UserRole.donor, initialIndex: 0)
          : AppShellArguments(role: role, initialIndex: 0);

      if (!mounted) return;
      await Navigator.of(context).pushNamedAndRemoveUntil(
        route,
        (route) => false,
        arguments: arguments,
      );
    } on FirebaseAuthException catch (error) {
      _updateState(() => _errorMessage = _getErrorMessage(error.code));
    } catch (error) {
      debugPrint('Login failure: $error');
      _updateState(() {
        _errorMessage = 'Unable to log in right now. Please try again.';
      });
    } finally {
      _updateState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account was found for this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Your email or password is incorrect.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return 'Login failed. Please try again.';
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
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 88,
                              height: 88,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.mint.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Image.asset('assets/logo.png'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const Text(
                            AppCopy.appName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            AppCopy.tagline,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.mist, height: 1.5),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AppTextField(
                            controller: _emailController,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(Icons.alternate_email_rounded),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your email.';
                              }
                              if (!RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value.trim())) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
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
                              if (value == null || value.isEmpty) {
                                return 'Enter your password.';
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
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: Border.all(
                                  color: AppColors.coral.withValues(alpha: 0.35),
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
                            label: 'Log in',
                            isLoading: _isLoading,
                            onPressed: _login,
                            icon: const Icon(Icons.login_rounded),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'Sign up and recovery flows can be wired onto this shell next.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.mist),
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
