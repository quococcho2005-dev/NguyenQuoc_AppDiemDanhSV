import 'dart:convert';

import 'package:flutter/material.dart';

import 'face_recognition.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

const apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://42-96-2-9.sslip.io',
);
const store = FlutterSecureStorage();
const ink = Color(0xFF172B4D),
    teal = Color(0xFF087E8B),
    canvas = Color(0xFFF4F7FA);

void main() => runApp(const RollCallApp());

class Api {
  static Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
    final uri = Uri.parse('$apiBase$path');
    final req = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    if (token != null && token.isNotEmpty)
      req.headers['Authorization'] = 'Bearer $token';
    final response = await http.Response.fromStream(
      await req.send().timeout(const Duration(seconds: 25)),
    );
    final data = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400)
      throw Exception(
        data is Map
            ? (data['message'] ?? 'Lỗi ${response.statusCode}')
            : 'Lỗi ${response.statusCode}',
      );
    return data;
  }

  static Future<dynamic> get(String path, String token) =>
      request('GET', path, token: token);
  static Future<dynamic> post(String path, Object body, String token) =>
      request('POST', path, body: body, token: token);
}

class RollCallApp extends StatefulWidget {
  const RollCallApp({super.key});
  @override
  State<RollCallApp> createState() => _RollCallAppState();
}

// Keeps the default Flutter test entry point name available for IDE tooling.
class MyApp extends RollCallApp {
  const MyApp({super.key});
}

class _RollCallAppState extends State<RollCallApp> {
  Map<String, dynamic>? user;
  String? token;
  String? startupError;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    // Paint the sign-in page before invoking native secure storage. Some
    // emulator/API combinations can stall the platform channel during startup.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    try {
      token = await store
          .read(key: 'token')
          .timeout(const Duration(seconds: 5));
      final raw = await store
          .read(key: 'user')
          .timeout(const Duration(seconds: 5));
      if (raw != null) user = Map<String, dynamic>.from(jsonDecode(raw));
      if (token == null || user == null) {
        token = null;
        user = null;
      }
    } catch (e) {
      token = null;
      user = null;
      startupError =
          'Không đọc được phiên đăng nhập đã lưu. Hãy đăng nhập lại.';
      debugPrint('Session restore failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> signedIn(String t, Map<String, dynamic> u) async {
    token = t;
    user = u;
    await store.write(key: 'token', value: t);
    await store.write(key: 'user', value: jsonEncode(u));
    if (mounted) setState(() => {});
  }

  Future<void> signOut() async {
    await store.deleteAll();
    token = null;
    user = null;
    if (mounted) setState(() => {});
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BaKhi Điểm Danh',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        surface: Colors.white,
        primary: teal,
        secondary: const Color(0xFF45B8A9),
        error: const Color(0xFFBA3A45),
      ),
      fontFamily: 'Roboto',
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: ink),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0x100F2F46),
        margin: const EdgeInsets.only(bottom: 14),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE7EEF2)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: const TextStyle(color: Color(0xFF68798C)),
        prefixIconColor: const Color(0xFF718498),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E9EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E9EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: teal, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFBA3A45)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFBA3A45), width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          side: const BorderSide(color: Color(0xFFD4E0E6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDDF4F0),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: teal,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 40,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEBF0F3),
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEAF4F4),
        selectedColor: const Color(0xFFD9F1EC),
        side: const BorderSide(color: Color(0xFFDCE9E9)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: ink),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? teal : null,
        ),
      ),
    ),
    home: loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : user == null
        ? LoginPage(onSignedIn: signedIn, startupError: startupError)
        : HomePage(user: user!, token: token!, onSignOut: signOut),
  );
}

void notice(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.toString().replaceFirst('Exception: ', '')),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String roleName(String? r) => switch (r) {
  'admin' => 'Quản trị viên',
  'teacher' => 'Giảng viên',
  _ => 'Sinh viên',
};
String textOf(dynamic v, [String fallback = '—']) =>
    v == null || v.toString().isEmpty ? fallback : v.toString();
List<Map<String, dynamic>> mapList(dynamic raw) {
  if (raw is List)
    return raw
        .whereType<Map>()
        .map((x) => Map<String, dynamic>.from(x))
        .toList();
  if (raw is Map && raw['items'] is List) return mapList(raw['items']);
  return [];
}

class PageBanner extends StatelessWidget {
  const PageBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE5F5F2), Color(0xFFF1F7F8)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFD8ECE8)),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: teal, size: 25),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF607486),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onSignedIn, this.startupError});
  final Future<void> Function(String, Map<String, dynamic>) onSignedIn;
  final String? startupError;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController(), password = TextEditingController();
  bool busy = false, hide = true;
  String? error;
  Future<void> faceLogin() async {
    if (username.text.trim().isEmpty) {
      notice(context, 'Nhập tên đăng nhập hoặc email trước.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final embedding = await FaceRecognition.captureEmbedding();
      final data = await Api.request(
        'POST',
        '/api/auth/face-login',
        body: {'username': username.text.trim(), 'embedding': embedding},
      );
      await widget.onSignedIn(
        data['token'].toString(),
        Map<String, dynamic>.from(data['user']),
      );
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> login() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final c = await Api.request(
        'POST',
        '/api/auth/login',
        body: {
          'username': username.text.trim(),
          'password': password.text,
          'otpChannel': 'email',
        },
      );
      if (c is! Map) {
        throw Exception('Phản hồi đăng nhập không hợp lệ.');
      }

      // Demo accounts (and accounts without OTP enabled) may be returned as
      // an authenticated session immediately. Keep the same session setup and
      // role-based navigation used after OTP verification.
      final directToken = c['token']?.toString();
      if (directToken != null && directToken.isNotEmpty) {
        final rawUser = c['user'];
        if (rawUser is! Map) {
          throw Exception('API đăng nhập thiếu thông tin người dùng.');
        }
        await widget.onSignedIn(
          directToken,
          Map<String, dynamic>.from(rawUser),
        );
        return;
      }

      final ticket = c['ticket']?.toString();
      if (ticket == null || ticket.isEmpty) {
        throw Exception('API không trả token hoặc ticket xác thực OTP.');
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpPage(
            ticket: ticket,
            devCode: c['devCode']?.toString(),
            purpose: textOf(c['purpose']),
            onVerified: widget.onSignedIn,
          ),
        ),
      );
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF6F5), Color(0xFFF5F7FA), Color(0xFFF8FAFC)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 4,
                shadowColor: const Color(0x220B5661),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0C9A9A), Color(0xFF086575)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33087E8B),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fact_check_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Xin chào 👋',
                        style: TextStyle(
                          color: ink,
                          fontSize: 31,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Đăng nhập để tiếp tục điểm danh',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      Form(
                        key: form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: username,
                              decoration: const InputDecoration(
                                labelText: 'Tên đăng nhập hoặc email',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Nhập tài khoản'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: password,
                              obscureText: hide,
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => hide = !hide),
                                  icon: Icon(
                                    hide
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Nhập mật khẩu'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      if (error != null || widget.startupError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            error ?? widget.startupError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: busy ? null : login,
                          child: busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Đăng nhập',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : faceLogin,
                          icon: const Icon(Icons.face_retouching_natural),
                          label: const Text('Đăng nhập bằng khuôn mặt'),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Center(
                        child: Text(
                          'Mã OTP sẽ được gửi đến email tài khoản',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: busy
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RegisterPage(
                                      onSignedIn: widget.onSignedIn,
                                    ),
                                  ),
                                ),
                          child: const Text(
                            'Chưa có tài khoản? Đăng ký sinh viên',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.onSignedIn});
  final Future<void> Function(String, Map<String, dynamic>) onSignedIn;
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final studentCode = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool busy = false, hidePassword = true;

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    email.dispose();
    studentCode.dispose();
    phone.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final challenge = await Api.request(
        'POST',
        '/api/auth/register',
        body: {
          'username': username.text.trim(),
          'email': email.text.trim(),
          'password': password.text,
          'fullName': name.text.trim(),
          if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
          if (studentCode.text.trim().isNotEmpty)
            'studentCode': studentCode.text.trim(),
        },
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpPage(
            ticket: challenge['ticket'].toString(),
            devCode: challenge['devCode']?.toString(),
            purpose: textOf(challenge['purpose'], 'verify-email'),
            onVerified: widget.onSignedIn,
          ),
        ),
      );
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đăng ký tài khoản sinh viên')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF163B58), Color(0xFF087E8B)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A087E8B),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: Color(0x33FFFFFF),
                  child: Icon(
                    Icons.person_add_alt_1,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tạo tài khoản',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Mã xác minh sẽ được gửi đến email của bạn.',
                        style: TextStyle(
                          color: Color(0xFFD8F1F0),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Họ và tên',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nhập họ và tên' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: username,
            decoration: const InputDecoration(
              labelText: 'Tên đăng nhập',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.trim().length < 3
                ? 'Tên đăng nhập cần ít nhất 3 ký tự'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || !RegExp(r'^.+@.+\..+$').hasMatch(v.trim())
                ? 'Nhập email hợp lệ'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: studentCode,
            decoration: const InputDecoration(
              labelText: 'Mã sinh viên (nếu có)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại (không bắt buộc)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: password,
            obscureText: hidePassword,
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => hidePassword = !hidePassword),
                icon: Icon(
                  hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (v) => v == null || v.length < 8
                ? 'Mật khẩu cần ít nhất 8 ký tự'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: confirmPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nhập lại mật khẩu',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v != password.text ? 'Mật khẩu nhập lại chưa khớp' : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: busy ? null : register,
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Tạo tài khoản'),
            ),
          ),
        ],
      ),
    ),
  );
}

class OtpPage extends StatefulWidget {
  const OtpPage({
    super.key,
    required this.ticket,
    this.devCode,
    this.purpose,
    required this.onVerified,
  });
  final String ticket;
  final String? devCode, purpose;
  final Future<void> Function(String, Map<String, dynamic>) onVerified;
  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  late final TextEditingController code;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    code = TextEditingController(text: widget.devCode ?? '');
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    if (code.text.trim().length != 6) {
      notice(context, 'Mã OTP gồm 6 chữ số');
      return;
    }
    setState(() => busy = true);
    try {
      final data = await Api.post('/api/auth/verify-otp', {
        'ticket': widget.ticket,
        'code': code.text.trim(),
      }, '');
      await widget.onVerified(
        data['token'].toString(),
        Map<String, dynamic>.from(data['user']),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageBanner(
            icon: Icons.mark_email_read_outlined,
            title: 'Xác minh OTP',
            subtitle: widget.purpose == 'verify-email'
                ? 'Xác thực email để hoàn tất đăng nhập.'
                : 'Nhập mã 6 số được gửi đến bạn.',
          ),
          const SizedBox(height: 10),
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Mã OTP',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.password),
            ),
            onSubmitted: (_) => verify(),
          ),
          if (widget.devCode != null)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE5F5F2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: teal, size: 19),
                  SizedBox(width: 8),
                  Text(
                    'Mã phát triển đã được tự điền.',
                    style: TextStyle(color: teal, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: busy ? null : verify,
              child: busy
                  ? const CircularProgressIndicator()
                  : const Text('Xác nhận'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.user,
    required this.token,
    required this.onSignOut,
  });
  final Map<String, dynamic> user;
  final String token;
  final Future<void> Function() onSignOut;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  List<Map<String, dynamic>> classes = [];
  bool busy = true;
  String? error;
  String get role => textOf(widget.user['role'], 'student');
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      classes = mapList(await Api.get('/api/classes', widget.token));
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Trang chủ', 'Lớp học', 'Cá nhân'];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[tab],
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'out') widget.onSignOut();
              if (v == 'profile')
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProfilePage(user: widget.user, token: widget.token),
                  ),
                );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('Hồ sơ')),
              PopupMenuItem(value: 'out', child: Text('Đăng xuất')),
            ],
          ),
        ],
      ),
      body: tab == 2
          ? ProfileSummary(
              user: widget.user,
              onProfile: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProfilePage(user: widget.user, token: widget.token),
                ),
              ),
            )
          : tab == 1
          ? classList()
          : dashboard(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Lớp học',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }

  Widget dashboard() => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4ECEF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D102D3D),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0C9A9A), Color(0xFF086575)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    textOf(
                          widget.user['fullName'],
                          widget.user['username']?.toString() ?? 'B',
                        )
                        .trim()
                        .split(RegExp(r'\s+'))
                        .take(2)
                        .map((part) => part.isEmpty ? '' : part[0])
                        .join()
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'XIN CHÀO,',
                      style: TextStyle(
                        color: teal,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      textOf(
                        widget.user['fullName'],
                        widget.user['username']?.toString() ?? 'Bạn',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${roleName(role)} · Chúc bạn một ngày hiệu quả',
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (role == 'admin') ...[
          FilledButton.tonalIcon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminUsersPage(token: widget.token),
                ),
              );
            },
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('Quản lý sinh viên và giảng viên'),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF163B58), Color(0xFF087E8B)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220B5661),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ĐIỂM DANH THÔNG MINH',
                style: TextStyle(
                  color: Color(0xFF8AE0D7),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                role == 'student'
                    ? 'Quét mã QR tại lớp để ghi nhận có mặt.'
                    : 'Quản lý buổi học và theo dõi chuyên cần.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (role == 'student')
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScannerPage(token: widget.token),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Quét mã điểm danh'),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => setState(() => tab = 1),
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Mở lớp học'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Lớp của bạn',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
            ),
            Text(
              '${classes.length} lớp',
              style: const TextStyle(color: Colors.blueGrey),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          )
        else if (error != null)
          ErrorPanel(message: error!, retry: load)
        else if (classes.isEmpty)
          const EmptyPanel(text: 'Chưa có lớp học nào được phân công.')
        else
          ...classes
              .take(3)
              .map(
                (c) => ClassCard(
                  item: c,
                  onTap: () => openClass(c),
                  isAdmin: role == 'admin',
                  onEdit: () => editClass(c),
                  onDelete: () => deleteClass(c),
                ),
              ),
      ],
    ),
  );
  Widget classList() => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Danh sách lớp',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
            ),
            if (role == 'admin')
              IconButton.filled(
                onPressed: createClass,
                icon: const Icon(Icons.add),
                tooltip: 'Tạo lớp',
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (busy)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
          ErrorPanel(message: error!, retry: load)
        else if (classes.isEmpty)
          const EmptyPanel(text: 'Chưa có lớp học nào.')
        else
          ...classes.map(
            (c) => ClassCard(
              item: c,
              onTap: () => openClass(c),
              isAdmin: role == 'admin',
              onEdit: () => editClass(c),
              onDelete: () => deleteClass(c),
            ),
          ),
      ],
    ),
  );
  void openClass(Map<String, dynamic> c) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ClassPage(item: c, token: widget.token, role: role, onChanged: load),
    ),
  );
  Future<void> createClass() => editClass(null);

  Future<void> editClass(Map<String, dynamic>? current) async {
    final code = TextEditingController(
          text: current?['code']?.toString() ?? '',
        ),
        name = TextEditingController(text: current?['name']?.toString() ?? ''),
        subject = TextEditingController(
          text: current?['subject']?.toString() ?? '',
        ),
        room = TextEditingController(text: current?['room']?.toString() ?? '');
    List<Map<String, dynamic>> teachers = [];
    try {
      teachers = mapList(
        await Api.get('/api/users?role=teacher', widget.token),
      );
    } catch (e) {
      if (mounted) notice(context, e);
    }
    if (!mounted) return;
    String? teacherId = current?['teacherId']?.toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(current == null ? 'Tạo lớp học' : 'Sửa lớp học'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'Mã lớp'),
                ),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Tên lớp'),
                ),
                TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'Môn học'),
                ),
                TextField(
                  controller: room,
                  decoration: const InputDecoration(labelText: 'Phòng học'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: teachers.any((u) => u['id']?.toString() == teacherId)
                      ? teacherId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Giảng viên phụ trách',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Chưa phân công'),
                    ),
                    ...teachers.map(
                      (u) => DropdownMenuItem<String?>(
                        value: u['id']?.toString(),
                        child: Text(
                          textOf(
                            u['fullName'],
                            u['username']?.toString() ?? 'Giảng viên',
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => teacherId = value),
                ),
                if (teachers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Chưa có tài khoản giảng viên. Hãy tạo ở mục Quản lý tài khoản.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(current == null ? 'Tạo' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final payload = {
        'code': code.text.trim(),
        'name': name.text.trim(),
        'subject': subject.text.trim(),
        'room': room.text.trim(),
        'teacherId': teacherId,
      };
      if (current == null) {
        await Api.post('/api/classes', payload, widget.token);
      } else {
        await Api.request(
          'PUT',
          '/api/classes/${current['id']}',
          token: widget.token,
          body: payload,
        );
      }
      await load();
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  Future<void> deleteClass(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa lớp học?'),
        content: Text('Bạn có chắc muốn xóa lớp ${textOf(item['name'])}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.request(
        'DELETE',
        '/api/classes/${item['id']}',
        token: widget.token,
      );
      await load();
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, required this.token});
  final String token;
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  String role = 'student';
  bool loading = true;
  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      users = mapList(await Api.get('/api/users?role=$role', widget.token));
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> editUser([Map<String, dynamic>? user]) async {
    final name = TextEditingController(
      text: user?['fullName']?.toString() ?? '',
    );
    final username = TextEditingController(
      text: user?['username']?.toString() ?? '',
    );
    final email = TextEditingController(text: user?['email']?.toString() ?? '');
    final phone = TextEditingController(text: user?['phone']?.toString() ?? '');
    final studentCode = TextEditingController(
      text: user?['studentCode']?.toString() ?? '',
    );
    final password = TextEditingController();
    final key = GlobalKey<FormState>();
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          user == null
              ? 'Tạo ${role == 'student' ? 'sinh viên' : 'giảng viên'}'
              : 'Sửa tài khoản',
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user == null)
                    TextFormField(
                      controller: username,
                      decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nhập tên đăng nhập'
                          : null,
                    ),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nhập họ tên' : null,
                  ),
                  TextFormField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  TextFormField(
                    controller: phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  if (role == 'student')
                    TextFormField(
                      controller: studentCode,
                      decoration: const InputDecoration(
                        labelText: 'Mã sinh viên',
                      ),
                    ),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: user == null
                          ? 'Mật khẩu'
                          : 'Mật khẩu mới (để trống nếu không đổi)',
                    ),
                    validator: (v) =>
                        user == null && (v == null || v.length < 6)
                        ? 'Mật khẩu tối thiểu 6 ký tự'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate())
                Navigator.pop(ctx, {
                  'username': username.text.trim(),
                  'fullName': name.text.trim(),
                  'email': email.text.trim(),
                  'phone': phone.text.trim(),
                  'studentCode': studentCode.text.trim(),
                  'password': password.text,
                });
            },
            child: Text(user == null ? 'Tạo tài khoản' : 'Lưu'),
          ),
        ],
      ),
    );
    if (data == null) return;
    try {
      if (user == null) {
        await Api.post('/api/users', {
          'username': data['username'],
          'fullName': data['fullName'],
          'email': data['email'],
          'phone': data['phone'],
          'studentCode': data['studentCode'],
          'password': data['password'],
          'role': role,
        }, widget.token);
      } else {
        await Api.request(
          'PUT',
          '/api/users/${user['id']}',
          token: widget.token,
          body: {
            'fullName': data['fullName'],
            'email': data['email'],
            'phone': data['phone'],
            'studentCode': data['studentCode'],
            'role': role,
            if (data['password']!.isNotEmpty) 'newPassword': data['password'],
          },
        );
      }
      await load();
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  Future<void> deleteUser(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: Text(
          'Xóa tài khoản ${textOf(user['fullName'], user['username']?.toString() ?? '')}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.request(
        'DELETE',
        '/api/users/${user['id']}',
        token: widget.token,
      );
      await load();
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý tài khoản')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => editUser(),
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('Thêm tài khoản'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'student',
                label: Text('Sinh viên'),
                icon: Icon(Icons.school_outlined),
              ),
              ButtonSegment(
                value: 'teacher',
                label: Text('Giảng viên'),
                icon: Icon(Icons.co_present_outlined),
              ),
            ],
            selected: {role},
            onSelectionChanged: (v) {
              setState(() => role = v.first);
              load();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PageBanner(
            icon: role == 'student'
                ? Icons.school_outlined
                : Icons.co_present_outlined,
            title: role == 'student' ? 'Sinh viên' : 'Giảng viên',
            subtitle:
                '${users.length} tài khoản trong danh sách · Chọn tài khoản để chỉnh sửa hoặc quản lý.',
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : users.isEmpty
              ? const EmptyPanel(text: 'Chưa có tài khoản nào.')
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              role == 'student'
                                  ? Icons.school_outlined
                                  : Icons.co_present_outlined,
                            ),
                          ),
                          title: Text(
                            textOf(
                              user['fullName'],
                              user['username']?.toString() ?? '',
                            ),
                          ),
                          subtitle: Text(
                            '${textOf(user['username'])} · ${textOf(user['email'])}${role == 'student' ? ' · ${textOf(user['studentCode'], '')}' : ''}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') editUser(user);
                              if (v == 'delete') deleteUser(user);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Sửa tài khoản'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Xóa tài khoản'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}

class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isAdmin = false,
    this.onEdit,
    this.onDelete,
  });
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final bool isAdmin;
  final VoidCallback? onEdit, onDelete;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFE8EDF2)),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFE2F5F2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.menu_book_rounded, color: teal),
      ),
      title: Text(
        textOf(item['name']),
        style: const TextStyle(fontWeight: FontWeight.bold, color: ink),
      ),
      subtitle: Text(
        '${textOf(item['code'])} · ${textOf(item['subject'], 'Môn học')}',
      ),
      trailing: isAdmin
          ? PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa lớp')),
                PopupMenuItem(value: 'delete', child: Text('Xóa lớp')),
              ],
            )
          : const Icon(Icons.chevron_right),
    ),
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFF1F7F8)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE4ECEF)),
    ),
    child: Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFFE3F3F1),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(Icons.inbox_outlined, size: 34, color: teal),
        ),
        const SizedBox(height: 14),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.blueGrey),
        ),
      ],
    ),
  );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF3D5D7)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFBA3A45)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF9D2F3A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      TextButton.icon(
        onPressed: retry,
        icon: const Icon(Icons.refresh),
        label: const Text('Thử lại'),
      ),
    ],
  );
}

class ClassPage extends StatefulWidget {
  const ClassPage({
    super.key,
    required this.item,
    required this.token,
    required this.role,
    required this.onChanged,
  });
  final Map<String, dynamic> item;
  final String token, role;
  final VoidCallback onChanged;
  @override
  State<ClassPage> createState() => _ClassPageState();
}

class _ClassPageState extends State<ClassPage> {
  List<Map<String, dynamic>> sessions = [];
  List<Map<String, dynamic>> students = [];
  bool loading = true;
  bool loadingStudents = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      sessions = mapList(
        await Api.get(
          '/api/classes/${widget.item['id']}/sessions',
          widget.token,
        ),
      );
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
    if (widget.role == 'admin') await loadStudents();
  }

  Future<void> loadStudents() async {
    if (mounted) setState(() => loadingStudents = true);
    try {
      students = mapList(
        await Api.get(
          '/api/classes/${widget.item['id']}/students',
          widget.token,
        ),
      );
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => loadingStudents = false);
    }
  }

  Future<void> addStudents() async {
    try {
      final allStudents = mapList(
        await Api.get('/api/users?role=student', widget.token),
      );
      final enrolledIds = students.map((s) => s['id']?.toString()).toSet();
      final available = allStudents
          .where((s) => !enrolledIds.contains(s['id']?.toString()))
          .toList();
      if (!mounted) return;
      if (available.isEmpty) {
        notice(context, 'Không còn sinh viên nào để thêm vào lớp.');
        return;
      }
      final selected = <String>{};
      final ids = await showDialog<List<String>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Thêm sinh viên vào lớp'),
            content: SizedBox(
              width: 420,
              height: 420,
              child: ListView(
                children: available.map((student) {
                  final id = student['id']?.toString() ?? '';
                  return CheckboxListTile(
                    value: selected.contains(id),
                    title: Text(
                      textOf(
                        student['fullName'],
                        student['username']?.toString() ?? 'Sinh viên',
                      ),
                    ),
                    subtitle: Text(
                      '${textOf(student['studentCode'], '')} ${textOf(student['email'], '')}',
                    ),
                    onChanged: (checked) => setDialogState(() {
                      if (checked == true) {
                        selected.add(id);
                      } else {
                        selected.remove(id);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, selected.toList()),
                child: Text('Thêm (${selected.length})'),
              ),
            ],
          ),
        ),
      );
      if (ids == null || ids.isEmpty) return;
      await Api.post('/api/classes/${widget.item['id']}/students', {
        'studentIds': ids,
      }, widget.token);
      await loadStudents();
      widget.onChanged();
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  Future<void> removeStudent(Map<String, dynamic> student) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa sinh viên khỏi lớp?'),
        content: Text('Gỡ ${textOf(student['fullName'])} khỏi lớp học này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gỡ khỏi lớp'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.request(
        'DELETE',
        '/api/classes/${widget.item['id']}/students/${student['id']}',
        token: widget.token,
      );
      await loadStudents();
      widget.onChanged();
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(textOf(widget.item['name']))),
    floatingActionButton: widget.role == 'admin' || widget.role == 'teacher'
        ? FloatingActionButton.extended(
            onPressed: createSession,
            icon: const Icon(Icons.add),
            label: const Text('Tạo buổi học'),
          )
        : null,
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PageBanner(
            icon: Icons.menu_book_rounded,
            title: textOf(widget.item['name']),
            subtitle:
                '${textOf(widget.item['code'])} · ${textOf(widget.item['subject'], 'Môn học')} · ${textOf(widget.item['room'], 'Chưa có phòng')}',
          ),
          if (widget.role == 'admin') ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sinh viên trong lớp',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: addStudents,
                  icon: const Icon(Icons.person_add_alt_1),
                  tooltip: 'Thêm sinh viên',
                ),
              ],
            ),
            if (loadingStudents)
              const Center(child: CircularProgressIndicator())
            else if (students.isEmpty)
              const EmptyPanel(text: 'Chưa có sinh viên trong lớp.')
            else
              ...students.map(
                (student) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(
                      textOf(
                        student['fullName'],
                        student['username']?.toString() ?? 'Sinh viên',
                      ),
                    ),
                    subtitle: Text(
                      '${textOf(student['studentCode'], '')} ${textOf(student['email'], '')}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_remove_outlined),
                      tooltip: 'Gỡ khỏi lớp',
                      onPressed: () => removeStudent(student),
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Buổi học',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            ErrorPanel(message: error!, retry: load)
          else if (sessions.isEmpty)
            const EmptyPanel(text: 'Lớp chưa có buổi học.')
          else
            ...sessions.map(
              (s) => SessionCard(
                session: s,
                classId: widget.item['id'].toString(),
                token: widget.token,
                role: widget.role,
                onRefresh: load,
              ),
            ),
        ],
      ),
    ),
  );
  Future<void> createSession() async {
    final data = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const CreateSessionPage()),
    );
    if (data == null) return;
    try {
      await Api.post(
        '/api/classes/${widget.item['id']}/sessions',
        data,
        widget.token,
      );
      await load();
      widget.onChanged();
    } catch (e) {
      if (mounted) notice(context, e);
    }
  }
}

class CreateSessionPage extends StatefulWidget {
  const CreateSessionPage({super.key});
  @override
  State<CreateSessionPage> createState() => _CreateSessionPageState();
}

class _CreateSessionPageState extends State<CreateSessionPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final radius = TextEditingController(text: '100');
  DateTime start = DateTime.now().add(const Duration(minutes: 5));
  DateTime end = DateTime.now().add(const Duration(hours: 2));
  Position? location;
  bool requireFace = false, locating = false;

  @override
  void dispose() {
    title.dispose();
    radius.dispose();
    super.dispose();
  }

  Future<DateTime?> selectDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> locate() async {
    setState(() => locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw Exception('Cần cấp quyền vị trí để lấy GPS lớp học.');
      }
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (mounted) setState(() => location = current);
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    if (!end.isAfter(start)) {
      notice(context, 'Thời gian kết thúc phải sau thời gian bắt đầu.');
      return;
    }
    if (location == null) {
      notice(context, 'Hãy lấy vị trí GPS lớp học trước khi tạo buổi.');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'title': title.text.trim(),
      'startTime': isoWithLocalOffset(start),
      'endTime': isoWithLocalOffset(end),
      'latitude': location!.latitude,
      'longitude': location!.longitude,
      'radiusMeters': double.parse(radius.text.trim()),
      'requireFace': requireFace,
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tạo buổi học')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PageBanner(
            icon: Icons.event_available_outlined,
            title: 'Lên lịch buổi học',
            subtitle:
                'Thiết lập thời gian, vị trí và phạm vi điểm danh cho lớp.',
          ),
          TextFormField(
            controller: title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Tên buổi học',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event_note),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập tên buổi học'
                : null,
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.play_circle_outline, color: teal),
                  title: const Text('Bắt đầu'),
                  subtitle: Text(localTime(start)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final selected = await selectDateTime(start);
                    if (selected != null && mounted)
                      setState(() => start = selected);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.stop_circle_outlined, color: teal),
                  title: const Text('Kết thúc'),
                  subtitle: Text(localTime(end)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final selected = await selectDateTime(end);
                    if (selected != null && mounted)
                      setState(() => end = selected);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: locating ? null : locate,
            icon: locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              location == null
                  ? 'Lấy vị trí lớp học bằng GPS'
                  : 'Cập nhật vị trí GPS',
            ),
          ),
          if (location != null)
            Card(
              color: const Color(0xFFE2F5F2),
              child: ListTile(
                leading: const Icon(Icons.location_on, color: teal),
                title: const Text('Vị trí hiện tại đã chọn'),
                subtitle: Text(
                  '${location!.latitude.toStringAsFixed(6)}, ${location!.longitude.toStringAsFixed(6)}',
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: radius,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Bán kính điểm danh (mét)',
              helperText: 'Sinh viên cần ở trong phạm vi này để điểm danh.',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.radar),
            ),
            validator: (value) {
              final meters = double.tryParse(value?.trim() ?? '');
              return meters == null || meters <= 0
                  ? 'Nhập bán kính lớn hơn 0'
                  : null;
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: requireFace,
            onChanged: (value) => setState(() => requireFace = value),
            title: const Text('Yêu cầu xác minh khuôn mặt'),
            subtitle: const Text(
              'Sinh viên phải đăng ký khuôn mặt để điểm danh.',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: locating ? null : submit,
            icon: const Icon(Icons.check),
            label: const Text('Tạo buổi học'),
          ),
        ],
      ),
    ),
  );
}

String localTime(dynamic d) {
  try {
    return DateTime.parse(d.toString()).toLocal().toString().substring(0, 16);
  } catch (_) {
    return 'Chưa có thời gian';
  }
}

String isoWithLocalOffset(DateTime value) {
  final offset = value.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '${value.toIso8601String()}$sign$hours:$minutes';
}

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.classId,
    required this.token,
    required this.role,
    required this.onRefresh,
  });
  final Map<String, dynamic> session;
  final String classId;
  final String token, role;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE2F5F2),
        child: Icon(Icons.event_available, color: teal),
      ),
      title: Text(
        textOf(session['title']),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(localTime(session['startTime'])),
      trailing: role == 'student'
          ? null
          : IconButton(
              icon: const Icon(Icons.qr_code_2, color: teal),
              tooltip: 'Tạo QR',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QrPage(session: session, token: token),
                ),
              ),
            ),
      onTap: role == 'student'
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentSessionPage(
                  session: session,
                  classId: classId,
                  token: token,
                ),
              ),
            )
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherSessionPage(
                  session: session,
                  classId: classId,
                  token: token,
                ),
              ),
            ),
    ),
  );
}

class StudentSessionPage extends StatefulWidget {
  const StudentSessionPage({
    super.key,
    required this.session,
    required this.classId,
    required this.token,
  });
  final Map<String, dynamic> session;
  final String classId, token;
  @override
  State<StudentSessionPage> createState() => _StudentSessionPageState();
}

class _StudentSessionPageState extends State<StudentSessionPage> {
  Map<String, dynamic>? attendance;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = mapList(
        await Api.get(
          '/api/attendance/me?classId=${Uri.encodeComponent(widget.classId)}',
          widget.token,
        ),
      );
      final found = rows.where(
        (r) => r['sessionId']?.toString() == widget.session['id']?.toString(),
      );
      attendance = found.isEmpty ? null : found.first;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String statusText(dynamic value) => switch (value) {
    'present' => 'Có mặt',
    'late' => 'Đi trễ',
    'absent' => 'Vắng',
    'excused' => 'Có phép',
    _ => textOf(value, 'Chưa điểm danh'),
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết buổi học')),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            textOf(widget.session['title']),
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(localTime(widget.session['startTime'])),
          const SizedBox(height: 22),
          Card(
            color: Colors.white,
            child: ListTile(
              leading: Icon(
                loading
                    ? Icons.sync
                    : attendance == null
                    ? Icons.pending_actions
                    : Icons.check_circle,
                color: attendance == null ? Colors.orange : teal,
              ),
              title: Text(
                loading
                    ? 'Đang tải trạng thái…'
                    : error != null
                    ? 'Không tải được trạng thái'
                    : statusText(attendance?['status']),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: error != null
                  ? Text(error!)
                  : attendance == null
                  ? const Text('Chưa có bản ghi điểm danh trong buổi này')
                  : Text(
                      'Phương thức: ${textOf(attendance?['method'])} · ${localTime(attendance?['checkInTime'])}',
                    ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              final result = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                  builder: (_) => ScannerPage(
                    token: widget.token,
                    expectedSessionId: widget.session['id'].toString(),
                    requireFace: widget.session['requireFace'] == true,
                  ),
                ),
              );
              if (result != null) await load();
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Quét QR điểm danh'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AbsencePage(session: widget.session, token: widget.token),
              ),
            ),
            icon: const Icon(Icons.edit_note),
            label: const Text('Gửi đơn xin phép'),
          ),
          if (error != null)
            TextButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại trạng thái'),
            ),
        ],
      ),
    ),
  );
}

class TeacherSessionPage extends StatefulWidget {
  const TeacherSessionPage({
    super.key,
    required this.session,
    required this.classId,
    required this.token,
  });
  final Map<String, dynamic> session;
  final String classId, token;
  @override
  State<TeacherSessionPage> createState() => _TeacherSessionPageState();
}

class _TeacherSessionPageState extends State<TeacherSessionPage> {
  List<Map<String, dynamic>> roster = [];
  List<Map<String, dynamic>> requests = [];
  bool loading = true, reviewing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        Api.get(
          '/api/sessions/${widget.session['id']}/attendance',
          widget.token,
        ),
        Api.get(
          '/api/absence-requests?status=pending&classId=${Uri.encodeComponent(widget.classId)}',
          widget.token,
        ),
      ]);
      roster = mapList(values[0]);
      requests = mapList(values[1])
          .where(
            (r) =>
                r['sessionId']?.toString() ==
                    widget.session['id']?.toString() &&
                r['status']?.toString() == 'pending',
          )
          .toList();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String statusLabel(dynamic value) => switch (value) {
    'present' => 'Có mặt',
    'late' => 'Đi trễ',
    'absent' => 'Vắng',
    'excused' => 'Có phép',
    'pending' || null => 'Chưa điểm danh',
    _ => textOf(value),
  };

  Color statusColor(dynamic value) => switch (value) {
    'present' => Colors.green,
    'late' => Colors.orange,
    'absent' => Colors.red,
    'excused' => teal,
    _ => Colors.blueGrey,
  };

  Future<void> review(Map<String, dynamic> request, String status) async {
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          status == 'approved' ? 'Duyệt đơn xin phép' : 'Từ chối đơn xin phép',
        ),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Ghi chú phản hồi (không bắt buộc)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(status == 'approved' ? 'Duyệt đơn' : 'Từ chối'),
          ),
        ],
      ),
    );
    if (accepted != true) {
      note.dispose();
      return;
    }
    setState(() => reviewing = true);
    try {
      await Api.post('/api/absence-requests/${request['id']}/review', {
        'status': status,
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      }, widget.token);
      await load();
      if (mounted)
        notice(
          context,
          status == 'approved'
              ? 'Đã duyệt đơn; điểm danh chuyển sang có phép.'
              : 'Đã từ chối đơn.',
        );
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      note.dispose();
      if (mounted) setState(() => reviewing = false);
    }
  }

  void showEvidence(Map<String, dynamic> evidence) {
    final path = textOf(evidence['url'], '');
    final uri = Uri.tryParse(path);
    final url = uri == null
        ? ''
        : uri.hasScheme
        ? path
        : '$apiBase$path';
    final type = textOf(evidence['contentType'], '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(textOf(evidence['fileName'], 'Minh chứng')),
        content: type.startsWith('image/') && url.isNotEmpty
            ? SizedBox(
                width: 360,
                child: Image.network(
                  url,
                  headers: {'Authorization': 'Bearer ${widget.token}'},
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Không tải được ảnh minh chứng.'),
                ),
              )
            : Text(
                'Tệp đính kèm: ${textOf(evidence['fileName'])}\nLoại tệp: $type',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final present = roster.where((r) => r['status'] == 'present').length;
    final late = roster.where((r) => r['status'] == 'late').length;
    final excused = roster.where((r) => r['status'] == 'excused').length;
    final absent = roster.where((r) => r['status'] == 'absent').length;
    final pending = roster
        .where((r) => r['status'] == 'pending' || r['status'] == null)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý buổi học')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              textOf(widget.session['title']),
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            Text('Bắt đầu: ${localTime(widget.session['startTime'])}'),
            Text('Kết thúc: ${localTime(widget.session['endTime'])}'),
            Text(
              'Bán kính điểm danh: ${textOf(widget.session['radiusMeters'], '—')} m',
            ),
            if (widget.session['latitude'] != null &&
                widget.session['longitude'] != null)
              Text(
                'GPS lớp: ${widget.session['latitude']}, ${widget.session['longitude']}',
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      QrPage(session: widget.session, token: widget.token),
                ),
              ),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Tạo / hiển thị mã QR'),
            ),
            if (error != null) ErrorPanel(message: error!, retry: load),
            const SizedBox(height: 18),
            const Text(
              'Tình hình điểm danh',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip('Có mặt', present, Colors.green),
                _statusChip('Đi trễ', late, Colors.orange),
                _statusChip('Chưa điểm danh', pending, Colors.blueGrey),
                _statusChip('Vắng', absent, Colors.red),
                _statusChip('Có phép', excused, teal),
              ],
            ),
            const SizedBox(height: 10),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (roster.isEmpty)
              const EmptyPanel(
                text: 'Chưa có sinh viên trong danh sách buổi học.',
              )
            else
              ...roster.map(
                (student) => Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor(student['status'])
                          .withValues(alpha: 0.12),
                      child: Icon(
                        Icons.person,
                        color: statusColor(student['status']),
                      ),
                    ),
                    title: Text(
                      textOf(student['fullName']),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        if (student['studentCode'] != null)
                          'MSSV ${student['studentCode']}',
                        statusLabel(student['status']),
                        if (student['checkInTime'] != null)
                          localTime(student['checkInTime']),
                        if (student['distanceMeters'] != null)
                          '${(student['distanceMeters'] as num).toStringAsFixed(0)} m',
                        if (student['faceVerified'] == true)
                          'Đã xác minh khuôn mặt',
                        if (textOf(student['note'], '').isNotEmpty)
                          textOf(student['note']),
                      ].join(' · '),
                    ),
                    trailing: Chip(
                      label: Text(statusLabel(student['status'])),
                      labelStyle: TextStyle(
                        color: statusColor(student['status']),
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: statusColor(student['status'])
                            .withValues(alpha: 0.35),
                      ),
                      backgroundColor: statusColor(student['status'])
                          .withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Đơn xin phép chờ duyệt',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                ),
                if (requests.isNotEmpty)
                  Chip(label: Text('${requests.length}')),
              ],
            ),
            if (requests.isEmpty && !loading)
              const EmptyPanel(
                text: 'Buổi học này không có đơn xin phép đang chờ.',
              )
            else
              ...requests.map((request) {
                final evidence = mapList(request['evidence']);
                return Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textOf(request['studentName']),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${textOf(request['studentCode'])} · ${textOf(request['category'])} · gửi ${localTime(request['createdAt'])}',
                        ),
                        const SizedBox(height: 8),
                        Text(textOf(request['reason'])),
                        if (evidence.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: evidence
                                .map(
                                  (file) => OutlinedButton.icon(
                                    onPressed: () => showEvidence(file),
                                    icon: const Icon(
                                      Icons.attachment,
                                      size: 18,
                                    ),
                                    label: Text(
                                      textOf(file['fileName'], 'Minh chứng'),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: reviewing
                                    ? null
                                    : () => review(request, 'rejected'),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                label: const Text('Từ chối'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: reviewing
                                    ? null
                                    : () => review(request, 'approved'),
                                icon: const Icon(Icons.check),
                                label: const Text('Duyệt đơn'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, int count, Color color) => Chip(
    avatar: CircleAvatar(backgroundColor: color, radius: 5),
    label: Text('$label: $count'),
    backgroundColor: color.withValues(alpha: 0.08),
    side: BorderSide(color: color.withValues(alpha: 0.25)),
  );
}

class QrPage extends StatefulWidget {
  const QrPage({super.key, required this.session, required this.token});
  final Map<String, dynamic> session;
  final String token;
  @override
  State<QrPage> createState() => _QrPageState();
}

class _QrPageState extends State<QrPage> {
  String? qr, expiry;
  bool busy = false;
  Future<void> make() async {
    setState(() => busy = true);
    try {
      final r = await Api.post('/api/sessions/${widget.session['id']}/qr', {
        'validMinutes': 5,
      }, widget.token);
      setState(() {
        qr = r['qrToken'].toString();
        expiry = localTime(r['expiresAt']);
      });
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mã điểm danh')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              textOf(widget.session['title']),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quét mã để ghi nhận tham dự',
              style: TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 24),
            if (qr != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE3ECEF)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x170E3345),
                      blurRadius: 26,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: QrImageView(data: qr!, size: 250),
              )
            else
              Container(
                width: 286,
                height: 286,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE3ECEF)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 112, color: teal),
                    SizedBox(height: 8),
                    Text(
                      'Mã QR sẽ hiện ở đây',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            if (expiry != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F5F2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Có hiệu lực đến $expiry',
                  style: const TextStyle(
                    color: teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : make,
              icon: const Icon(Icons.refresh),
              label: Text(qr == null ? 'Tạo mã QR' : 'Làm mới mã'),
            ),
          ],
        ),
      ),
    ),
  );
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({
    super.key,
    required this.token,
    this.expectedSessionId,
    this.requireFace = false,
  });
  final String token;
  final String? expectedSessionId;
  final bool requireFace;
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool done = false, busy = false;
  late bool sendFace = widget.requireFace;
  String? message;
  Map<String, dynamic>? checkinRecord;

  Future<void> checkin(String raw) async {
    if (done || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      Position? position;
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied)
          permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          position = await Geolocator.getCurrentPosition();
        }
      } catch (_) {}
      final body = <String, dynamic>{'qrToken': raw};
      if (position != null) {
        body['latitude'] = position.latitude;
        body['longitude'] = position.longitude;
      }
      if (sendFace) {
        message = 'Chụp khuôn mặt để xác minh…';
        if (mounted) setState(() {});
        body['faceEmbedding'] = await FaceRecognition.captureEmbedding();
      }
      final result = await Api.post(
        '/api/attendance/checkin',
        body,
        widget.token,
      );
      checkinRecord = Map<String, dynamic>.from(result as Map);
      final differentSession =
          widget.expectedSessionId != null &&
          checkinRecord!['sessionId']?.toString() != widget.expectedSessionId;
      if (mounted)
        setState(() {
          done = true;
          message = differentSession
              ? 'Mã QR thuộc buổi học khác. Trạng thái đã ghi nhận: ${textOf(checkinRecord!['status'])}'
              : 'Điểm danh ${switch (checkinRecord!['status']) {
                  'present' => 'có mặt',
                  'late' => 'đi trễ',
                  _ => textOf(checkinRecord!['status'], 'thành công'),
                }}.';
        });
    } catch (e) {
      if (mounted)
        setState(() => message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quét QR điểm danh')),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              final codes = capture.barcodes;
              if (codes.isNotEmpty && codes.first.rawValue != null)
                checkin(codes.first.rawValue!);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (!done)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sendFace,
                  onChanged: busy || widget.requireFace
                      ? null
                      : (value) => setState(() => sendFace = value),
                  title: const Text('Xác minh bằng khuôn mặt'),
                  subtitle: const Text(
                    'Dùng khi buổi học yêu cầu nhận diện khuôn mặt.',
                  ),
                ),
              Text(
                done
                    ? 'Đã ghi nhận điểm danh'
                    : message ?? 'Đưa mã QR vào khung hình để quét',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: done ? teal : ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(),
                ),
              if (done)
                FilledButton(
                  onPressed: () => Navigator.pop(context, checkinRecord),
                  child: const Text('Hoàn tất'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AbsencePage extends StatefulWidget {
  const AbsencePage({super.key, required this.session, required this.token});
  final Map<String, dynamic> session;
  final String token;
  @override
  State<AbsencePage> createState() => _AbsencePageState();
}

class _AbsencePageState extends State<AbsencePage> {
  final reason = TextEditingController();
  String category = 'other';
  XFile? file;
  bool busy = false;
  Future<void> submit() async {
    if (reason.text.trim().isEmpty) {
      notice(context, 'Nhập lý do xin phép');
      return;
    }
    setState(() => busy = true);
    try {
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse('$apiBase/api/absence-requests'),
            )
            ..headers['Authorization'] = 'Bearer ${widget.token}'
            ..fields['sessionId'] = widget.session['id'].toString()
            ..fields['reason'] = reason.text.trim()
            ..fields['category'] = category;
      if (file != null)
        req.files.add(await http.MultipartFile.fromPath('files', file!.path));
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode >= 400)
        throw Exception(
          (jsonDecode(res.body) as Map)['message'] ?? 'Không gửi được đơn',
        );
      if (mounted) {
        notice(context, 'Đơn xin phép đã gửi');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xin phép vắng')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageBanner(
          icon: Icons.event_busy_outlined,
          title: 'Gửi đơn xin phép',
          subtitle: textOf(widget.session['title']),
        ),
        Text(
          textOf(widget.session['title']),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: category,
          decoration: const InputDecoration(
            labelText: 'Lý do',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'sick', child: Text('Ốm / sức khỏe')),
            DropdownMenuItem(value: 'family', child: Text('Việc gia đình')),
            DropdownMenuItem(value: 'event', child: Text('Hoạt động trường')),
            DropdownMenuItem(value: 'other', child: Text('Khác')),
          ],
          onChanged: (v) => setState(() => category = v ?? 'other'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: reason,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Mô tả lý do',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final x = await ImagePicker().pickImage(
              source: ImageSource.camera,
              imageQuality: 70,
              maxWidth: 1280,
            );
            if (x != null) setState(() => file = x);
          },
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(
            file == null ? 'Chụp minh chứng' : 'Đã chọn ${file!.name}',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : submit,
          child: busy
              ? const CircularProgressIndicator()
              : const Text('Gửi đơn xin phép'),
        ),
      ],
    ),
  );
}

class ProfileSummary extends StatelessWidget {
  const ProfileSummary({
    super.key,
    required this.user,
    required this.onProfile,
  });
  final Map<String, dynamic> user;
  final VoidCallback onProfile;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF163B58), Color(0xFF087E8B)],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x220B5661),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textOf(user['fullName']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      roleName(user['role']?.toString()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Card(
        color: Colors.white,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: const Text('Tài khoản'),
              subtitle: Text(textOf(user['username'])),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Email'),
              subtitle: Text(textOf(user['email'])),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Mã sinh viên'),
              subtitle: Text(textOf(user['studentCode'])),
            ),
          ],
        ),
      ),
      FilledButton.icon(
        onPressed: onProfile,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Cập nhật hồ sơ'),
      ),
    ],
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, required this.token});
  final Map<String, dynamic> user;
  final String token;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final name = TextEditingController(
    text: textOf(widget.user['fullName'], ''),
  );
  late final phone = TextEditingController(
    text: textOf(widget.user['phone'], ''),
  );
  bool busy = false;
  bool hasFace = false;
  bool faceStatusLoading = true;

  @override
  void initState() {
    super.initState();
    hasFace = widget.user['hasFace'] == true;
    refreshFaceStatus();
  }

  Future<void> refreshFaceStatus() async {
    try {
      final result = await Api.get('/api/users/me', widget.token);
      if (mounted && result is Map && result['hasFace'] is bool) {
        setState(() => hasFace = result['hasFace'] as bool);
      }
    } catch (_) {
      // Keep the status from the signed-in user response if profile fetch fails.
    } finally {
      if (mounted) setState(() => faceStatusLoading = false);
    }
  }

  Future<void> registerFace() async {
    final replacingFace = hasFace;
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận mật khẩu'),
        content: TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    if (confirmed != true || password.text.isEmpty) {
      password.dispose();
      return;
    }
    setState(() => busy = true);
    try {
      final vectors = <List<double>>[];
      const poses = ['nhìn thẳng', 'quay nhẹ sang trái', 'quay nhẹ sang phải'];
      for (var i = 0; i < 3; i++) {
        if (!mounted) return;
        notice(context, 'Mẫu ${i + 1}/3: ${poses[i]}');
        vectors.add(await FaceRecognition.captureEmbedding());
      }
      if (replacingFace) {
        await Api.request('DELETE', '/api/users/me/face', token: widget.token);
        if (mounted) setState(() => hasFace = false);
      }
      await Api.post('/api/users/me/face', {
        'embeddings': vectors,
        'password': password.text,
      }, widget.token);
      if (mounted) {
        setState(() => hasFace = true);
        notice(
          context,
          replacingFace ? 'Đã cập nhật khuôn mặt.' : 'Đã đăng ký khuôn mặt.',
        );
      }
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      password.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteFace() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa khuôn mặt?'),
        content: const Text(
          'Bạn sẽ không thể đăng nhập hoặc điểm danh bằng khuôn mặt cho đến khi đăng ký lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa khuôn mặt'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await Api.request('DELETE', '/api/users/me/face', token: widget.token);
      if (mounted) {
        setState(() => hasFace = false);
        notice(context, 'Đã xóa khuôn mặt đã đăng ký.');
      }
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await Api.request(
        'PUT',
        '/api/users/me',
        body: {'fullName': name.text.trim(), 'phone': phone.text.trim()},
        token: widget.token,
      );
      if (mounted) {
        notice(context, 'Đã cập nhật hồ sơ');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cập nhật hồ sơ')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageBanner(
          icon: Icons.manage_accounts_outlined,
          title: 'Hồ sơ cá nhân',
          subtitle:
              'Cập nhật thông tin liên hệ và cài đặt nhận diện khuôn mặt.',
        ),
        TextField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Họ và tên',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Số điện thoại',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : save,
          child: busy
              ? const CircularProgressIndicator()
              : const Text('Lưu thay đổi'),
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.white,
          child: ListTile(
            leading: Icon(
              hasFace ? Icons.face : Icons.face_outlined,
              color: hasFace ? teal : Colors.blueGrey,
            ),
            title: const Text('Nhận diện khuôn mặt'),
            subtitle: Text(
              faceStatusLoading
                  ? 'Đang kiểm tra trạng thái…'
                  : hasFace
                  ? 'Đã đăng ký'
                  : 'Chưa đăng ký',
            ),
            trailing: IconButton(
              tooltip: 'Làm mới trạng thái',
              onPressed: busy || faceStatusLoading
                  ? null
                  : () {
                      setState(() => faceStatusLoading = true);
                      refreshFaceStatus();
                    },
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: busy || faceStatusLoading ? null : registerFace,
          icon: const Icon(Icons.face_retouching_natural),
          label: Text(hasFace ? 'Thay đổi khuôn mặt' : 'Đăng ký khuôn mặt'),
        ),
        if (hasFace) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: busy || faceStatusLoading ? null : deleteFace,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text(
              'Xóa khuôn mặt đã đăng ký',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ],
    ),
  );
}
