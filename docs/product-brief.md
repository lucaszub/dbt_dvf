# DVF Analytics - Product Brief

> **Plateforme d'analyse du marché immobilier français - Portfolio End-to-End Data Engineering**

---

## 1. Vision Produit

### 1.1 Objectif Principal

Créer une **plateforme de visualisation interactive** des prix immobiliers en France, démontrant une maîtrise complète de la chaîne de valeur Data Engineering :

- **Ingestion** : Collecte et chargement des données ouvertes (DVF + BAN)
- **Transformation** : Pipeline dbt avec architecture Medallion
- **Stockage** : Data Warehouse Snowflake en Star Schema
- **Orchestration** : Apache Airflow (standard industrie)
- **Visualisation** : Application Streamlit interactive
- **Infrastructure** : Déploiement Azure Container Apps + Terraform

### 1.2 Cible Audience

| Audience | Besoin | Ce que le projet démontre |
|----------|--------|---------------------------|
| **Recruteurs techniques CGI** | Évaluer le niveau technique | Stack moderne, code propre, tests |
| **Directeurs techniques gros comptes** | Confiance sur les compétences | Architecture enterprise-ready |
| **Équipes commerciales CGI** | Avoir un asset démo | Application fonctionnelle à montrer |
| **Communauté Data** | Ressource open-source | Projet réutilisable et documenté |

### 1.3 Proposition de Valeur

**Pour les utilisateurs finaux :**
> "Explorez les prix de l'immobilier en France sur une carte interactive avec des filtres fins (commune, type de bien, période, surface)."

**Pour le portfolio professionnel :**
> "Démonstration end-to-end d'une plateforme data moderne : de l'ingestion à la visualisation, avec les standards des grands comptes (Airflow, Snowflake, dbt, Azure)."

---

## 2. Périmètre Fonctionnel

### 2.1 Fonctionnalités MVP (Phase 1)

| ID | Fonctionnalité | Priorité | Statut |
|----|----------------|----------|--------|
| F01 | Carte interactive des prix par commune | MUST | À faire |
| F02 | Filtres : type de bien (appartement/maison) | MUST | À faire |
| F03 | Filtres : période (année, trimestre) | MUST | À faire |
| F04 | Filtres : fourchette de prix | SHOULD | À faire |
| F05 | Statistiques par zone (prix médian, nb transactions) | MUST | À faire |
| F06 | Export des données filtrées (CSV) | COULD | À faire |

### 2.2 Fonctionnalités Avancées (Phase 2)

| ID | Fonctionnalité | Priorité |
|----|----------------|----------|
| F07 | Évolution temporelle des prix (graphiques) | SHOULD |
| F08 | Comparateur de communes | SHOULD |
| F09 | Prix au m² par quartier (si données suffisantes) | COULD |
| F10 | Heatmap de densité des transactions | COULD |
| F11 | Prédiction de prix (ML - optionnel) | WONT (V1) |

### 2.3 Données Sources

| Source | Description | Fréquence MAJ | Volume |
|--------|-------------|---------------|--------|
| **DVF** | Demandes de Valeurs Foncières - Transactions immobilières | Semestrielle (avril/octobre) | ~15M lignes (5 ans) |
| **BAN** | Base Adresse Nationale - Géocodage | Mensuelle | ~26M adresses |

---

## 3. Architecture Technique

### 3.1 Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ORCHESTRATION (Airflow)                           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │ DVF Ingest  │───▶│ BAN Ingest  │───▶│ dbt Transform│───▶│ Data Quality│  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SNOWFLAKE                                       │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                      │
│  │   BRONZE    │───▶│   SILVER    │───▶│    GOLD     │                      │
│  │ (Raw Data)  │    │ (Cleaned)   │    │(Star Schema)│                      │
│  └─────────────┘    └─────────────┘    └─────────────┘                      │
│                                               │                              │
└───────────────────────────────────────────────┼──────────────────────────────┘
                                                │
                                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      AZURE CONTAINER APPS                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         STREAMLIT APP                                │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │    │
│  │  │  Carte   │  │ Filtres  │  │  Stats   │  │ Tendances│            │    │
│  │  │Interactive│  │  Panel   │  │  Panel   │  │  Charts  │            │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘            │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Stack Technique

| Couche | Technologie | Version | Justification |
|--------|-------------|---------|---------------|
| **Ingestion** | Python | 3.11+ | Standard, librairies riches |
| **Orchestration** | Apache Airflow | 2.8+ | Standard gros comptes |
| **Stockage** | Snowflake | Latest | Leader cloud DWH |
| **Transformation** | dbt-core | 1.7+ | Standard moderne |
| **Visualisation** | Streamlit | 1.30+ | Prototypage rapide |
| **Cartographie** | Folium / PyDeck | Latest | Intégration Streamlit |
| **Hébergement** | Azure Container Apps | - | Enterprise-ready |
| **CI/CD** | GitHub Actions | - | Intégration native |
| **IaC** | Terraform | 1.6+ | Standard gros comptes |
| **Conteneurisation** | Docker | 24+ | Standard |

### 3.3 Organisation Repositories

#### Monorepo Principal : `dvf-analytics`

```
dvf-analytics/
│
├── README.md                       # Landing page projet
├── CONTRIBUTING.md                 # Guide contribution
├── LICENSE                         # MIT
│
├── docs/                           # Documentation générée
│   ├── index.md
│   ├── product-brief.md           # CE DOCUMENT
│   ├── architecture.md
│   ├── data-model.md
│   └── deployment.md
│
├── ingestion/                      # Pipeline Python
│   ├── src/
│   │   ├── __init__.py
│   │   ├── config.py              # Configuration (env vars)
│   │   ├── dvf_loader.py          # Extraction DVF data.gouv.fr
│   │   ├── ban_loader.py          # Extraction BAN
│   │   ├── snowflake_client.py    # Client Snowflake
│   │   └── utils/
│   │       ├── __init__.py
│   │       ├── logging.py
│   │       └── validators.py
│   ├── tests/
│   │   ├── __init__.py
│   │   ├── test_dvf_loader.py
│   │   ├── test_ban_loader.py
│   │   └── test_snowflake_client.py
│   ├── requirements.txt
│   └── pyproject.toml
│
├── airflow/                        # Orchestration
│   ├── dags/
│   │   ├── __init__.py
│   │   ├── dvf_pipeline_dag.py    # DAG principal
│   │   ├── ban_ingestion_dag.py   # DAG BAN
│   │   └── dbt_transform_dag.py   # DAG dbt
│   ├── plugins/                   # Custom operators si besoin
│   ├── config/
│   │   └── airflow.cfg
│   ├── docker-compose.airflow.yml # Dev local
│   └── README.md
│
├── dbt_dvf/                        # ✅ EXISTANT - Transformations
│   ├── models/
│   │   ├── silver/
│   │   └── gold/
│   ├── macros/
│   ├── tests/
│   ├── dbt_project.yml
│   └── profiles.yml.example
│
├── streamlit/                      # Application Frontend
│   ├── app.py                     # Entry point
│   ├── pages/
│   │   ├── 01_🗺️_Carte_Prix.py
│   │   ├── 02_📈_Tendances.py
│   │   └── 03_🔍_Comparateur.py
│   ├── components/
│   │   ├── __init__.py
│   │   ├── filters.py             # Composants filtres
│   │   ├── map_view.py            # Composant carte
│   │   └── stats_panel.py         # Composant statistiques
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── snowflake_connector.py
│   │   └── cache.py
│   ├── tests/
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .streamlit/
│       └── config.toml
│
├── docker/                         # Conteneurisation
│   ├── docker-compose.yml         # Dev local complet
│   ├── docker-compose.test.yml    # Tests CI
│   └── Dockerfile.ingestion
│
├── .github/
│   └── workflows/
│       ├── ci.yml                 # Tests + Lint
│       ├── cd-staging.yml         # Deploy staging
│       └── cd-prod.yml            # Deploy production
│
├── .env.example                    # Template variables
├── .gitignore
├── .pre-commit-config.yaml         # Hooks qualité
└── Makefile                        # Commandes dev
```

#### Repo Séparé : `dvf-infrastructure`

```
dvf-infrastructure/
│
├── README.md
│
├── terraform/
│   ├── modules/
│   │   ├── snowflake/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── databases.tf
│   │   │
│   │   ├── azure-container-apps/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   └── azure-managed-airflow/  # Optionnel
│   │       ├── main.tf
│   │       └── variables.tf
│   │
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.tf
│   │   │   ├── terraform.tfvars
│   │   │   └── backend.tf
│   │   │
│   │   └── prod/
│   │       ├── main.tf
│   │       ├── terraform.tfvars
│   │       └── backend.tf
│   │
│   └── shared/
│       └── providers.tf
│
├── scripts/
│   ├── init-snowflake.sql         # Setup initial Snowflake
│   └── destroy-all.sh             # Cleanup
│
└── .github/
    └── workflows/
        ├── terraform-plan.yml
        └── terraform-apply.yml
```

---

## 4. Modèle de Données

### 4.1 Architecture Medallion

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     BRONZE      │     │     SILVER      │     │      GOLD       │
│   (Raw Data)    │────▶│   (Cleaned)     │────▶│  (Star Schema)  │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ DVF_RAW_VARCHAR │     │ dvf_silver      │     │ fact_mutation   │
│ BAN_ADRESSES    │     │ ban_addresses   │     │ dim_address     │
│                 │     │ ban_addresses_  │     │ dim_address_    │
│                 │     │   normalized    │     │   enriched      │
│                 │     │                 │     │ dim_commune     │
│                 │     │                 │     │ dim_parcelle    │
│                 │     │                 │     │ dim_type_local  │
│                 │     │                 │     │ dim_code_postal │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### 4.2 Star Schema (Couche Gold)

```
                              ┌─────────────────────┐
                              │   dim_type_local    │
                              ├─────────────────────┤
                              │ TYPE_LOCAL_ID (PK)  │
                              │ TYPE_LOCAL          │
                              │ SOURCE_SYSTEM       │
                              └──────────┬──────────┘
                                         │
┌─────────────────────┐                  │                  ┌─────────────────────┐
│   dim_commune       │                  │                  │   dim_parcelle      │
├─────────────────────┤                  │                  ├─────────────────────┤
│ COMMUNE_ID (PK)     │                  │                  │ PARCELLE_ID (PK)    │
│ COMMUNE             │                  │                  │ PREFIXE_DE_SECTION  │
│ CODE_DEPARTEMENT    │                  │                  │ SECTION             │
└──────────┬──────────┘                  │                  │ NO_PLAN             │
           │                             │                  │ NO_VOLUME           │
           │         ┌───────────────────┼───────────────┐  │ IS_PARTIAL          │
           │         │                   │               │  └──────────┬──────────┘
           │         │    ┌──────────────┴────────────┐  │             │
           │         │    │       fact_mutation       │  │             │
           │         │    ├───────────────────────────┤  │             │
           └─────────┼───▶│ ADDRESS_ID (FK)           │◀─┼─────────────┘
                     │    │ COMMUNE_ID (FK)           │  │
                     │    │ PARCELLE_ID (FK)          │  │
                     │    │ TYPE_LOCAL_ID (FK)        │  │
                     │    │ CODE_POSTAL_ID (FK)       │  │
                     │    │ BAN_ID                    │  │
                     │    │ CODE_INSEE                │  │
                     │    │ LONGITUDE                 │  │
                     │    │ LATITUDE                  │  │
                     │    │ GEOCODING_MATCH_LEVEL     │  │
                     │    │ GEOCODING_MATCH_SCORE     │  │
                     │    │ ADDRESS_MATCH_STRATEGY    │  │
                     │    │ DATE_MUTATION             │  │
                     │    │ NATURE_MUTATION           │  │
                     │    │ VALEUR_FONCIERE          │◀─┼─ Mesures
                     │    │ SURFACE_REELLE_BATI      │  │
                     │    │ NOMBRE_PIECES_PRINCIPALES│  │
                     │    │ SURFACE_TERRAIN          │  │
                     │    └───────────────────────────┘  │
                     │                   │               │
┌────────────────────┴───┐               │    ┌──────────┴──────────┐
│ dim_address_enriched   │               │    │   dim_code_postal   │
├────────────────────────┤               │    ├─────────────────────┤
│ ADDRESS_ID (PK)        │◀──────────────┘    │ CODE_POSTAL_ID (PK) │
│ BAN_ID                 │                    │ CODE_POSTAL         │
│ NO_VOIE                │                    │ COMMUNE             │
│ TYPE_DE_VOIE           │                    │ CODE_DEPARTEMENT    │
│ VOIE                   │                    └─────────────────────┘
│ CODE_POSTAL            │
│ COMMUNE                │
│ CODE_DEPARTEMENT       │
│ ADDRESS_FULL           │
│ CODE_INSEE             │
│ LONGITUDE              │
│ LATITUDE               │
│ X_LAMBERT93            │
│ Y_LAMBERT93            │
│ MATCH_LEVEL            │
│ MATCH_SCORE            │
└────────────────────────┘
```

### 4.3 Métriques Clés Disponibles

| Métrique | Calcul | Usage |
|----------|--------|-------|
| **Prix médian** | `MEDIAN(VALEUR_FONCIERE)` | Indicateur marché |
| **Prix au m²** | `VALEUR_FONCIERE / SURFACE_REELLE_BATI` | Comparaison |
| **Nb transactions** | `COUNT(*)` | Volume marché |
| **Volume total** | `SUM(VALEUR_FONCIERE)` | Taille marché |
| **Surface moyenne** | `AVG(SURFACE_REELLE_BATI)` | Caractérisation |

---

## 5. Roadmap d'Implémentation

### Phase 1 : Fondations (Actuel → +2 semaines)

| Tâche | Statut | Priorité |
|-------|--------|----------|
| Structure monorepo | À faire | P0 |
| Pipeline ingestion DVF (Python) | À faire | P0 |
| Pipeline ingestion BAN (Python) | À faire | P0 |
| Tests unitaires ingestion | À faire | P0 |
| DAGs Airflow (local) | À faire | P0 |
| CI/CD GitHub Actions (tests) | À faire | P1 |

### Phase 2 : Application Streamlit (+2 → +4 semaines)

| Tâche | Statut | Priorité |
|-------|--------|----------|
| Structure app Streamlit | À faire | P0 |
| Page carte interactive | À faire | P0 |
| Filtres (type, période, prix) | À faire | P0 |
| Panel statistiques | À faire | P1 |
| Dockerfile Streamlit | À faire | P0 |
| Tests composants | À faire | P1 |

### Phase 3 : Déploiement (+4 → +6 semaines)

| Tâche | Statut | Priorité |
|-------|--------|----------|
| Terraform Azure Container Apps | À faire | P0 |
| Terraform Snowflake | À faire | P1 |
| CD GitHub Actions (deploy) | À faire | P0 |
| Documentation déploiement | À faire | P1 |
| README principal | À faire | P0 |

### Phase 4 : Polish (+6 → +8 semaines)

| Tâche | Statut | Priorité |
|-------|--------|----------|
| Page tendances temporelles | À faire | P2 |
| Page comparateur communes | À faire | P2 |
| Optimisation performances | À faire | P1 |
| Documentation complète | À faire | P1 |
| Video démo (optionnel) | À faire | P3 |

---

## 6. Critères de Succès

### 6.1 Techniques

| Critère | Cible | Mesure |
|---------|-------|--------|
| **Couverture tests** | > 80% | pytest-cov |
| **Temps chargement carte** | < 3s | Mesure Streamlit |
| **Qualité code** | A | SonarQube / CodeClimate |
| **Disponibilité** | 99% | Azure monitoring |
| **Documentation** | Complète | Revue manuelle |

### 6.2 Portfolio

| Critère | Cible |
|---------|-------|
| **GitHub stars** | > 50 |
| **Temps compréhension recruteur** | < 5 min (README clair) |
| **Démo fonctionnelle** | App accessible publiquement |
| **Reproductibilité** | Clone → Run en < 15 min |

---

## 7. Risques et Mitigations

| Risque | Impact | Probabilité | Mitigation |
|--------|--------|-------------|------------|
| Coût Snowflake trop élevé | Haut | Moyen | Utiliser tier gratuit, optimiser requêtes |
| Complexité Airflow | Moyen | Moyen | Commencer simple, 3 DAGs max |
| Performance carte avec millions de points | Haut | Haut | Agrégation côté Snowflake, clustering |
| Temps de développement | Moyen | Moyen | MVP first, itérer |

---

## 8. Annexes

### 8.1 Liens Utiles

- [Données DVF - data.gouv.fr](https://www.data.gouv.fr/fr/datasets/demandes-de-valeurs-foncieres/)
- [Base Adresse Nationale](https://adresse.data.gouv.fr/)
- [Documentation Snowflake](https://docs.snowflake.com/)
- [Documentation dbt](https://docs.getdbt.com/)
- [Documentation Streamlit](https://docs.streamlit.io/)
- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/)

### 8.2 Glossaire

| Terme | Définition |
|-------|------------|
| **DVF** | Demandes de Valeurs Foncières - données publiques des transactions immobilières |
| **BAN** | Base Adresse Nationale - référentiel des adresses françaises |
| **Medallion Architecture** | Pattern Bronze → Silver → Gold pour data lakes |
| **Star Schema** | Modèle dimensionnel avec table de faits centrale et dimensions |
| **DAG** | Directed Acyclic Graph - workflow Airflow |

---

*Document généré le 2026-01-20 | Version 1.0*
