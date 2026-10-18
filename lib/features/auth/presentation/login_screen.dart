import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../shell/main_shell.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepo = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final pass = _passwordController.text.trim();

    if (phone.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = "يرجى كتابة رقم الهاتف وكلمة المرور.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authRepo.login(phone, pass);

      if (!mounted) return;

      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      }

      // Always safely navigate using own active context
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll("Exception:", "").trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/tayyar-logo.png',
                    width: 150,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.delivery_dining,
                      size: 54,
                      color: AppColors.primaryMint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "بوابة دخول الكباتن",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "سجّل دخولك لبدء استلام وتوصيل الطلبات",
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 24),

                  // Login Box
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF450A0A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFFCA5A5), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        const Text(
                          "رقم الهاتف",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          cursorColor: AppColors.primaryMint,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            hintText: "أدخل رقم الهاتف المسجل...",
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            prefixIcon: const Icon(Icons.phone_iphone, size: 18, color: AppColors.primaryMint),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primaryMint, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          "كلمة المرور / الكود السري",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          cursorColor: AppColors.primaryMint,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            hintText: "أدخل كلمة المرور...",
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppColors.primaryMint),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                size: 18,
                                color: const Color(0xFF94A3B8),
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primaryMint, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryMint,
                            foregroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Color(0xFF0F172A),
                                  ),
                                )
                              : const Text(
                                  "دخول وبدء الوردية",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    "للانضمام لأسطول طياري في ثواني، تواصل مع المشرف: 01034293703",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
