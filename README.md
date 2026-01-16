# 🏠 DVF Analytics - Plateforme de Données Immobilières France

[![dbt](https://img.shields.io/badge/dbt-1.0+-orange.svg)](https://www.getdbt.com/)
[![Snowflake](https://img.shields.io/badge/Snowflake-Ready-29B5E8.svg)](https://www.snowflake.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Plateforme moderne de data engineering pour l'analyse du marché immobilier français basée sur les données ouvertes DVF (Demandes de Valeurs Foncières)

## 📊 Vue d'ensemble

**DVF Analytics** est un projet dbt (data build tool) qui transforme les données brutes des transactions immobilières françaises en une plateforme d'analyse prête à l'emploi. Ce projet implémente les **meilleures pratiques de data engineering** avec une architecture en couches (medallion architecture) et un modèle dimensionnel optimisé pour la business intelligence.

### 🎯 Cas d'usage

- **Analyse du marché immobilier** : Évolution des prix, tendances par zone géographique
- **Business Intelligence** : Tableaux de bord Power BI, Tableau, Looker
- **Data Science** : Modèles prédictifs, détection d'anomalies, estimation de prix
- **Études statistiques** : Recherche académique, études de marché
- **Applications métier** : Outils d'aide à la décision pour professionnels de l'immobilier

## ✨ Fonctionnalités principales

### 🏗️ Architecture moderne
- **Medallion Architecture** : Bronze → Silver → Gold
- **Star Schema** : Modèle dimensionnel optimisé pour les requêtes analytiques
- **Incremental Processing** : Pipeline de transformation performant avec dbt
- **Data Quality** : Tests automatisés sur la qualité des données

### 📐 Modèle de données

#### 🥈 Couche Silver (Staging)
Nettoyage et standardisation des données brutes :
- Conversion des types de données (dates, montants, surfaces)
- Normalisation des chaînes de caractères
- Filtrage des transactions valides (ventes > 20 000€)

#### 🥇 Couche Gold (Analytics)
Modèle en étoile prêt pour l'analyse :

**5 Tables de dimensions :**
- `dim_address` : Référentiel des adresses normalisées
- `dim_commune` : Référentiel des communes françaises
- `dim_parcelle` : Référentiel cadastral des parcelles
- `dim_type_local` : Types de biens (maison, appartement, local commercial...)
- `dim_code_postal` : Référentiel géographique par code postal

**1 Table de faits :**
- `fact_mutation` : Transactions immobilières avec mesures (valeur foncière, surfaces, nombre de pièces)

### 🔍 Qualité des données
- **Tests dbt intégrés** : Unicité, non-nullité, intégrité référentielle
- **Traçabilité** : Flag `ADDRESS_MATCH_STRATEGY` pour suivre la qualité des jointures
- **Documentation complète** : Chaque colonne documentée dans `schema.yml`
- **Data lineage** : Vue claire des transformations source → cible

### 🚀 Performance
- **Matérialisation optimisée** : Vues pour Silver, tables pour Gold
- **Clés techniques hashées** : Jointures performantes avec HASH(colonnes)
- **Indexation naturelle** : Clés primaires et étrangères pour requêtes rapides

## 📦 Structure du projet

```
dbt_dvf/
├── models/
│   ├── silver/               # Couche de nettoyage
│   │   ├── dvf_silver.sql   # Données DVF standardisées
│   │   └── schema.yml       # Documentation + tests
│   │
│   └── gold/                 # Couche analytique
│       ├── dim_address.sql       # Dimension Adresse
│       ├── dim_commune.sql       # Dimension Commune
│       ├── dim_parcelle.sql      # Dimension Parcelle cadastrale
│       ├── dim_type_local.sql    # Dimension Type de bien
│       ├── dim_code_postal.sql   # Dimension Code postal
│       ├── fact_mutation.sql     # Table de faits - Transactions
│       └── schema.yml            # Documentation + tests
│
├── macros/
│   └── generate_schema_name.sql  # Configuration des schémas
│
├── dbt_project.yml               # Configuration dbt
└── README.md
```

## 🚀 Guide de démarrage rapide

### Prérequis

- **dbt** >= 1.0
- **Snowflake** (ou adapter dbt compatible)
- **Accès aux données DVF** : [data.gouv.fr](https://www.data.gouv.fr/fr/datasets/demandes-de-valeurs-foncieres/)

### Installation

```bash
# Cloner le repository
git clone https://github.com/votre-username/dbt_dvf.git
cd dbt_dvf

# Installer les dépendances dbt
dbt deps

# Configurer votre profil Snowflake dans ~/.dbt/profiles.yml
```

### Configuration `profiles.yml`

```yaml
dvf:
  outputs:
    dev:
      type: snowflake
      account: votre_account
      user: votre_user
      password: votre_password
      role: votre_role
      database: VALFONC_ANALYTICS_DBT
      warehouse: COMPUTE_WH
      schema: PUBLIC
      threads: 4
  target: dev
```

### Exécution

```bash
# Vérifier la configuration
dbt debug

# Compiler les modèles
dbt compile

# Exécuter toutes les transformations
dbt run

# Lancer les tests de qualité
dbt test

# Générer la documentation
dbt docs generate
dbt docs serve
```

## 📚 Documentation technique

### Source de données : DVF (Demandes de Valeurs Foncières)

Les **Demandes de Valeurs Foncières (DVF)** sont des données publiques françaises qui recensent l'ensemble des transactions immobilières des 5 dernières années. Ces données sont publiées par la **Direction Générale des Finances Publiques (DGFiP)**.

**Couverture géographique :**
- France métropolitaine
- Départements d'Outre-Mer (DOM)

**Contenu :**
- Date et nature de la mutation
- Prix de vente (valeur foncière)
- Adresse du bien
- Référence cadastrale
- Caractéristiques du bien (type, surface, nombre de pièces)

**Mise à jour :** Semestrielle (avril et octobre)

### Modèle de données détaillé

#### Table de faits : `fact_mutation`

**Grain :** Une ligne = Une transaction immobilière (vente)

**Clés étrangères :**
- `ADDRESS_ID` → `dim_address.ADDRESS_ID`
- `COMMUNE_ID` → `dim_commune.COMMUNE_ID`
- `PARCELLE_ID` → `dim_parcelle.PARCELLE_ID`
- `TYPE_LOCAL_ID` → `dim_type_local.TYPE_LOCAL_ID`
- `CODE_POSTAL_ID` → `dim_code_postal.CODE_POSTAL_ID`

**Mesures numériques :**
- `VALEUR_FONCIERE` : Prix de vente en euros
- `SURFACE_REELLE_BATI` : Surface habitable en m²
- `SURFACE_TERRAIN` : Surface du terrain en m²
- `NOMBRE_PIECES_PRINCIPALES` : Nombre de pièces

**Attributs de qualité :**
- `ADDRESS_MATCH_STRATEGY` : Indicateur de qualité du lien adresse
  - `MATCH_ADDRESS` : Jointure exacte ✅
  - `FALLBACK_COMMUNE` : Fallback au niveau commune ⚠️
  - `NO_MATCH` : Aucun match ❌

### Exemples de requêtes analytiques

```sql
-- Prix médian par commune en 2024
SELECT
    c.COMMUNE,
    c.CODE_DEPARTEMENT,
    MEDIAN(f.VALEUR_FONCIERE) as prix_median,
    COUNT(*) as nb_ventes
FROM gold.fact_mutation f
JOIN gold.dim_commune c ON f.COMMUNE_ID = c.COMMUNE_ID
WHERE YEAR(f.DATE_MUTATION) = 2024
GROUP BY c.COMMUNE, c.CODE_DEPARTEMENT
ORDER BY prix_median DESC;

-- Évolution temporelle du prix au m² pour les appartements
SELECT
    DATE_TRUNC('MONTH', f.DATE_MUTATION) as mois,
    AVG(f.VALEUR_FONCIERE / NULLIF(f.SURFACE_REELLE_BATI, 0)) as prix_m2_moyen
FROM gold.fact_mutation f
JOIN gold.dim_type_local t ON f.TYPE_LOCAL_ID = t.TYPE_LOCAL_ID
WHERE t.TYPE_LOCAL = 'Appartement'
    AND f.SURFACE_REELLE_BATI > 0
    AND f.VALEUR_FONCIERE > 0
GROUP BY mois
ORDER BY mois;

-- Top 10 des villes avec le plus de transactions
SELECT
    c.COMMUNE,
    c.CODE_DEPARTEMENT,
    COUNT(*) as nb_transactions,
    SUM(f.VALEUR_FONCIERE) as volume_total
FROM gold.fact_mutation f
JOIN gold.dim_commune c ON f.COMMUNE_ID = c.COMMUNE_ID
GROUP BY c.COMMUNE, c.CODE_DEPARTEMENT
ORDER BY nb_transactions DESC
LIMIT 10;
```

## 🎯 Bonnes pratiques implémentées

### Data Engineering
- ✅ **Separation of Concerns** : Couches Bronze/Silver/Gold clairement séparées
- ✅ **Idempotence** : Les transformations peuvent être rejouées sans effet de bord
- ✅ **Scalability** : Architecture conçue pour gérer des millions de transactions
- ✅ **Observability** : Logs dbt, tests, documentation auto-générée

### Data Modeling
- ✅ **Star Schema** : Optimisé pour les requêtes analytiques
- ✅ **Surrogate Keys** : Clés techniques via HASH() pour indépendance des sources
- ✅ **Slowly Changing Dimensions** : Architecture prête pour gérer l'historisation
- ✅ **Data Quality Flags** : `ADDRESS_MATCH_STRATEGY`, `IS_PARTIAL`

### Data Governance
- ✅ **Documentation** : Toutes les colonnes documentées dans `schema.yml`
- ✅ **Data Lineage** : Traçabilité complète avec dbt
- ✅ **Data Testing** : Tests automatisés (unicité, non-nullité, FK, valeurs acceptées)
- ✅ **Metadata** : Colonnes `CREATED_AT`, `SOURCE_SYSTEM` pour audit

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :

1. Fork le projet
2. Créer une branche pour votre fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. Commiter vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Pousser vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

### Idées d'améliorations

- 🗺️ Enrichissement avec données géographiques (latitude/longitude)
- 📊 Ajout de métriques pré-calculées (prix au m², évolutions)
- 🔄 Implémentation de SCD Type 2 pour historisation des dimensions
- 🧪 Tests avancés avec dbt-expectations
- 🚀 CI/CD avec GitHub Actions
- 📈 Tableaux de bord Power BI / Tableau prêts à l'emploi

## 📖 Ressources

### Documentation officielle
- [dbt Documentation](https://docs.getdbt.com/)
- [Données DVF sur data.gouv.fr](https://www.data.gouv.fr/fr/datasets/demandes-de-valeurs-foncieres/)
- [Snowflake Documentation](https://docs.snowflake.com/)

### Articles & Tutoriels
- [Medallion Architecture](https://www.databricks.com/glossary/medallion-architecture)
- [Star Schema Design](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/)
- [dbt Best Practices](https://docs.getdbt.com/guides/best-practices)

## 📄 License

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

## 👤 Auteur

**Votre Nom**
- GitHub: [@votre-username](https://github.com/lucaszub)
- LinkedIn: [Votre Profil](https://www.linkedin.com/in/lucas-zubiarrain/)


---

