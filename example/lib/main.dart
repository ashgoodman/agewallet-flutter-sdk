import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agewallet_flutter_sdk/agewallet_flutter_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgeWallet SDK Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AgeWallet _ageWallet;
  bool _isVerified = false;
  bool _isLoading = true;

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _ageWallet = AgeWallet(
      clientId: '239472f9-3398-47ea-ad13-fe9502a0eb33',
      redirectUri: 'https://agewallet-sdk-demo.netlify.app/callback',
    );
    _checkVerification();

    if (Platform.isIOS) {
      _appLinks = AppLinks();
      _linkSub = _appLinks!.uriLinkStream.listen((uri) {
        if (uri.host == 'agewallet-sdk-demo.netlify.app' &&
            uri.path.startsWith('/callback')) {
          _handleCallback(uri.toString());
        }
      });
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    try {
      final isVerified = await _ageWallet.isVerified();
      setState(() {
        _isVerified = isVerified;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startVerification() async {
    setState(() => _isLoading = true);
    try {
      if (Platform.isIOS) {
        final url = await _ageWallet.buildVerificationURL();
        await launchUrl(url, mode: LaunchMode.externalApplication);
        // iOS: loading stays true until _handleCallback fires via Universal Link
      } else {
        await _ageWallet.startVerification();
        await _checkVerification();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    }
  }

  Future<void> _handleCallback(String url) async {
    setState(() => _isLoading = true);
    await _ageWallet.handleCallback(url);
    await _checkVerification();
  }

  Future<void> _clearVerification() async {
    await _ageWallet.clearVerification();
    setState(() => _isVerified = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: _isLoading
                ? const CircularProgressIndicator()
                : _isVerified
                    ? _buildVerifiedView()
                    : _buildUnverifiedView(),
          ),
        ),
      ),
    );
  }

  Widget _buildUnverifiedView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(
            Icons.lock_outline,
            size: 50,
            color: Color(0xFF6366F1),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Age Verification Required',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'You must verify your age to access this content.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startVerification,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Verify with AgeWallet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(
            Icons.check_circle_outline,
            size: 50,
            color: Color(0xFF10B981),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Age Verified',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'You have successfully verified your age.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _clearVerification,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'Clear Verification',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
