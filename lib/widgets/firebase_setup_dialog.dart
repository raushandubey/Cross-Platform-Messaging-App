import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/colors.dart';
import '../providers/auth_provider.dart';

void showFirebaseSetupDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const FirebaseSetupDialog(),
  );
}

class FirebaseSetupDialog extends StatelessWidget {
  const FirebaseSetupDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber,
            size: 28,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Firebase Setup Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pulse couldn\'t connect to your Firebase database on Android. This happens when the Android API key is not configured or is restricted to other platforms in your Firebase Console.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can choose to switch to Offline Mock Mode to instantly test and experience all features of the application locally!',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              'How to configure your real Android database:',
              style: TextStyle(
                color: AppColors.accentBlue,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildStep('1. Go to your Firebase Console.'),
            _buildStep('2. Add an Android app with package name:\n   com.antigravity.pulse.pulse'),
            _buildStep('3. Download google-services.json.'),
            _buildStep('4. Copy the API Key and App ID into your\n   lib/firebase_options.dart file.'),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // Reinitialize AuthProvider with Mock Mode
            Provider.of<AuthProvider>(context, listen: false).enableMockMode();
          },
          style: TextButton.styleFrom(
            backgroundColor: AppColors.accentIndigo,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          child: const Text(
            'Go Offline (Mock Mode)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'Close',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.3,
        ),
      ),
    );
  }
}
