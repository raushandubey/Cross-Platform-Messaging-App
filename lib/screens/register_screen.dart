import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/colors.dart';
import '../widgets/gradient_background.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../providers/auth_provider.dart';
import '../widgets/firebase_setup_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreeToTerms = false;

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must agree to the Terms of Service & Privacy Policy.',
          ),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signUp(
      _nameController.text,
      _emailController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      // Pop all views until we reach home (which switches to HomeScreen automatically due to auth listener!)
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (mounted) {
      if (auth.needsFirebaseSetup) {
        showFirebaseSetupDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Registration failed.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 700;

    return Scaffold(
      body: GradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 440 : size.width,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Back Button (Figma: '< Back' on the top left)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textMuted,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Back',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // 2. Title & Subtitle
                  const Text(
                    'Create account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join millions of users on Pulse',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // 3. Register Card Form
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg.withValues(alpha: 0.55),
                      borderRadius: const BorderRadius.all(Radius.circular(24)),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full Name field
                          CustomTextField(
                            label: 'Full name',
                            hintText: 'Arla Chen',
                            prefixIcon: Icons.person_outline_rounded,
                            controller: _nameController,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your name.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Email field
                          CustomTextField(
                            label: 'Email',
                            hintText: 'you@example.com',
                            prefixIcon: Icons.mail_outline_rounded,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your email.';
                              }
                              if (!val.contains('@')) {
                                return 'Please enter a valid email.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password field
                          CustomTextField(
                            label: 'Password',
                            hintText: 'Min. 8 characters',
                            prefixIcon: Icons.lock_outline_rounded,
                            controller: _passwordController,
                            isPassword: true,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter a password.';
                              }
                              if (val.length < 8) {
                                return 'Password must be at least 8 characters.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // 4. Terms of Service Checkbox (Custom glassmorphic checkbox)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _agreeToTerms = !_agreeToTerms;
                              });
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    color: _agreeToTerms
                                        ? AppColors.accentIndigo
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(6),
                                    ),
                                    border: Border.all(
                                      color: _agreeToTerms
                                          ? AppColors.accentIndigo
                                          : AppColors.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _agreeToTerms
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 14,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'I agree to the Terms of Service and Privacy Policy',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Create Account Button
                          PrimaryButton(
                            text: 'Create Account',
                            isLoading: auth.isLoading,
                            onTap: _handleRegister,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // 5. Already have an account link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            color: AppColors.accentIndigo,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
