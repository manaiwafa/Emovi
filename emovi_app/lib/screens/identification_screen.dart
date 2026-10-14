import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'questionnaire_screen.dart';

// Même adresse que les autres écrans réseau — à factoriser dans un seul
// fichier de config si tu veux éviter de la dupliquer partout.
const String _apiBaseUrl = 'http://localhost:8000';

class IdentificationScreen extends StatefulWidget {
  const IdentificationScreen({super.key});

  @override
  State<IdentificationScreen> createState() => _IdentificationScreenState();
}

class _IdentificationScreenState extends State<IdentificationScreen> {
  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _codeController = TextEditingController();

  // null = pas encore vérifié, 'checking', 'found' (retour), 'not_found' (nouveau)
  String? _lookupStatus;
  Timer? _debounce;

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _codeController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  bool get _isReturningUser => _lookupStatus == 'found';

  bool get _isValid =>
      RegExp(r'^\d{4}$').hasMatch(_codeController.text) &&
          _lookupStatus != null &&
          _lookupStatus != 'checking' &&
          _prenomController.text.trim().isNotEmpty &&
          _nomController.text.trim().isNotEmpty;

  void _onCodeChanged(String value) {
    _debounce?.cancel();

    if (!RegExp(r'^\d{4}$').hasMatch(value)) {
      setState(() {
        _lookupStatus = null;
        _prenomController.clear();
        _nomController.clear();
      });
      return;
    }

    setState(() => _lookupStatus = 'checking');
    _debounce = Timer(const Duration(milliseconds: 400), _lookupCode);
  }

  Future<void> _lookupCode() async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/lookup-code')
          .replace(queryParameters: {'code_travail': _codeController.text});
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['exists'] == true) {
          setState(() {
            _prenomController.text = data['prenom'] as String;
            _nomController.text = data['nom'] as String;
            _lookupStatus = 'found';
          });
        } else {
          setState(() {
            _prenomController.clear();
            _nomController.clear();
            _lookupStatus = 'not_found';
          });
        }
      } else {
        setState(() => _lookupStatus = null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _lookupStatus = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1EA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBanner(),
              const SizedBox(height: 28),
              _buildCodeField(),
              const SizedBox(height: 20),
              _buildField(
                label: 'PRÉNOM',
                emoji: '😊',
                controller: _prenomController,
                hint: 'Ex : Sophie',
                readOnly: _isReturningUser,
              ),
              const SizedBox(height: 20),
              _buildField(
                label: 'NOM',
                emoji: '📝',
                controller: _nomController,
                hint: 'Ex : Arnaud',
                readOnly: _isReturningUser,
              ),
              const SizedBox(height: 36),
              _buildStartButton(),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '‹ Retour à l\'accueil',
                    style: TextStyle(color: Colors.brown, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    Text(
                      'Avant de commencer',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.assignment_outlined, color: Colors.white, size: 16),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Qui êtes-vous ?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const Text('🙋', style: TextStyle(fontSize: 40)),
        ],
      ),
    );
  }

  Widget _buildCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🏷️', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            const Text(
              'CODE DE TRAVAIL (4 CHIFFRES)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B5FA8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          onChanged: _onCodeChanged,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: 'Ex : 1234',
            hintStyle: const TextStyle(color: Colors.brown, fontSize: 14),
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: _buildStatusIcon(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.brown.withOpacity(0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.brown.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
            ),
          ),
        ),
        if (_lookupStatus != null) ...[
          const SizedBox(height: 6),
          _buildStatusMessage(),
        ],
      ],
    );
  }

  Widget? _buildStatusIcon() {
    switch (_lookupStatus) {
      case 'checking':
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6B5FA8)),
          ),
        );
      case 'found':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'not_found':
        return const Icon(Icons.person_add_alt_1, color: Color(0xFF6B5FA8));
      default:
        return null;
    }
  }

  Widget _buildStatusMessage() {
    late final String text;
    late final Color color;

    switch (_lookupStatus) {
      case 'found':
        text = '✓ Bon retour ! Tes informations ont été retrouvées.';
        color = Colors.green;
        break;
      case 'not_found':
        text = 'Nouveau code — complète ton prénom et nom ci-dessous.';
        color = const Color(0xFF6B5FA8);
        break;
      default:
        text = '';
        color = Colors.transparent;
    }

    return Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500));
  }

  Widget _buildField({
    required String label,
    required String emoji,
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B5FA8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.brown, fontSize: 14),
            filled: true,
            fillColor: readOnly ? const Color(0xFFEDE8DE) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.brown.withOpacity(0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.brown.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return InkWell(
      onTap: _isValid
          ? () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('prenom', _prenomController.text.trim());
        await prefs.setString('nom', _nomController.text.trim());

        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuestionnaireScreen(
              prenom: _prenomController.text.trim(),
              nom: _nomController.text.trim(),
              codeTravail: _codeController.text.trim(),
            ),
          ),
        );
      }
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: _isValid
                ? const [Color(0xFFFF6B6B), Color(0xFFFF9F43)]
                : [Colors.grey.shade300, Colors.grey.shade300],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '⚡',
              style: TextStyle(
                fontSize: 16,
                color: _isValid ? Colors.white : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Démarrer le questionnaire',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isValid ? Colors.white : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}