import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'home.dart';
import 'dart:developer' as developer;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _libraryCardController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isButtonPressed = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Log loaded environment for debugging
    developer.log(
      'Loaded environment: ${dotenv.env['API_URL']}',
      name: 'login_page',
    );
  }

  @override
  void dispose() {
    _libraryCardController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    // Use environment variables for Basic Auth
    final String username = dotenv.env['API_USERNAME'] ?? 'admin';
    final String kohapassword = dotenv.env['API_PASSWORD'] ?? 'Zxcqwe123\$';
    final String basicAuth =
        'Basic ${base64.encode(utf8.encode('$username:$kohapassword'))}';

    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['API_URL']}/api/v1/auth/password/validation'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': basicAuth,
        },
        body: json.encode({
          'identifier': _libraryCardController.text,
          'password': _passwordController.text,
        }),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Parse response to get patron_id
          final responseBody = json.decode(response.body);
          final patronId = responseBody['patron_id']?.toString() ?? 'Unknown';

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Successfully Logged In'),
              content: const Text('Login successful'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomePage(
                          libraryCard: _libraryCardController.text,
                          patronId: patronId,
                        ),
                      ),
                    );
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unsuccessful'),
              content: const Text('Login failed'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unsuccessful'),
            content: const Text('Login failed'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/loginBG.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Container(
                        height: 60,
                        width: 60,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: const DecorationImage(
                            image: AssetImage('assets/icons/book.jpg'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        'AI Librarian',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: Colors.white, fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your Digital Knowledge Assistant',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Access your personalized library experience',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 320,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Library Access',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: const Color.fromARGB(
                                    221,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontSize: 20,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter your library credentials to continue',
                            style: TextStyle(
                              color: const Color.fromARGB(135, 255, 255, 255),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 280,
                            height: 36,
                            child: TextField(
                              controller: _libraryCardController,
                              decoration: InputDecoration(
                                labelText: 'Library Card Number',
                                labelStyle: TextStyle(
                                  color: const Color.fromARGB(
                                    137,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontSize: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.credit_card,
                                  color: const Color.fromARGB(
                                    135,
                                    255,
                                    255,
                                    255,
                                  ),
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: const Color.fromARGB(66, 0, 0, 0),
                                  ),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                              ),
                              style: TextStyle(
                                color: const Color.fromARGB(221, 255, 255, 255),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Usually found on the back of your library card',
                                style: TextStyle(
                                  color: const Color.fromARGB(
                                    96,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 280,
                            height: 36,
                            child: TextField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(
                                  color: const Color.fromARGB(
                                    137,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontSize: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock,
                                  color: const Color.fromARGB(
                                    135,
                                    255,
                                    255,
                                    255,
                                  ),
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: const Color.fromARGB(
                                      135,
                                      255,
                                      255,
                                      255,
                                    ),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                hintText: 'Enter your password',
                                hintStyle: TextStyle(
                                  color: const Color.fromARGB(
                                    96,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontSize: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: const Color.fromARGB(66, 0, 0, 0),
                                  ),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              style: TextStyle(
                                color: const Color.fromARGB(221, 255, 255, 255),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // Handle forgot password
                              },
                              child: Text(
                                'Forgot your password?',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 280,
                            height: 36,
                            child: GestureDetector(
                              onTapDown: (_) {
                                if (!_isLoading) {
                                  setState(() {
                                    _isButtonPressed = true;
                                  });
                                }
                              },
                              onTapUp: (_) {
                                if (!_isLoading) {
                                  setState(() {
                                    _isButtonPressed = false;
                                  });
                                  _login();
                                }
                              },
                              onTapCancel: () {
                                setState(() {
                                  _isButtonPressed = false;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  border: Border.all(
                                    color: _isButtonPressed
                                        ? Colors.orange
                                        : Colors.black26,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                              'assets/icons/book.jpg',
                                              height: 16,
                                              width: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Access Library',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              // Handle get library card
                            },
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: "Don't have a library card? ",
                                    style: TextStyle(
                                      color: const Color.fromARGB(
                                        221,
                                        255,
                                        255,
                                        255,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: "Get one here",
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 280,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.white70,
                                    thickness: 0.5,
                                    indent: 15,
                                    endIndent: 6,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0,
                                  ),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.white70,
                                    thickness: 0.5,
                                    indent: 6,
                                    endIndent: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: SizedBox(
                              width: 280,
                              height: 36,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const HomePage(),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.black26,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Continue as Guest (Limited Access)',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: true,
                          onChanged: (value) {
                            // Handle radio button change
                          },
                          activeColor: Colors.white70,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Your library data is protected with enterprise-grade security',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
