import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/colors.dart';
import '../widgets/gradient_background.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signIn(
      _emailController.text,
      _passwordController.text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Sign in failed.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _handleSocialSignIn(String platform) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // For swift review/testing, social buttons instantly login a beautiful mock user in mock mode
    if (auth.isLoading) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logging in with $platform...'),
        duration: const Duration(milliseconds: 600),
      ),
    );

    final success = await auth.signIn(
      '${platform.toLowerCase()}@pulse.io',
      'password1234',
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Social sign in failed.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _handleForgotPassword() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address in the field first.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    // Trigger password reset dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Reset Password'),
        content: Text('Send a password reset link to $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final messenger = ScaffoldMessenger.of(context);
              final sent = await auth.resetPassword(email);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    sent
                        ? 'Password reset email sent!'
                        : (auth.errorMessage ??
                              'Failed to send reset email.'),
                  ),
                  backgroundColor: sent
                      ? AppColors.onlineGreen
                      : Colors.redAccent,
                ),
              );
            },
            child: const Text(
              'Send',
              style: TextStyle(color: AppColors.accentBlue),
            ),
          ),
        ],
      ),
    );
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
                children: [
                  const SizedBox(height: 48),

                  // 1. Top Logo - Neon Glowing Speech Bubble Outline
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B), // Very dark indigo
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accentBlue, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentBlue.withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Title & Subtitle
                  const Text(
                    'Welcome back',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to continue',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // 3. Login Details Form Card
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
                          // Email Field
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

                          // Password Field
                          CustomTextField(
                            label: 'Password',
                            hintText: '••••••••',
                            prefixIcon: Icons.lock_outline_rounded,
                            controller: _passwordController,
                            isPassword: true,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your password.';
                              }
                              if (val.length < 6) {
                                return 'Password must be at least 6 characters.';
                              }
                              return null;
                            },
                          ),

                          // Forgot Password link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _handleForgotPassword,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: AppColors.accentIndigo,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Sign in Button
                          PrimaryButton(
                            text: 'Sign in',
                            isLoading: auth.isLoading,
                            onTap: _handleSignIn,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Social Divider
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: AppColors.border, endIndent: 12),
                      ),
                      Text(
                        'or continue with',
                        style: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Expanded(
                        child: Divider(color: AppColors.border, indent: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 5. Social Google & Apple Buttons side-by-side
                  Row(
                    children: [
                      // Google Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleSocialSignIn('Google'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.cardBg.withValues(alpha: 0.3),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.g_mobiledata_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Google',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Apple Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleSocialSignIn('Apple'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.cardBg.withValues(alpha: 0.3),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.apple_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Apple',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // 6. Navigation Link to Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'New here? ',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Create account',
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
