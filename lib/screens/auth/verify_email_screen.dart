import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _loading = false;
  bool _resending = false;

  @override
  void dispose() => super.dispose();

  Future<void> _verify() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyEmail();
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Verification failed')));
      auth.clearError();
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    final ok = await context.read<AuthProvider>().resendVerification();
    if (!mounted) return;
    setState(() => _resending = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Verification email sent!' : 'Failed to resend')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_unread_outlined,
                    size: 64, color: AppTheme.primary),
                const SizedBox(height: 16),
                Text('Verify Your Email',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                const SizedBox(height: 8),
                Text('We sent a verification email to ${auth.user?.email ?? "your email"}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 24),
                const Text(
                  'Open your inbox, click the verification link, then tap "I verified".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('I Verified'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _resending ? null : _resend,
                  child: Text(_resending ? 'Sending...' : 'Resend code'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
