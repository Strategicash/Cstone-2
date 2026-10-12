import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_client.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import '../screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _googleInitialized = false;

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please enter email and password';
        });
        return;
      }

      try {
        final response = await ApiClient.post('api_login.php', {
          'email': _emailController.text,
          'password': _passwordController.text,
        });

        final data = jsonDecode(response.body);

        setState(() {
          _isLoading = false;
        });

        if (data['success'] == true) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(loginData: data),
            ),
          );
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Login failed';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Could not connect to server';
          _isLoading = false;
        });
      }
    }
  }

  void _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: '34344699875-uha53979akadbaaufru02d9dq0mga6s7.apps.googleusercontent.com',
        );
        _googleInitialized = true;
      }
      final GoogleSignInAccount? account;
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        account = await GoogleSignIn.instance.authenticate();
      } else {
        account = await GoogleSignIn.instance
            .attemptLightweightAuthentication();
      }
      debugPrint('Google Sign-In success: ${account?.email}');
      if (!mounted) return;
      if (account == null) {
        setState(() => _errorMessage = 'Google sign-in was cancelled');
        return;
      }
      final email = account.email;
      final displayName = account.displayName ?? email.split('@').first;

      // Exchange the Google identity for a backend user row so the
      // dashboard has a real `users.id` for all api_get_* queries.
      // UserMetrics.fromLoginPayload reads `id`/`user_id` from this map.
      late final Map<String, dynamic> backendUser;
      try {
        final response = await ApiClient.post('api_google_login.php', {
          'email': email,
          'full_name': displayName,
        });
        final data = jsonDecode(response.body);
        if (data['success'] != true || data['user'] is! Map) {
          throw Exception(data['message'] ?? 'Google login failed');
        }
        backendUser = Map<String, dynamic>.from(data['user'] as Map);
        // Forward the Google avatar so the drawer can show it; the PHP
        // backend has no photo column and never returns one itself.
        final googlePhotoUrl = account.photoUrl;
        if (googlePhotoUrl != null && googlePhotoUrl.isNotEmpty) {
          backendUser['photo_url'] = googlePhotoUrl;
        }
      } catch (e) {
        debugPrint('Backend Google login failed: $e');
        if (!mounted) return;
        setState(
          () => _errorMessage = 'Google sign-in succeeded but the backend account could not be linked. Check your connection and try again.',
        );
        _showSnackBar('Backend unavailable — could not link Google account.');
        return;
      }

      if (!mounted) return;
      _showSnackBar('Signed in as $email');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              HomeScreen(loginData: {'success': true, 'user': backendUser}),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Google Sign-In error: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => _errorMessage = 'Google sign-in failed: $e');
      _showSnackBar('Google sign-in failed. See debug console for details.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.fitness_center,
                  size: 64,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'FitX Training Club',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    errorMaxLines: 2,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                  onEditingComplete: () {
                    FocusScope.of(context).nextFocus();
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    errorMaxLines: 2,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    return null;
                  },
                  onEditingComplete: () {
                    FocusScope.of(context).nextFocus();
                  },
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Log In'),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(),
                const SizedBox(width: 8),
                Text('OR'),
                const SizedBox(width: 8),
                Divider(),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text("Don't have an account? Sign Up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
