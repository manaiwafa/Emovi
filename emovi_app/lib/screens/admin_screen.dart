import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

const String _apiBaseUrl = 'http://localhost:8000';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const Color cream = Color(0xFFF6F1EA);
  static const Color accent = Color(0xFF3B3B3B);

  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _stats;

  String _granularite = 'jour';
  List<Map<String, dynamic>>? _tendance;
  bool _loadingTendance = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_apiBaseUrl/admin/stats')
          .replace(queryParameters: {'password': _passwordController.text});
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(response.body) as Map<String, dynamic>;
          _loading = false;
        });
        _loadTendance();
      } else if (response.statusCode == 401) {
        setState(() {
          _loading = false;
          _error = 'Mot de passe incorrect.';
        });
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
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.brown),
                  ),
                  const SizedBox(width: 12),
                  const Text('Espace admin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _stats == null ? _buildLogin() : _buildDashboard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadTendance() async {
    setState(() => _loadingTendance = true);

    try {
      final uri = Uri.parse('$_apiBaseUrl/admin/tendance').replace(queryParameters: {
        'password': _passwordController.text,
        'granularite': _granularite,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _tendance = (data['points'] as List).cast<Map<String, dynamic>>();
          _loadingTendance = false;
        });
      } else {
        setState(() => _loadingTendance = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingTendance = false);
    }
  }

  Widget _buildLogin() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 40, color: accent),
          const SizedBox(height: 16),
          const Text('Accès réservé', style: TextStyle(fontSize: 15, color: Colors.brown)),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onSubmitted: (_) => _login(),
            decoration: InputDecoration(
              hintText: 'Mot de passe',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.brown.withOpacity(0.15)),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(backgroundColor: accent),
              child: _loading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Entrer', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final stats = _stats!;
    final repartition = (stats['repartition_categories'] as List).cast<Map<String, dynamic>>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _AdminStatCard(label: 'Tests réalisés', value: '${stats['total_tests']}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdminStatCard(label: 'Personnes', value: '${stats['total_utilisateurs']}'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Répartition des catégories', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(height: 180, child: _buildBarChart(repartition)),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Évolution du stress moyen', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              _buildGranulariteToggle(),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Indicateur de bien-être/stress ",
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 180, child: _buildTendanceChart()),
          const SizedBox(height: 24),

          const Text('Scores moyens (sur 42)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildMoyenne('Stress', stats['moyenne_stress']),
          _buildMoyenne('Anxiété', stats['moyenne_anxiete']),
          _buildMoyenne('Dépression', stats['moyenne_depression']),
          const SizedBox(height: 20),
          const Text(
            'Données agrégées uniquement — aucune information individuelle nominative n\'est affichée ici.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> repartition) {
    if (repartition.isEmpty) {
      return const Center(child: Text('Pas encore de données', style: TextStyle(color: Colors.grey)));
    }
    final maxCount = repartition.map((r) => r['count'] as int).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: (maxCount + 1).toDouble(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= repartition.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    repartition[i]['categorie_label'],
                    style: const TextStyle(fontSize: 9, color: Colors.brown),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < repartition.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: (repartition[i]['count'] as int).toDouble(),
                color: const Color(0xFF7F77DD),
                width: 28,
                borderRadius: BorderRadius.circular(6),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildGranulariteToggle() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _toggleButton('Jour', 'jour'),
          _toggleButton('Mois', 'mois'),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, String value) {
    final selected = _granularite == value;
    return GestureDetector(
      onTap: () {
        if (_granularite != value) {
          setState(() => _granularite = value);
          _loadTendance();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : Colors.brown,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTendanceChart() {
    if (_loadingTendance) {
      return const Center(child: CircularProgressIndicator(color: accent));
    }
    if (_tendance == null || _tendance!.isEmpty) {
      return const Center(child: Text('Pas assez de données', style: TextStyle(color: Colors.grey)));
    }

    final points = _tendance!;
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), (points[i]['score_moyen'] as num).toDouble()),
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 42,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                // Affiche une étiquette sur deux si beaucoup de points, pour ne pas surcharger
                if (points.length > 8 && i % 2 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[i]['periode'].toString().substring(5), // coupe l'année si présente
                    style: const TextStyle(fontSize: 9, color: Colors.brown),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF2A78D6),
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: const Color(0xFF2A78D6).withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildMoyenne(String label, dynamic value) {
    final v = (value as num).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${v.toStringAsFixed(1)}/42', style: const TextStyle(fontSize: 12, color: Colors.brown)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (v / 42).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.brown.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7F77DD)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _AdminStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.brown)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}