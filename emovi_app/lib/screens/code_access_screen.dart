import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';

const String _apiBaseUrl = 'http://localhost:8000';

class CodeAccessScreen extends StatefulWidget {
  const CodeAccessScreen({super.key});

  @override
  State<CodeAccessScreen> createState() => _CodeAccessScreenState();
}

class _CodeAccessScreenState extends State<CodeAccessScreen> {
  final _codeController = TextEditingController();
  static const Color accent = Color(0xFF7F77DD);
  static const Color cream = Color(0xFFF6F1EA);

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool get _isValid => RegExp(r'^\d{4}$').hasMatch(_codeController.text);

  Future<void> _accederAuDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_apiBaseUrl/lookup-code')
          .replace(queryParameters: {'code_travail': _codeController.text});
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['exists'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('prenom', data['prenom'] as String);
          await prefs.setString('nom', data['nom'] as String);

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        } else {
          setState(() {
            _loading = false;
            _error = "Ce code n'existe pas encore. Complète d'abord un questionnaire.";
          });
        }
      } else {
        setState(() {
          _loading = false;
          _error = 'Erreur serveur, réessaie.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Impossible de contacter l'API.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.brown),
              ),
              const SizedBox(height: 20),
              _buildBanner(),
              const SizedBox(height: 28),
              const Text(
                'CODE DE TRAVAIL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accent,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                onChanged: (_) => setState(() => _error = null),
                keyboardType: TextInputType.number,
                maxLength: 4,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '••••',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.brown.withOpacity(0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: _error != null ? Colors.red : Colors.brown.withOpacity(0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _error != null ? Colors.red : accent),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isValid && !_loading) ? _accederAuDashboard : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text(
                    'Voir mon historique',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7F77DD), Color(0xFF9B6BFF)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Mon espace', style: TextStyle(color: Colors.white, fontSize: 14)),
                SizedBox(height: 8),
                Text(
                  'Entre ton code pour\nvoir ton historique',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const Text('🔑', style: TextStyle(fontSize: 36)),
        ],
      ),
    );
  }
}