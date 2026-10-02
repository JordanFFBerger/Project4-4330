import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLoginSuccess});

  final WidgetBuilder onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool hidePassword = true;

  String? message;
  bool successMessage = false;

  String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000";
    }

    return "http://10.0.2.2:3000";
  }

  Future<void> submit() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      showMessage("Enter a username and password.");
      return;
    }

    if (!isLogin && username.length < 3) {
      showMessage("Username must be at least 3 characters.");
      return;
    }

    if (!isLogin && password.length < 6) {
      showMessage("Password must be at least 6 characters.");
      return;
    }

    if (!isLogin && password != confirmPassword) {
      showMessage("Passwords do not match.");
      return;
    }

    setState(() {
      isLoading = true;
      message = null;
    });

    try {
      final endpoint = isLogin ? "/login" : "/register";

      final response = await http
          .post(
            Uri.parse("$baseUrl$endpoint"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"username": username, "password": password}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (isLogin && response.statusCode == 200) {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: widget.onLoginSuccess));
        return;
      }

      if (!isLogin && response.statusCode == 201) {
        setState(() {
          isLogin = true;
          isLoading = false;
          message = "Account created! Log in to continue.";
          successMessage = true;

          passwordController.clear();
          confirmPasswordController.clear();
        });

        return;
      }

      showMessage(data["message"] ?? "Something went wrong.");
    } catch (e) {
      if (!mounted) return;

      showMessage(
        "Could not connect to the server. Make sure the server is running.",
      );
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void showMessage(String text) {
    setState(() {
      message = text;
      successMessage = false;
      isLoading = false;
    });
  }

  void switchMode() {
    setState(() {
      isLogin = !isLogin;
      message = null;
      successMessage = false;

      confirmPasswordController.clear();
    });
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE6EAD9),
                  Color(0xFFF7F2E8),
                  Color(0xFFE5D1B4),
                ],
              ),
            ),
          ),

          const Positioned(
            top: 50,
            left: -30,
            child: Icon(
              Icons.catching_pokemon,
              size: 220,
              color: Color(0x19496451),
            ),
          ),

          const Positioned(
            bottom: 30,
            right: -40,
            child: Icon(
              Icons.catching_pokemon,
              size: 260,
              color: Color(0x19496451),
            ),
          ),

          const Positioned(
            top: 120,
            right: 30,
            child: Icon(
              Icons.auto_stories_outlined,
              size: 90,
              color: Color(0x55496451),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PokeballLogo(),

                      const SizedBox(height: 18),

                      Text(
                        isLogin
                            ? "Welcome Back, Trainer!"
                            : "Create Trainer Account",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        isLogin
                            ? "Your next encounter belongs in a photobook."
                            : "Create an account and begin your journey.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 24),

                      TextField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          labelText: "Username",
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: const Color(0xFFF2EEE4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: passwordController,
                        obscureText: hidePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              hidePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                hidePassword = !hidePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF2EEE4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      if (!isLogin) ...[
                        const SizedBox(height: 14),

                        TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "Confirm Password",
                            prefixIcon: const Icon(
                              Icons.verified_user_outlined,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF2EEE4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],

                      if (message != null) ...[
                        const SizedBox(height: 14),

                        Text(
                          message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: successMessage ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  isLogin ? "Log In" : "Create Account",
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: isLoading ? null : switchMode,
                        child: Text(
                          isLogin
                              ? "New trainer? Create an account"
                              : "Already have an account? Log in",
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Continue as guest'),
                        onPressed: isLoading
                            ? null
                            : () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: widget.onLoginSuccess,
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PokeballLogo extends StatelessWidget {
  const PokeballLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 85,
      height: 85,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.red, Colors.red, Colors.white, Colors.white],
          stops: [0, 0.48, 0.52, 1],
        ),
        border: Border.all(color: Colors.black87, width: 5),
      ),
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black87, width: 5),
          ),
        ),
      ),
    );
  }
}
