import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'result_screen.dart';

// ------------------------------------------------------------------
// ADRESSE DE L'API — remplace par l'IP locale de ton PC (ipconfig,
// ligne "Adresse IPv4" de ta carte WiFi). Ton téléphone et ton PC
// doivent être sur le même réseau WiFi.
// ------------------------------------------------------------------
const String apiBaseUrl = 'http://localhost:8000';
class ChargementScreen extends StatefulWidget {
  final String prenom;
  final String nom;
  final String codeTravail;
  final Map<String, int> reponses;

  const ChargementScreen({
    super.key,
    required this.prenom,
    required this.nom,
    required this.codeTravail,
    required this.reponses,
  });

  @override
  State<ChargementScreen> createState() => _ChargementScreenState();
}

class _ChargementScreenState extends State<ChargementScreen> {
  static const Color accent = Color(0xFF6B5FA8);
  static const Color cream = Color(0xFFF6F1EA);

  static const List<String> _messages = [
    'Analyse du stress...',
    "Analyse de l'anxiété...",
    'Analyse de la dépression...',
    'Croisement des réponses...',
    'Calcul du résultat...',
  ];

  int _messageIndex = 0;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startMessageCycle();
    _callApi();
  }

  void _startMessageCycle() {
    _timer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (_messageIndex < _messages.length - 1) {
        setState(() => _messageIndex++);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _callApi() async {
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'prenom': widget.prenom,
              'nom': widget.nom,
              'code_travail': widget.codeTravail,
              'reponses': widget.reponses,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ResultScreen(resultat: data)),
        );
      } else {
        setState(() {
          _errorMessage = 'Erreur serveur (${response.statusCode}). Réessaie.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            "Impossible de contacter l'API. Vérifie que le serveur tourne "
            "et que ton téléphone est sur le même WiFi que ton PC.";
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _errorMessage != null
                ? [
                    const Icon(Icons.wifi_off, size: 48, color: Colors.brown),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.brown, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _errorMessage = null);
                        _callApi();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: accent),
                      child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                    ),
                  ]
                : [
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _messages[_messageIndex],
                        key: ValueKey(_messageIndex),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.brown,
                        ),
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}