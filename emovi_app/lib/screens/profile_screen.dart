import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

// Même adresse que chargement_screen.dart — pense à les garder synchronisées,
// ou factorise-les dans un seul fichier de config plus tard.
const String _apiBaseUrl = 'http://localhost:8000';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color cream = Color(0xFFF6F1EA);
  static const Color accent = Color(0xFF7F77DD);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _stats;
  String _prenom = '';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final prenom = prefs.getString('prenom');
    final nom = prefs.getString('nom');

    if (prenom == null || nom == null) {
      setState(() {
        _loading = false;
        _error = "Passe d'abord un questionnaire pour voir ton profil.";
      });
      return;
    }

    _prenom = prenom;

    try {
      final uri = Uri.parse('$_apiBaseUrl/stats').replace(queryParameters: {
        'prenom': prenom,
        'nom': nom,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(response.body) as Map<String, dynamic>;
          _loading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _loading = false;
          _error = "Passe d'abord un questionnaire pour voir ton profil.";
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Erreur serveur (${response.statusCode}).';
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
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: accent))
            : _error != null
            ? _buildError()
            : RefreshIndicator(
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off_outlined, size: 48, color: Colors.brown),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.brown)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStats,
              style: ElevatedButton.styleFrom(backgroundColor: accent),
              child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final stats = _stats!;
    final historique = (stats['historique_graphique'] as List).cast<Map<String, dynamic>>();
    final recent = (stats['historique_recent'] as List).cast<Map<String, dynamic>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFEEEDFE),
              child: Text(
                _prenom.isNotEmpty ? _prenom[0].toUpperCase() : '?',
                style: const TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Text('Bonjour $_prenom 👋', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 20),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _StatCard(
              icon: Icons.assignment_turned_in_outlined,
              color: const Color(0xFFFFA95F),
              label: 'Tests passés',
              value: '${stats['tests_passes']}',
            ),
            _StatCard(
              icon: Icons.sentiment_satisfied_alt_outlined,
              color: const Color(0xFF2ED9B8),
              label: 'Dernier score',
              value: '${stats['dernier_score_stress']}/42',
            ),
            _StatCard(
              icon: Icons.favorite_outline,
              color: accent,
              label: 'Niveau actuel',
              value: '${stats['niveau_actuel']}',
              small: true,
            ),
            _StatCard(
              icon: Icons.local_fire_department_outlined,
              color: const Color(0xFFD4537E),
              label: 'Régularité',
              value: '${stats['regularite']}/mois',
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (historique.length > 1) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ton évolution récente', style: TextStyle(fontSize: 13, color: Colors.brown)),
                const SizedBox(height: 12),
                SizedBox(height: 140, child: _buildChart(historique)),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        const Text('Historique récent', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...recent.map((r) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(r['date'], style: const TextStyle(fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  r['categorie_label'],
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: accent),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildChart(List<Map<String, dynamic>> historique) {
    final spots = <FlSpot>[
      for (var i = 0; i < historique.length; i++)
        FlSpot(i.toDouble(), (historique[i]['score_stress'] as int).toDouble()),
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 42,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= historique.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(historique[i]['date'], style: const TextStyle(fontSize: 10, color: Colors.brown)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: accent,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: accent.withOpacity(0.12)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool small;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: small ? 14 : 20, fontWeight: FontWeight.w600, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}