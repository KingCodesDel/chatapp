import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.signIn(email: _emailCtrl.text, password: _passwordCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your email above first')));
      return;
    }
    try {
      await _authService.sendPasswordReset(_emailCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _socialComingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$provider sign-in isn\'t set up yet — use email for now')));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.xl * 2),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Welcome Back 👋', style: textTheme.displaySmall, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('Sign in to continue', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'Email or Username', prefixIcon: Icon(Icons.mail_outline_rounded)),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSecondary),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot Password?')),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFE85C5C), fontSize: 13)),
                    ),
                  GradientButton(label: 'Login', loading: _loading, onPressed: _loading ? null : _login),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.divider)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or continue with', style: textTheme.bodySmall),
                      ),
                      Expanded(child: Divider(color: AppColors.divider)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialButton(icon: Icons.g_mobiledata_rounded, onTap: _loading ? () {} : _googleSignIn),
                      const SizedBox(width: 16),
                      _SocialButton(icon: Icons.apple_rounded, onTap: () => _socialComingSoon('Apple')),
                      const SizedBox(width: 16),
                      _SocialButton(icon: Icons.facebook_rounded, onTap: () => _socialComingSoon('Facebook')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ", style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: const Text('Sign Up', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 24),
      ),
    );
  }
}
