import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> resultat; // vient directement de la réponse de l'API

  const ResultScreen({super.key, required this.resultat});

  static const Color cream = Color(0xFFF6F1EA);

  // Texte des questions, pour traduire "Q6A" en quelque chose de lisible
  // dans la section "ce qui a le plus influencé ce résultat" (SHAP).
  static const Map<String, String> _questionTexte = {
    'Q1A': "J'ai eu du mal à me calmer",
    'Q2A': "J'ai senti ma bouche devenir sèche",
    'Q3A': "Je n'arrivais pas à éprouver de sentiment positif",
    'Q4A': "J'ai eu des difficultés à respirer",
    'Q5A': "J'ai eu du mal à trouver l'initiative de faire les choses",
    'Q6A': "J'ai eu tendance à réagir de manière excessive",
    'Q7A': "J'ai ressenti des tremblements",
    'Q8A': "J'ai senti que j'utilisais beaucoup d'énergie nerveuse",
    'Q9A': "Je me suis inquiété(e) de paniquer",
    'Q10A': "J'ai senti que je n'avais rien à espérer",
    'Q11A': "Je me suis senti(e) agité(e)",
    'Q12A': "J'ai eu du mal à me détendre",
    'Q13A': "Je me suis senti(e) triste et abattu(e)",
    'Q14A': "J'étais intolérant(e) à ce qui m'interrompait",
    'Q15A': "J'ai senti que j'étais proche de la panique",
    'Q16A': "Je n'arrivais pas à être enthousiaste",
    'Q17A': "J'ai senti que je ne valais pas grand-chose",
    'Q18A': "Je me suis senti(e) plutôt susceptible",
    'Q19A': "J'étais conscient(e) des battements de mon cœur",
    'Q20A': "Je me suis senti(e) effrayé(e) sans raison",
    'Q21A': "J'ai senti que la vie n'avait pas de sens",
  };

  // Conseil personnalisé par question — utilisé quand cette question fait
  // partie des facteurs qui ont le plus influencé le résultat (via SHAP),
  // plutôt qu'un conseil générique valable pour toute une catégorie.
  static const Map<String, String> _conseilParQuestion = {
    'Q1A': "Essaie des techniques de respiration ou de relaxation pour t'aider à te calmer plus facilement.",
    'Q2A': "Les symptômes physiques d'anxiété peuvent s'atténuer avec des exercices de respiration profonde.",
    'Q3A': "Essaie de noter chaque jour une petite chose agréable, même minime.",
    'Q4A': "Des exercices de respiration contrôlée peuvent aider à apaiser les sensations d'essoufflement.",
    'Q5A': "Fixe-toi des objectifs très petits et atteignables pour retrouver progressivement de l'élan.",
    'Q6A': "Prends un instant de pause avant de réagir aux imprévus.",
    'Q7A': "Des exercices de relaxation musculaire peuvent aider à apaiser la tension nerveuse.",
    'Q8A': "Canaliser cette énergie nerveuse dans une activité physique régulière peut t'aider.",
    'Q9A': "Identifier à l'avance les situations qui t'inquiètent peut aider à mieux les anticiper.",
    'Q10A': "Parler à un proche ou un professionnel peut aider à retrouver une perspective plus positive.",
    'Q11A': "Des pauses régulières dans ta journée peuvent réduire cette sensation d'agitation.",
    'Q12A': "Bloque un vrai moment de détente dans ta journée, sans distraction ni obligation.",
    'Q13A': "Ces sentiments méritent d'être écoutés — envisage d'en parler à quelqu'un de confiance.",
    'Q14A': "Essaie d'accepter que certaines interruptions sont hors de ton contrôle.",
    'Q15A': "Des techniques d'ancrage (respiration, 5 sens) peuvent aider à calmer une panique montante.",
    'Q16A': "Essaie de renouer, même brièvement, avec une activité qui te plaisait avant.",
    'Q17A': "Ce sentiment est fréquent en période difficile — en parler à un professionnel peut vraiment aider.",
    'Q18A': "Prendre un peu de recul avant de réagir aux remarques peut aider à limiter l'irritabilité.",
    'Q19A': "Ces sensations physiques sont courantes avec l'anxiété — la cohérence cardiaque peut aider.",
    'Q20A': "Identifier le moment où cette peur apparaît peut aider à mieux la comprendre.",
    'Q21A': "Ce sentiment est sérieux — en parler à un professionnel de santé est fortement recommandé.",
  };

  // Traduction des catégories réelles du modèle + couleur associée
  static const Map<String, Map<String, dynamic>> _categorieInfo = {
    'bien_etre': {'label': 'Bien-être stable', 'color': Color(0xFF2ED9B8)},
    'attention': {'label': 'À surveiller', 'color': Color(0xFFFFC24B)},
    'stress_modere': {'label': 'Stress modéré', 'color': Color(0xFFFF9F43)},
    'stress_eleve': {'label': 'Stress élevé', 'color': Color(0xFFFF6B6B)},
  };

  // Conseils génériques par catégorie — pas de diagnostic, juste des pistes
  static const Map<String, List<String>> _conseils = {
    'bien_etre': [
      'Continue tes habitudes actuelles, elles te réussissent.',
      'Un suivi régulier permet de repérer tôt tout changement.',
    ],
    'attention': [
      'Prends quelques minutes par jour pour te détendre (respiration, marche).',
      'Surveille ton sommeil, souvent lié à ces premiers signes.',
    ],
    'stress_modere': [
      "Intègre une activité physique régulière dans ta semaine.",
      'Limite les écrans avant le coucher pour un meilleur repos.',
      'Des exercices de respiration abdominale peuvent aider au quotidien.',
    ],
    'stress_eleve': [
      "Envisage d'en parler à un professionnel de santé.",
      'Réduis temporairement les sources de surcharge si possible.',
      'Des techniques de relaxation encadrées peuvent être utiles.',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final categorie = resultat['categorie'] as String? ?? 'attention';
    final confiance = (resultat['confiance'] as num?)?.toDouble() ?? 0.0;
    final scoreStress = resultat['score_stress'] as int? ?? 0;
    final scoreAnxiete = resultat['score_anxiete'] as int? ?? 0;
    final scoreDepression = resultat['score_depression'] as int? ?? 0;

    final info = _categorieInfo[categorie] ??
        {'label': categorie, 'color': Colors.grey};
    final topFacteurs = (resultat['top_facteurs'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Conseils personnalisés : un par facteur qui a RENFORCÉ le résultat
    // (contribution positive) — pas de conseil pour un facteur qui a
    // atténué le résultat, il n'y a rien à corriger là-dessus.
    final conseilsPersonnalises = topFacteurs
        .where((f) => (f['contribution'] as num) > 0)
        .map((f) => _conseilParQuestion[f['question']])
        .whereType<String>()
        .toList();

    // Repli sur les conseils génériques par catégorie si aucun facteur
    // n'a de conseil associé (ex. bien_etre, où rien ne "renforce" un problème).
    final conseils = conseilsPersonnalises.isNotEmpty
        ? conseilsPersonnalises
        : (_conseils[categorie] ?? []);
    final personnalise = conseilsPersonnalises.isNotEmpty;

    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.brown),
                  ),
                  const SizedBox(width: 12),
                  const Text('Résultat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),

              // Carte principale : catégorie prédite + confiance
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (info['color'] as Color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: info['color'] as Color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        info['label'] as String,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Fiabilité de cette prédiction : ${(confiance * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 13, color: Colors.brown),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('Détail par dimension', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildScoreBar('Stress', scoreStress, const Color(0xFFFF9F43)),
              const SizedBox(height: 10),
              _buildScoreBar('Anxiété', scoreAnxiete, const Color(0xFF6B5FA8)),
              const SizedBox(height: 10),
              _buildScoreBar('Dépression', scoreDepression, const Color(0xFF4E7FFF)),
              const SizedBox(height: 24),

              if (topFacteurs.isNotEmpty) ...[
                const Text(
                  'Ce qui a le plus influencé ce résultat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Calculé spécifiquement pour tes réponses (analyse SHAP)',
                  style: TextStyle(fontSize: 11, color: Colors.brown),
                ),
                const SizedBox(height: 12),
                ...topFacteurs.map((f) => _buildFacteurCard(f)),
                const SizedBox(height: 24),
              ],

              const Text('Recommandations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                personnalise
                    ? 'Basées sur tes réponses spécifiques'
                    : 'Recommandations générales',
                style: const TextStyle(fontSize: 11, color: Colors.brown),
              ),
              const SizedBox(height: 12),
              ...conseils.map(
                    (c) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(c, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Score sur 42 (7 questions x 3 max x 2), affiché comme une barre de progression
  // Une carte par facteur influent (issu de SHAP) : la question,
  // et si elle a renforcé ou atténué le résultat prédit.
  Widget _buildFacteurCard(Map<String, dynamic> facteur) {
    final question = facteur['question'] as String;
    final contribution = (facteur['contribution'] as num).toDouble();
    final texte = _questionTexte[question] ?? question;
    final renforce = contribution > 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(
            renforce ? Icons.arrow_upward : Icons.arrow_downward,
            color: renforce ? const Color(0xFFFF6B6B) : const Color(0xFF4E7FFF),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texte, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  renforce ? 'A renforcé ce résultat' : 'A légèrement atténué ce résultat',
                  style: TextStyle(
                    fontSize: 11,
                    color: renforce ? const Color(0xFFFF6B6B) : const Color(0xFF4E7FFF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBar(String label, int score, Color color) {
    final ratio = (score / 42).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('$score/42', style: const TextStyle(fontSize: 12, color: Colors.brown)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: Colors.brown.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}