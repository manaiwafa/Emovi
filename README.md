# 🧠 Emovi - Détection et analyse des émotions

Emovi est une application qui permet de détecter et analyser les émotions 
à partir de différentes sources (texte, voix, etc.) grâce à un modèle de 
Machine Learning.

## 🏗️ Architecture du projet

- **`emovi_app/`** : Application mobile Flutter (Dart)
- **`emovi_api/`** : API backend Python (FastAPI) avec modèles ML

## 🛠️ Technologies utilisées

| Composant | Technologie |
|-----------|-------------|
| Frontend mobile | Flutter / Dart |
| Backend | Python / FastAPI |
| Machine Learning | scikit-learn, pandas |
| Modèle | pipeline_emotions.pkl |

## 🚀 Installation et lancement

### Backend (API Python)
```bash
cd emovi_api
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
