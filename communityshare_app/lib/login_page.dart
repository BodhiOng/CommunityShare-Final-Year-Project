import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app/app_routes.dart';
import 'app/app_router.dart';
import 'app/user_role.dart';
import 'constants.dart';
import 'widgets/app_forms.dart';

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

    setState(() {
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

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = UserRoleX.fromStorage(userDoc.data()?['role']?.toString());

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.shell,
        arguments: AppShellArguments(role: role),
      );
    } on FirebaseAuthException catch (error) {
      setState(() => _errorMessage = _getErrorMessage(error.code));
    } catch (error) {
      debugPrint('Login failure: $error');
      setState(() {
        _errorMessage = 'Unable to log in right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
