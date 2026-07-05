import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../ui/app_theme.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Mock accounts for the dropdown
  final List<Map<String, String>> _availableUsers = [
    {'email': 'test@looped.com', 'password': 'password123'},
    {'email': 'admin@looped.com', 'password': 'admin123'},
    {'email': 'gero@looped.com', 'password': 'gero123'},
    {'email': 'dj@looped.com', 'password': 'djpass123'},
    {'email': 'user1@looped.com', 'password': 'user1pass'},
  ];

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      if (_isLogin) {
        await auth.login(_emailController.text, _passwordController.text);
      } else {
        await auth.register(_emailController.text, _passwordController.text,
            _usernameController.text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (kDebugMode) ...[
                  // Available Users Dropdown (White Card)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: const Icon(Icons.arrow_right_rounded, color: Colors.black, size: 30),
                        title: Text(
                          'Usuarios disponibles (${_availableUsers.length})',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                        ),
                        iconColor: Colors.black,
                        collapsedIconColor: Colors.black,
                        children: _availableUsers.map((user) {
                          return ListTile(
                            title: Text(user['email']!, style: const TextStyle(color: Colors.black, fontSize: 14)),
                            onTap: () {
                              setState(() {
                                _emailController.text = user['email']!;
                                _passwordController.text = user['password']!;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Infinity Logo
                const Icon(
                  Icons.all_inclusive, // Infinity icon
                  size: 64,
                  color: AppTheme.accent,
                ),
                const SizedBox(height: 32),

                // Welcome texts
                Text(
                  _isLogin ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
                  style: AppTheme.displayMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin ? 'Baila para superarte' : 'Únete a la comunidad LOOPED',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),

                // Inputs
                if (!_isLogin) ...[
                  _buildTextField(
                    controller: _usernameController,
                    hint: 'Nombre de usuario',
                  ),
                  const SizedBox(height: 16),
                ],
                _buildTextField(
                  controller: _emailController,
                  hint: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordController,
                  hint: 'Contraseña',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Iniciar Sesion Button
                CtaButton(
                  label: _isLogin ? 'INICIAR SESIÓN' : 'CREAR CUENTA',
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _submit,
                ),
                const SizedBox(height: 24),

                // Forgot password
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    );
                  },
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 32),

                // Divider "O continuar con"
                Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.surfaceBorder)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'O continuar con',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ),
                    Expanded(child: Divider(color: AppTheme.surfaceBorder)),
                  ],
                ),
                const SizedBox(height: 24),

                // Social buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          setState(() => _isLoading = true);
                          try {
                            final auth = Provider.of<AuthService>(context, listen: false);
                            await auth.loginWithGoogle();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Google Login Error: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppTheme.surfaceBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Google',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppTheme.surfaceBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.apple, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Apple',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // Registrarse
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      text: _isLogin ? '¿No tienes una cuenta? ' : '¿Ya tienes una cuenta? ',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      children: [
                        TextSpan(
                          text: _isLogin ? 'Crear cuenta' : 'Iniciar sesión',
                          style: const TextStyle(
                              color: AppTheme.accent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.surfaceLight, // Dark grey
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      ),
    );
  }
}
