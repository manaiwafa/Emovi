"""
main.py — API Émovi

Ce que fait ce fichier, dans l'ordre :
1. Au démarrage : charge une seule fois pipeline_emotions.pkl en mémoire
2. Expose un endpoint POST /predict que Flutter va appeler
3. Pour chaque requête : valide les réponses, fait la prédiction,
   sauvegarde dans MySQL, renvoie le résultat en JSON
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, Optional
import pandas as pd
import joblib
import mysql.connector
import json
import shap

# ------------------------------------------------------------------
# CONFIGURATION — à adapter avec tes vrais identifiants MySQL
# ------------------------------------------------------------------
DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "root",  
    "database": "emovi_db",
}

# Les 3 sous-échelles, dans le même regroupement que le notebook d'entraînement
STRESS_COLS = [f"Q{i}A" for i in [1, 6, 8, 11, 12, 14, 18]]
ANXIETE_COLS = [f"Q{i}A" for i in [2, 4, 7, 9, 15, 19, 20]]
DEPRESSION_COLS = [f"Q{i}A" for i in [3, 5, 10, 13, 16, 17, 21]]
ALL_COLS = STRESS_COLS + ANXIETE_COLS + DEPRESSION_COLS  # 21 colonnes attendues

# ------------------------------------------------------------------
# Chargement du modèle — une seule fois, au démarrage de l'API
# ------------------------------------------------------------------
pipeline = joblib.load("pipeline_emotions.pkl")

# Ordre exact des colonnes attendu par le pipeline (utile car l'ordre interne
# n'est pas forcément Q1..Q21, cf. ce qu'on avait découvert en inspectant le .pkl)
EXPECTED_COLS = list(pipeline.named_steps["scaler"].feature_names_in_)

#shap
background_summary = joblib.load("background_summary.pkl")
# On enveloppe pipeline.predict_proba dans une simple fonction plutôt que
# de la donner directement à SHAP : shap essaie sinon de modifier un attribut
# interne du Pipeline scikit-learn qui n'est pas modifiable, et plante.
def _predict_proba_pour_shap(X):
    df_X = pd.DataFrame(X, columns=EXPECTED_COLS)
    return pipeline.predict_proba(df_X)


shap_explainer = shap.KernelExplainer(_predict_proba_pour_shap, background_summary)

app = FastAPI(title="Émovi API")

# Autorise les appels depuis Flutter (mobile) et un navigateur (tests web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ------------------------------------------------------------------
# Format attendu du corps de la requête envoyée par Flutter
# ------------------------------------------------------------------
class PredictionRequest(BaseModel):
    prenom: str
    nom: str
    code_travail: Optional[str] = None
    reponses: Dict[str, int]  # ex: {"Q1A": 2, "Q6A": 0, ...} — 21 clés attendues


@app.get("/lookup-code")
def lookup_code(code_travail: str):
    """
    Cherche si ce code de travail (4 chiffres) est déjà associé à quelqu'un.
    Si oui, renvoie son prénom/nom pour que l'app les pré-remplisse
    automatiquement — évite de redemander à l'utilisateur de retaper
    exactement son nom à l'identique à chaque fois.
    """
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor(dictionary=True)

    cursor.execute(
        "SELECT prenom, nom FROM utilisateurs WHERE code_travail = %s LIMIT 1",
        (code_travail,),
    )
    row = cursor.fetchone()
    cursor.close()
    conn.close()

    if row:
        return {"exists": True, "prenom": row["prenom"], "nom": row["nom"]}
    return {"exists": False}


@app.get("/")
def health_check():
    """Juste pour vérifier que l'API tourne, en ouvrant l'URL dans un navigateur."""
    return {"status": "ok", "message": "Émovi API est en ligne"}


@app.post("/predict")
def predict(request: PredictionRequest):
    reponses = request.reponses

    # 1. Vérifier que les 21 réponses attendues sont bien présentes
    manquantes = [col for col in ALL_COLS if col not in reponses]
    if manquantes:
        raise HTTPException(
            status_code=400,
            detail=f"Réponses manquantes : {manquantes}",
        )

    # 2. Vérifier que chaque réponse est bien entre 0 et 3
    for col in ALL_COLS:
        if reponses[col] not in (0, 1, 2, 3):
            raise HTTPException(
                status_code=400,
                detail=f"Valeur invalide pour {col} : {reponses[col]} (attendu 0-3)",
            )

    # 3. Construire le DataFrame dans le BON ORDRE attendu par le pipeline
    df = pd.DataFrame([reponses])[EXPECTED_COLS]

    # 4. Prédiction
    categorie = pipeline.predict(df)[0]
    confiance = float(pipeline.predict_proba(df)[0].max())  # score de confiance réel

    # 4bis. SHAP — quelles réponses ont le plus influencé CETTE prédiction précise
    classe_index = list(pipeline.classes_).index(categorie)
    shap_values = shap_explainer.shap_values(df, nsamples=100)

    # Selon la version de shap, le format renvoyé change légèrement — on gère les deux
    if isinstance(shap_values, list):
        contributions = shap_values[classe_index][0]
    else:
        contributions = shap_values[0, :, classe_index]

    top_facteurs = sorted(
        zip(EXPECTED_COLS, contributions),
        key=lambda item: abs(item[1]),
        reverse=True,
    )[:3]

    top_facteurs_json = [
        {"question": col, "contribution": round(float(val), 3)}
        for col, val in top_facteurs
    ]

    # 5. Scores bruts par sous-échelle (les mêmes formules que le notebook)
    score_stress = int(sum(reponses[c] for c in STRESS_COLS) * 2)
    score_anxiete = int(sum(reponses[c] for c in ANXIETE_COLS) * 2)
    score_depression = int(sum(reponses[c] for c in DEPRESSION_COLS) * 2)

    # 6. Sauvegarde dans MySQL
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()

    # Si ce code de travail existe déjà, on réutilise cet utilisateur au lieu
    # d'en créer un nouveau (sinon ça viole la contrainte d'unicité sur
    # code_travail dès qu'une même personne repasse un test).
    utilisateur_id = None
    if request.code_travail:
        cursor.execute(
            "SELECT id FROM utilisateurs WHERE code_travail = %s",
            (request.code_travail,),
        )
        row = cursor.fetchone()
        if row:
            utilisateur_id = row[0]

    if utilisateur_id is None:
        cursor.execute(
            "INSERT INTO utilisateurs (prenom, nom, code_travail) VALUES (%s, %s, %s)",
            (request.prenom, request.nom, request.code_travail),
        )
        utilisateur_id = cursor.lastrowid

    cursor.execute(
        """INSERT INTO resultats
           (utilisateur_id, reponses, score_stress, score_anxiete, score_depression, categorie)
           VALUES (%s, %s, %s, %s, %s, %s)""",
        (
            utilisateur_id,
            json.dumps(reponses),
            score_stress,
            score_anxiete,
            score_depression,
            categorie,
        ),
    )
    conn.commit()
    cursor.close()
    conn.close()

    # 7. Réponse renvoyée à Flutter
    return {
        "categorie": categorie,
        "confiance": round(confiance, 3),
        "score_stress": score_stress,
        "score_anxiete": score_anxiete,
        "score_depression": score_depression,
        "top_facteurs": top_facteurs_json,
    }


# Traduction des catégories du modèle en libellés affichables
CATEGORIE_LABELS = {
    "bien_etre": "Bien-être stable",
    "attention": "À surveiller",
    "stress_modere": "Stress modéré",
    "stress_eleve": "Stress élevé",
}


@app.get("/stats")
def get_stats(prenom: str, nom: str):
    """
    Statistiques pour l'écran Profil : nombre de tests, dernier score,
    évolution récente, historique. Identifie l'utilisateur par
    prénom+nom (pas de vrai système de compte pour l'instant).
    """
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor(dictionary=True)

    cursor.execute(
        """
        SELECT r.score_stress, r.score_anxiete, r.score_depression,
               r.categorie, r.date_creation
        FROM resultats r
        JOIN utilisateurs u ON u.id = r.utilisateur_id
        WHERE u.prenom = %s AND u.nom = %s
        ORDER BY r.date_creation DESC
        """,
        (prenom, nom),
    )
    rows = cursor.fetchall()

    cursor.execute(
        """
        SELECT COUNT(*) AS regularite
        FROM resultats r
        JOIN utilisateurs u ON u.id = r.utilisateur_id
        WHERE u.prenom = %s AND u.nom = %s
          AND r.date_creation >= NOW() - INTERVAL 30 DAY
        """,
        (prenom, nom),
    )
    regularite = cursor.fetchone()["regularite"]

    cursor.close()
    conn.close()

    if not rows:
        raise HTTPException(status_code=404, detail="Aucun résultat trouvé pour cet utilisateur")

    dernier = rows[0]

    # Pour le graphique : les 5 derniers résultats, du plus ancien au plus récent
    historique_graphique = [
        {
            "date": r["date_creation"].strftime("%d/%m"),
            "score_stress": r["score_stress"],
        }
        for r in reversed(rows[:5])
    ]

    # Pour la liste "historique récent" : les 3 derniers, du plus récent au plus ancien
    historique_recent = [
        {
            "date": r["date_creation"].strftime("%d %B %Y"),
            "categorie": r["categorie"],
            "categorie_label": CATEGORIE_LABELS.get(r["categorie"], r["categorie"]),
        }
        for r in rows[:3]
    ]

    return {
        "tests_passes": len(rows),
        "dernier_score_stress": dernier["score_stress"],
        "niveau_actuel": CATEGORIE_LABELS.get(dernier["categorie"], dernier["categorie"]),
        "regularite": regularite,
        "historique_graphique": historique_graphique,
        "historique_recent": historique_recent,
    }


# ------------------------------------------------------------------
# ESPACE ADMIN — mot de passe simple pour la démo, à changer.
# Données UNIQUEMENT agrégées (pas de vue nominative individuelle),
# choix volontaire pour un outil de santé mentale en entreprise.
# ------------------------------------------------------------------
ADMIN_PASSWORD = "emovi_admin_2026"  # <-- change ce mot de passe


@app.get("/admin/stats")
def admin_stats(password: str):
    if password != ADMIN_PASSWORD:
        raise HTTPException(status_code=401, detail="Mot de passe incorrect")

    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor(dictionary=True)

    cursor.execute("SELECT COUNT(*) AS total FROM resultats")
    total_tests = cursor.fetchone()["total"]

    cursor.execute("SELECT COUNT(DISTINCT utilisateur_id) AS total FROM resultats")
    total_utilisateurs = cursor.fetchone()["total"]

    cursor.execute("SELECT categorie, COUNT(*) AS n FROM resultats GROUP BY categorie")
    repartition = cursor.fetchall()

    cursor.execute(
        """
        SELECT AVG(score_stress) AS m_stress,
               AVG(score_anxiete) AS m_anxiete,
               AVG(score_depression) AS m_depression
        FROM resultats
        """
    )
    moyennes = cursor.fetchone()

    cursor.close()
    conn.close()

    return {
        "total_tests": total_tests,
        "total_utilisateurs": total_utilisateurs,
        "repartition_categories": [
            {
                "categorie": r["categorie"],
                "categorie_label": CATEGORIE_LABELS.get(r["categorie"], r["categorie"]),
                "count": r["n"],
            }
            for r in repartition
        ],
        "moyenne_stress": round(float(moyennes["m_stress"] or 0), 1),
        "moyenne_anxiete": round(float(moyennes["m_anxiete"] or 0), 1),
        "moyenne_depression": round(float(moyennes["m_depression"] or 0), 1),
    }


@app.get("/admin/tendance")
def admin_tendance(password: str, granularite: str = "jour"):
    """
    Score de stress moyen agrégé dans le temps — vue bien-être/stress
    collective, PAS un indicateur de productivité (les deux ne sont
    pas la même chose, cf. discussion sur le cadrage de ce dashboard).
    """
    if password != ADMIN_PASSWORD:
        raise HTTPException(status_code=401, detail="Mot de passe incorrect")

    if granularite not in ("jour", "mois"):
        raise HTTPException(status_code=400, detail="granularite doit être 'jour' ou 'mois'")

    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor(dictionary=True)

    if granularite == "jour":
        cursor.execute(
            """
            SELECT DATE(date_creation) AS periode,
                   AVG(score_stress) AS score_moyen
            FROM resultats
            WHERE date_creation >= NOW() - INTERVAL 14 DAY
            GROUP BY DATE(date_creation)
            ORDER BY periode ASC
            """
        )
    else:
        cursor.execute(
            """
            SELECT DATE_FORMAT(date_creation, '%Y-%m') AS periode,
                   AVG(score_stress) AS score_moyen
            FROM resultats
            WHERE date_creation >= NOW() - INTERVAL 6 MONTH
            GROUP BY DATE_FORMAT(date_creation, '%Y-%m')
            ORDER BY periode ASC
            """
        )

    rows = cursor.fetchall()
    cursor.close()
    conn.close()

    return {
        "granularite": granularite,
        "points": [
            {
                "periode": str(r["periode"]),
                "score_moyen": round(float(r["score_moyen"]), 1),
            }
            for r in rows
        ],
    }