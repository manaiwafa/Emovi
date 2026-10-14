import 'package:flutter/material.dart';
import 'chargement_screen.dart';

class QuestionnaireScreen extends StatefulWidget {
  final String prenom;
  final String nom;
  final String codeTravail;

  const QuestionnaireScreen({
    super.key,
    required this.prenom,
    required this.nom,
    required this.codeTravail,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _Question {
  final int id; // correspond à Qid A dans le pipeline (ex: id=1 -> "Q1A")
  final String subscale; // 'Stress' | 'Anxiété' | 'Dépression'
  final String text;

  const _Question({required this.id, required this.subscale, required this.text});
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  int _currentIndex = 0;
  final Map<int, int> _answers = {}; // id de question -> valeur choisie (0-3)

  static const Color accent = Color(0xFF6B5FA8); // violet, cohérent avec l'écran d'identification
  static const Color cream = Color(0xFFF6F1EA);

  // Les 21 questions du DASS-21, regroupées par section (Stress, puis Anxiété,
  // puis Dépression) pour l'affichage — recommandation de l'encadrant.
  // ATTENTION : cet ordre d'affichage n'a pas besoin de correspondre à l'ordre
  // interne du pipeline (qui utilise les noms de colonnes Q{id}A, pas la position).
  static const List<_Question> _questions = [
    // --- Section Stress (7 questions) ---
    _Question(id: 1, subscale: 'Stress', text: "J'ai eu du mal à me calmer"),
    _Question(id: 6, subscale: 'Stress', text: "J'ai eu tendance à réagir de manière excessive aux situations"),
    _Question(id: 8, subscale: 'Stress', text: "J'ai senti que j'utilisais beaucoup d'énergie nerveuse"),
    _Question(id: 11, subscale: 'Stress', text: "Je me suis senti(e) agité(e)"),
    _Question(id: 12, subscale: 'Stress', text: "J'ai eu du mal à me détendre"),
    _Question(id: 14, subscale: 'Stress', text: "J'étais intolérant(e) à tout ce qui m'empêchait de continuer"),
    _Question(id: 18, subscale: 'Stress', text: "Je me suis senti(e) plutôt susceptible"),
    // --- Section Anxiété (7 questions) ---
    _Question(id: 2, subscale: 'Anxiété', text: "J'ai senti ma bouche devenir sèche"),
    _Question(id: 4, subscale: 'Anxiété', text: "J'ai eu des difficultés à respirer (essoufflement sans effort)"),
    _Question(id: 7, subscale: 'Anxiété', text: "J'ai ressenti des tremblements (par exemple dans les mains)"),
    _Question(id: 9, subscale: 'Anxiété', text: "Je me suis inquiété(e) de situations où je pourrais paniquer"),
    _Question(id: 15, subscale: 'Anxiété', text: "J'ai senti que j'étais proche de la panique"),
    _Question(id: 19, subscale: 'Anxiété', text: "J'étais conscient(e) des battements de mon cœur sans effort"),
    _Question(id: 20, subscale: 'Anxiété', text: "Je me suis senti(e) effrayé(e) sans raison valable"),
    // --- Section Dépression (7 questions) ---
    _Question(id: 3, subscale: 'Dépression', text: "Je n'arrivais pas à éprouver de sentiment positif"),
    _Question(id: 5, subscale: 'Dépression', text: "J'ai eu du mal à trouver l'initiative de faire les choses"),
    _Question(id: 10, subscale: 'Dépression', text: "J'ai senti que je n'avais rien à espérer"),
    _Question(id: 13, subscale: 'Dépression', text: "Je me suis senti(e) triste et abattu(e)"),
    _Question(id: 16, subscale: 'Dépression', text: "Je n'arrivais pas à être enthousiaste pour quoi que ce soit"),
    _Question(id: 17, subscale: 'Dépression', text: "J'ai senti que je ne valais pas grand-chose"),
    _Question(id: 21, subscale: 'Dépression', text: "J'ai senti que la vie n'avait pas de sens"),
  ];

  static const List<Map<String, String>> _options = [
    {'emoji': '😊', 'label': 'Jamais'},
    {'emoji': '🙂', 'label': 'Parfois'},
    {'emoji': '😐', 'label': 'Souvent'},
    {'emoji': '😟', 'label': 'Toujours'},
  ];

  _Question get _currentQuestion => _questions[_currentIndex];
  int? get _selectedValue => _answers[_currentQuestion.id];
  bool get _isLast => _currentIndex == _questions.length - 1;

  // Combien de questions dans la section courante (Stress/Anxiété/Dépression)
  int get _sectionSize =>
      _questions.where((q) => q.subscale == _currentQuestion.subscale).length;

  // Position de la question courante au sein de sa section (1-based)
  int get _positionInSection {
    var count = 0;
    for (final q in _questions) {
      if (q.subscale == _currentQuestion.subscale) {
        count++;
        if (q.id == _currentQuestion.id) break;
      }
    }
    return count;
  }

  void _goBack() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    } else {
      Navigator.pop(context);
    }
  }

  void _goNext() {
    if (_isLast) {
      final payload = {
        for (final entry in _answers.entries) 'Q${entry.key}A': entry.value
      };
      debugPrint('Réponses prêtes à être envoyées : $payload');

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChargementScreen(
            prenom: widget.prenom,
            nom: widget.nom,
            codeTravail: widget.codeTravail,
            reponses: payload,
          ),
        ),
      );
    } else {
      setState(() => _currentIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _positionInSection / _sectionSize;

    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barre de progression + bouton retour
              Row(
                children: [
                  GestureDetector(
                    onTap: _goBack,
                    child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.brown),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.brown.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$_positionInSection/$_sectionSize',
                    style: const TextStyle(fontSize: 12, color: Colors.brown),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Tout le contenu variable (question + grille) peut défiler
              // si l'écran est trop petit, plutôt que de déborder.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sous-échelle + question
                      Text(
                        'Question $_positionInSection de $_sectionSize — ${_currentQuestion.subscale}',
                        style: const TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currentQuestion.text,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),

                      // Grille 2x2 des réponses
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _options.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.3,
                        ),
                        itemBuilder: (context, index) {
                          final isSelected = _selectedValue == index;
                          return GestureDetector(
                            onTap: () => setState(() => _answers[_currentQuestion.id] = index),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? accent.withOpacity(0.12) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? accent : Colors.brown.withOpacity(0.15),
                                  width: isSelected ? 2 : 0.5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_options[index]['emoji']!, style: const TextStyle(fontSize: 24)),
                                  const SizedBox(height: 6),
                                  Text(
                                    _options[index]['label']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected ? accent : Colors.black87,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bouton Suivant / Terminer — toujours visible, en dehors du scroll
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _selectedValue != null ? _goNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _isLast ? 'Terminer' : 'Suivant',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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