import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

/// Authentication screen with Sign In / Sign Up toggle.
/// Matches the React AuthScreen component.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _hearingLossLevel = '';
  String _deviceBrand = '';
  final _deviceModelController = TextEditingController();

  late AnimationController _logoController;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _logoAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _deviceModelController.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _error = null;
    });
  }

  Future<void> _handleSubmit() async {
    setState(() => _error = null);

    // Validation
    if (_isSignUp) {
      if (_nameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _passwordController.text.isEmpty) {
        setState(() => _error = 'Please fill in all required fields');
        return;
      }
      if (_passwordController.text.length < 6) {
        setState(() => _error = 'Password must be at least 6 characters');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _error = 'Passwords do not match');
        return;
      }
      if (_hearingLossLevel.isEmpty) {
        setState(() => _error = 'Please select your hearing loss level');
        return;
      }
      if (_deviceBrand.isEmpty) {
        setState(() => _error = 'Please select your device brand');
        return;
      }
    } else {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        setState(() => _error = 'Email and password are required');
        return;
      }
    }

    setState(() => _loading = true);

    if (!mounted) return;

    final provider = context.read<AppProvider>();

    try {
      bool success;
      if (_isSignUp) {
        success = await provider.signupWithCredentials(
          _nameController.text,
          _emailController.text,
          _passwordController.text,
        );
      } else {
        success = await provider.loginWithCredentials(
          _emailController.text,
          _passwordController.text,
        );
      }

      if (!success && mounted) {
        setState(() {
          _error = _isSignUp
              ? 'Failed to create account. Try a different email.'
              : 'Invalid email or password.';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Connection error. Is the backend running?';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HCColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Animated logo
              ScaleTransition(
                scale: _logoAnimation,
                child: const Text('👂', style: TextStyle(fontSize: 64)),
              ),
              const SizedBox(height: 12),
              const Text(
                'HearClear',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: HCColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Context-Aware Hearing Companion',
                style: TextStyle(
                  fontSize: 14,
                  color: HCColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // Toggle buttons
              Container(
                decoration: BoxDecoration(
                  color: HCColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HCColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ToggleButton(
                        label: 'Sign In',
                        isActive: !_isSignUp,
                        onTap: () {
                          if (_isSignUp) _switchMode();
                        },
                      ),
                    ),
                    Expanded(
                      child: _ToggleButton(
                        label: 'Sign Up',
                        isActive: _isSignUp,
                        onTap: () {
                          if (!_isSignUp) _switchMode();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isSignUp ? _buildSignUpForm() : _buildSignInForm(),
              ),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HCColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: HCColors.danger, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HCColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isSignUp ? 'Create Account' : 'Sign In',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              if (!_isSignUp) ...[
                const SizedBox(height: 16),
                Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 13,
                    color: HCColors.primaryLight.withValues(alpha: 0.7),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Footer
              const Text(
                'Stevens Institute of Technology',
                style: TextStyle(fontSize: 12, color: HCColors.textSecondary),
              ),
              const SizedBox(height: 2),
              const Text(
                'CS545B · Bridging the Gap',
                style: TextStyle(fontSize: 11, color: HCColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInForm() {
    return Column(
      key: const ValueKey('signin'),
      children: [
        _buildField(
          label: 'Email',
          icon: '📧',
          controller: _emailController,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildField(
          label: 'Password',
          icon: '🔒',
          controller: _passwordController,
          hint: '••••••••',
          obscure: true,
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      key: const ValueKey('signup'),
      children: [
        _buildField(
          label: 'Full Name',
          icon: '👤',
          controller: _nameController,
          hint: 'John Doe',
        ),
        const SizedBox(height: 14),
        _buildField(
          label: 'Email',
          icon: '📧',
          controller: _emailController,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildField(
          label: 'Password',
          icon: '🔒',
          controller: _passwordController,
          hint: '••••••••',
          obscure: true,
        ),
        const SizedBox(height: 14),
        _buildField(
          label: 'Confirm Password',
          icon: '🔒',
          controller: _confirmPasswordController,
          hint: '••••••••',
          obscure: true,
        ),
        const SizedBox(height: 14),
        _buildDropdown(
          label: 'Hearing Loss Level',
          value: _hearingLossLevel.isEmpty ? null : _hearingLossLevel,
          hint: 'Select your level...',
          items: const ['Mild', 'Moderate', 'Severe', 'Profound', 'Unsure'],
          onChanged: (v) => setState(() => _hearingLossLevel = v ?? ''),
        ),
        const SizedBox(height: 14),
        _buildDropdown(
          label: 'Device Brand',
          value: _deviceBrand.isEmpty ? null : _deviceBrand,
          hint: 'Select a brand...',
          items: const [
            'Cochlear',
            'Phonak',
            'Oticon',
            'ReSound',
            'Starkey',
            'Widex',
            'Other'
          ],
          onChanged: (v) => setState(() => _deviceBrand = v ?? ''),
        ),
        const SizedBox(height: 14),
        _buildField(
          label: 'Device Model (Optional)',
          icon: '🎧',
          controller: _deviceModelController,
          hint: 'e.g., Nucleus 7',
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required String icon,
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: HCColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          enabled: !_loading,
          style: const TextStyle(fontSize: 14, color: HCColors.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Text(icon, style: const TextStyle(fontSize: 16)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            hintText: hint,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: HCColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: HCColors.bgDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HCColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(hint,
                  style:
                      const TextStyle(color: HCColors.textSecondary, fontSize: 14)),
              isExpanded: true,
              dropdownColor: HCColors.bgCard,
              style: const TextStyle(color: HCColors.textPrimary, fontSize: 14),
              items: items
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: _loading ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? HCColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : HCColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
