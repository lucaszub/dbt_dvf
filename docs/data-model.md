# DVF Analytics - Modèle de Données

> **Documentation complète du Star Schema et des transformations dbt**

---

## 1. Vue d'Ensemble

### 1.1 Architecture Medallion

Le projet implémente une architecture **Medallion** (Bronze → Silver → Gold) :

| Couche | Description | Matérialisation | Base de données |
|--------|-------------|-----------------|-----------------|
| **Bronze** | Données brutes, non typées | TABLE (externe) | VALFONC_RAW |
| **Silver** | Données nettoyées, typées | VIEW | VALFONC_ANALYTICS_DBT |
| **Gold** | Modèle dimensionnel (Star Schema) | TABLE | VALFONC_ANALYTICS_DBT |

### 1.2 Sources de Données

| Source | Description | Volume | Fréquence MAJ |
|--------|-------------|--------|---------------|
| **DVF** | Demandes de Valeurs Foncières | ~15M lignes (5 ans) | Semestrielle |
| **BAN** | Base Adresse Nationale | ~26M adresses | Mensuelle |

---

## 2. Couche Bronze (Raw)

### 2.1 DVF_RAW_VARCHAR

Table source des transactions immobilières, toutes colonnes en VARCHAR.

```sql
-- Database: VALFONC_RAW
-- Schema: BRONZE

CREATE TABLE DVF_RAW_VARCHAR (
    DATE_MUTATION VARCHAR,
    NATURE_MUTATION VARCHAR,
    VALEUR_FONCIERE VARCHAR,
    NO_VOIE VARCHAR,
    BTQ VARCHAR,
    TYPE_DE_VOIE VARCHAR,
    CODE_VOIE VARCHAR,
    CODE_POSTAL VARCHAR,
    COMMUNE VARCHAR,
    VOIE VARCHAR,
    CODE_DEPARTEMENT VARCHAR,
    PREFIXE_DE_SECTION VARCHAR,
    SECTION VARCHAR,
    NO_PLAN VARCHAR,
    NO_VOLUME VARCHAR,
    TYPE_LOCAL VARCHAR,
    SURFACE_REELLE_BATI VARCHAR,
    NOMBRE_PIECES_PRINCIPALES VARCHAR,
    NATURE_CULTURE VARCHAR,
    SURFACE_TERRAIN VARCHAR
);
```

### 2.2 BAN_ADRESSES

Table source des adresses françaises avec géolocalisation.

```sql
-- Database: VALFONC_RAW
-- Schema: BRONZE

CREATE TABLE BAN_ADRESSES (
    "id" VARCHAR,
    "id_fantoir" VARCHAR,
    "numero" VARCHAR,
    "rep" VARCHAR,
    "nom_voie" VARCHAR,
    "code_postal" VARCHAR,
    "code_insee" VARCHAR,
    "nom_commune" VARCHAR,
    "code_insee_ancienne_commune" VARCHAR,
    "nom_ancienne_commune" VARCHAR,
    "x" VARCHAR,                    -- Lambert 93
    "y" VARCHAR,                    -- Lambert 93
    "lon" VARCHAR,                  -- WGS84
    "lat" VARCHAR,                  -- WGS84
    "type_position" VARCHAR,
    "alias" VARCHAR,
    "nom_ld" VARCHAR,
    "libelle_acheminement" VARCHAR,
    "nom_afnor" VARCHAR,
    "source_position" VARCHAR,
    "source_nom_voie" VARCHAR,
    "certification_commune" VARCHAR,
    "cad_parcelles" VARCHAR,
    "departement" VARCHAR
);
```

---

## 3. Couche Silver (Cleaned)

### 3.1 dvf_silver

Données DVF nettoyées et typées, filtrées sur les ventes > 20 000€.

**Transformations appliquées :**
- Conversion DATE_MUTATION : VARCHAR → DATE
- Conversion VALEUR_FONCIERE : VARCHAR (format français) → NUMBER
- Conversion surfaces : VARCHAR → NUMBER
- Filtrage : NATURE_MUTATION = 'Vente' AND VALEUR_FONCIERE > 20000

```sql
-- Colonnes principales
SELECT
    TO_DATE(DATE_MUTATION, 'DD/MM/YYYY') AS DATE_MUTATION,
    NATURE_MUTATION,
    TO_NUMBER(REPLACE(VALEUR_FONCIERE, ',', '.')) AS VALEUR_FONCIERE,
    NO_VOIE,
    TYPE_DE_VOIE,
    CODE_POSTAL,
    COMMUNE,
    VOIE,
    CODE_DEPARTEMENT,
    PREFIXE_DE_SECTION,
    SECTION,
    NO_PLAN,
    NO_VOLUME,
    TYPE_LOCAL,
    TO_NUMBER(REPLACE(SURFACE_REELLE_BATI, ',', '.')) AS SURFACE_REELLE_BATI,
    NOMBRE_PIECES_PRINCIPALES,
    TO_NUMBER(REPLACE(SURFACE_TERRAIN, ',', '.')) AS SURFACE_TERRAIN
FROM VALFONC_RAW.BRONZE.DVF_RAW_VARCHAR
WHERE VALEUR_FONCIERE IS NOT NULL
  AND NATURE_MUTATION = 'Vente'
  AND TO_NUMBER(REPLACE(VALEUR_FONCIERE, ',', '.')) > 20000
```

### 3.2 ban_addresses

Données BAN nettoyées avec normalisation des chaînes.

**Transformations appliquées :**
- UPPER + TRIM sur toutes les colonnes texte
- REGEXP_REPLACE pour écraser les espaces multiples
- Conversion coordonnées : VARCHAR → NUMBER (TRY_TO_NUMBER)
- Filtrage : id, code_postal, code_insee NOT NULL

### 3.3 ban_addresses_normalized

Vue préparée pour le matching multi-niveaux avec DVF.

**Colonnes de matching générées :**

| Colonne | Description | Exemple |
|---------|-------------|---------|
| MATCH_KEY_EXACT | numéro\|répétition\|voie\|CP\|commune | `12\|BIS\|RUE VICTOR HUGO\|75001\|PARIS` |
| MATCH_KEY_SANS_TYPE | numéro\|voie sans type\|CP\|commune | `12\|VICTOR HUGO\|75001\|PARIS` |
| MATCH_KEY_VOIE | voie\|CP\|commune | `RUE VICTOR HUGO\|75001\|PARIS` |
| MATCH_KEY_CODE_POSTAL | CP\|commune | `75001\|PARIS` |
| MATCH_KEY_COMMUNE | code INSEE | `75101` |

**Scores de qualité :**
- PRECISION_SCORE : basé sur TYPE_POSITION (HOUSENUMBER=100, STREET=60, etc.)
- CERTIFICATION_SCORE : +10 si certifié par commune
- QUALITY_SCORE : PRECISION + CERTIFICATION

---

## 4. Couche Gold (Star Schema)

### 4.1 Diagramme Entité-Relation

```
                              ┌─────────────────────┐
                              │   dim_type_local    │
                              ├─────────────────────┤
                              │ TYPE_LOCAL_ID (PK)  │
                              │ TYPE_LOCAL          │
                              │ SOURCE_SYSTEM       │
                              │ CREATED_AT          │
                              └──────────┬──────────┘
                                         │
                                         │ 1:N
                                         │
┌─────────────────────┐                  │                  ┌─────────────────────┐
│   dim_commune       │                  │                  │   dim_parcelle      │
├─────────────────────┤                  │                  ├─────────────────────┤
│ COMMUNE_ID (PK)     │                  │                  │ PARCELLE_ID (PK)    │
│ COMMUNE             │                  │                  │ PREFIXE_DE_SECTION  │
│ CODE_DEPARTEMENT    │                  │                  │ SECTION             │
│ CREATED_AT          │                  │                  │ NO_PLAN             │
└──────────┬──────────┘                  │                  │ NO_VOLUME           │
           │                             │                  │ IS_PARTIAL          │
           │ 1:N                         │                  │ CREATED_AT          │
           │                             │                  └──────────┬──────────┘
           │         ┌───────────────────┼───────────────────┐         │
           │         │                   │                   │         │ 1:N
           │         │    ┌──────────────┴────────────┐      │         │
           │         │    │                           │      │         │
           └─────────┼───▶│      fact_mutation        │◀─────┼─────────┘
                     │    │          (FACT)           │      │
                     │    │                           │      │
                     │    │ ─────────────────────────  │      │
                     │    │ ADDRESS_ID (FK)           │      │
                     │    │ COMMUNE_ID (FK)           │      │
                     │    │ PARCELLE_ID (FK)          │      │
                     │    │ TYPE_LOCAL_ID (FK)        │      │
                     │    │ CODE_POSTAL_ID (FK)       │      │
                     │    │ ─────────────────────────  │      │
                     │    │ BAN_ID                    │      │
                     │    │ CODE_INSEE                │      │
                     │    │ LONGITUDE                 │      │
                     │    │ LATITUDE                  │      │
                     │    │ GEOCODING_MATCH_LEVEL     │      │
                     │    │ GEOCODING_MATCH_SCORE     │      │
                     │    │ ADDRESS_MATCH_STRATEGY    │      │
                     │    │ ─────────────────────────  │      │
                     │    │ DATE_MUTATION             │      │
                     │    │ NATURE_MUTATION           │      │
                     │    │ ─────────────────────────  │      │
                     │    │ VALEUR_FONCIERE ◀── Mesure│      │
                     │    │ SURFACE_REELLE_BATI       │      │
                     │    │ NOMBRE_PIECES_PRINCIPALES │      │
                     │    │ SURFACE_TERRAIN           │      │
                     │    │ ─────────────────────────  │      │
                     │    │ CREATED_AT                │      │
                     │    └───────────────────────────┘      │
                     │                   ▲                   │
                     │                   │                   │
                     │                   │ 1:N               │
┌────────────────────┴───┐               │        ┌─────────┴───────────┐
│ dim_address_enriched   │───────────────┘        │   dim_code_postal   │
├────────────────────────┤                        ├─────────────────────┤
│ ADDRESS_ID (PK)        │                        │ CODE_POSTAL_ID (PK) │
│ BAN_ID                 │                        │ CODE_POSTAL         │
│ NO_VOIE                │                        │ COMMUNE             │
│ TYPE_DE_VOIE           │                        │ CODE_DEPARTEMENT    │
│ VOIE                   │                        │ VOIE                │
│ CODE_POSTAL            │                        │ CREATED_AT          │
│ COMMUNE                │                        └─────────────────────┘
│ CODE_DEPARTEMENT       │
│ ADDRESS_FULL           │
│ CODE_INSEE             │
│ ID_FANTOIR             │
│ LONGITUDE              │
│ LATITUDE               │
│ X_LAMBERT93            │
│ Y_LAMBERT93            │
│ MATCH_LEVEL            │
│ MATCH_SCORE            │
│ TYPE_POSITION          │
│ SOURCE_POSITION        │
│ BAN_QUALITY_SCORE      │
│ PARCELLES_CADASTRALES  │
│ LIBELLE_ACHEMINEMENT   │
│ NOM_AFNOR              │
│ CREATED_AT             │
│ UPDATED_AT             │
└────────────────────────┘
```

---

## 5. Tables de Dimensions

### 5.1 dim_address_enriched

**Description :** Dimension principale des adresses avec enrichissement géographique BAN.

**Grain :** Une ligne par adresse unique (6 composants DVF).

**Clé primaire :** `ADDRESS_ID` (HASH des 6 composants normalisés)

| Colonne | Type | Description |
|---------|------|-------------|
| ADDRESS_ID | VARCHAR(16) | PK - Hash hexadécimal |
| BAN_ID | VARCHAR | ID BAN (si match) |
| NO_VOIE | VARCHAR | Numéro de voie normalisé |
| TYPE_DE_VOIE | VARCHAR | Type (RUE, AVENUE, etc.) |
| VOIE | VARCHAR | Nom de voie |
| CODE_POSTAL | VARCHAR | Code postal |
| COMMUNE | VARCHAR | Nom commune |
| CODE_DEPARTEMENT | VARCHAR | Code département |
| ADDRESS_FULL | VARCHAR | Adresse formatée complète |
| CODE_INSEE | VARCHAR | Code INSEE commune |
| LONGITUDE | FLOAT | Longitude WGS84 |
| LATITUDE | FLOAT | Latitude WGS84 |
| X_LAMBERT93 | FLOAT | Coordonnée X Lambert 93 |
| Y_LAMBERT93 | FLOAT | Coordonnée Y Lambert 93 |
| MATCH_LEVEL | VARCHAR | Niveau de matching (EXACT, SANS_TYPE, etc.) |
| MATCH_SCORE | INT | Score 0-100 |

**Stratégie de matching multi-niveaux :**

| Niveau | Critères | Score | Précision GPS |
|--------|----------|-------|---------------|
| EXACT | Numéro + voie complète + CP + commune | 100 | < 10m |
| SANS_TYPE | Numéro + voie sans type + CP + commune | 90 | ~10-20m |
| VOIE_SEULE | Voie + CP + commune (centroïde rue) | 70 | ~50-200m |
| CODE_POSTAL | CP + commune (centroïde CP) | 50 | ~200-500m |
| COMMUNE | Code INSEE (centroïde commune) | 30 | > 500m |
| NO_MATCH | Aucun match | 0 | N/A |

### 5.2 dim_commune

**Description :** Référentiel des communes françaises.

**Grain :** Une ligne par couple (COMMUNE, CODE_DEPARTEMENT).

| Colonne | Type | Description |
|---------|------|-------------|
| COMMUNE_ID | NUMBER | PK - Hash(commune + dept) |
| COMMUNE | VARCHAR | Nom normalisé |
| CODE_DEPARTEMENT | VARCHAR | Code département |
| CREATED_AT | TIMESTAMP | Date création |

### 5.3 dim_parcelle

**Description :** Référentiel cadastral des parcelles.

**Grain :** Une ligne par parcelle unique.

| Colonne | Type | Description |
|---------|------|-------------|
| PARCELLE_ID | NUMBER | PK - Hash des 4 composants |
| PREFIXE_DE_SECTION | VARCHAR | Préfixe section |
| SECTION | VARCHAR | Section cadastrale |
| NO_PLAN | VARCHAR | Numéro de plan |
| NO_VOLUME | VARCHAR | Numéro volume (copropriété) |
| IS_PARTIAL | INT | Flag qualité (0=complet, 1=incomplet) |
| CREATED_AT | TIMESTAMP | Date création |

### 5.4 dim_type_local

**Description :** Types de biens immobiliers.

**Grain :** Une ligne par type de local.

| Colonne | Type | Description |
|---------|------|-------------|
| TYPE_LOCAL_ID | NUMBER | PK - Hash(type_local) |
| TYPE_LOCAL | VARCHAR | Libellé (Maison, Appartement, etc.) |
| SOURCE_SYSTEM | VARCHAR | Source = 'DVF' |
| CREATED_AT | TIMESTAMP | Date création |

**Valeurs :**
- MAISON
- APPARTEMENT
- LOCAL INDUSTRIEL. COMMERCIAL. OU ASSIMILÉ
- DÉPENDANCE
- INCONNU (fallback)

### 5.5 dim_code_postal

**Description :** Référentiel des codes postaux.

**Grain :** Une ligne par couple (CODE_POSTAL, CODE_DEPARTEMENT).

| Colonne | Type | Description |
|---------|------|-------------|
| CODE_POSTAL_ID | VARCHAR(16) | PK - Hash hexadécimal |
| CODE_POSTAL | VARCHAR | Code postal |
| COMMUNE | VARCHAR | Commune principale |
| CODE_DEPARTEMENT | VARCHAR | Code département |
| VOIE | VARCHAR | Voie représentative |
| CREATED_AT | TIMESTAMP | Date création |

---

## 6. Table de Faits

### 6.1 fact_mutation

**Description :** Table centrale des transactions immobilières.

**Grain :** Une ligne par transaction (mutation).

**Clés étrangères :**

| FK | Dimension | Jointure |
|----|-----------|----------|
| ADDRESS_ID | dim_address_enriched | 6 champs normalisés |
| COMMUNE_ID | dim_commune | COMMUNE + CODE_DEPARTEMENT |
| PARCELLE_ID | dim_parcelle | 4 composants cadastraux |
| TYPE_LOCAL_ID | dim_type_local | TYPE_LOCAL |
| CODE_POSTAL_ID | dim_code_postal | CODE_POSTAL + CODE_DEPARTEMENT |

**Colonnes :**

| Colonne | Type | Catégorie | Description |
|---------|------|-----------|-------------|
| ADDRESS_ID | VARCHAR(16) | FK | Lien adresse enrichie |
| COMMUNE_ID | NUMBER | FK | Lien commune |
| PARCELLE_ID | NUMBER | FK | Lien parcelle |
| TYPE_LOCAL_ID | NUMBER | FK | Lien type de bien |
| CODE_POSTAL_ID | VARCHAR(16) | FK | Lien code postal |
| BAN_ID | VARCHAR | Enrichissement | ID BAN |
| CODE_INSEE | VARCHAR | Enrichissement | Code INSEE |
| LONGITUDE | FLOAT | Enrichissement | Coordonnée GPS |
| LATITUDE | FLOAT | Enrichissement | Coordonnée GPS |
| GEOCODING_MATCH_LEVEL | VARCHAR | Qualité | Niveau matching |
| GEOCODING_MATCH_SCORE | INT | Qualité | Score 0-100 |
| ADDRESS_MATCH_STRATEGY | VARCHAR | Qualité | MATCH_ADDRESS / FALLBACK_COMMUNE / NO_MATCH |
| DATE_MUTATION | DATE | Attribut | Date transaction |
| NATURE_MUTATION | VARCHAR | Attribut | = 'Vente' |
| VALEUR_FONCIERE | NUMBER | **Mesure** | Prix en euros |
| SURFACE_REELLE_BATI | NUMBER | **Mesure** | Surface habitable m² |
| NOMBRE_PIECES_PRINCIPALES | INT | **Mesure** | Nombre de pièces |
| SURFACE_TERRAIN | NUMBER | **Mesure** | Surface terrain m² |
| CREATED_AT | TIMESTAMP | Technique | Date chargement |

---

## 7. Requêtes Analytiques Exemples

### 7.1 Prix médian par commune

```sql
SELECT
    c.COMMUNE,
    c.CODE_DEPARTEMENT,
    MEDIAN(f.VALEUR_FONCIERE) AS prix_median,
    COUNT(*) AS nb_transactions
FROM GOLD.fact_mutation f
JOIN GOLD.dim_commune c ON f.COMMUNE_ID = c.COMMUNE_ID
WHERE YEAR(f.DATE_MUTATION) = 2024
GROUP BY c.COMMUNE, c.CODE_DEPARTEMENT
ORDER BY prix_median DESC
LIMIT 20;
```

### 7.2 Prix au m² par type de bien

```sql
SELECT
    t.TYPE_LOCAL,
    AVG(f.VALEUR_FONCIERE / NULLIF(f.SURFACE_REELLE_BATI, 0)) AS prix_m2_moyen,
    COUNT(*) AS nb_transactions
FROM GOLD.fact_mutation f
JOIN GOLD.dim_type_local t ON f.TYPE_LOCAL_ID = t.TYPE_LOCAL_ID
WHERE f.SURFACE_REELLE_BATI > 0
  AND f.VALEUR_FONCIERE > 0
GROUP BY t.TYPE_LOCAL
ORDER BY prix_m2_moyen DESC;
```

### 7.3 Évolution mensuelle

```sql
SELECT
    DATE_TRUNC('MONTH', f.DATE_MUTATION) AS mois,
    COUNT(*) AS nb_transactions,
    MEDIAN(f.VALEUR_FONCIERE) AS prix_median,
    SUM(f.VALEUR_FONCIERE) AS volume_total
FROM GOLD.fact_mutation f
WHERE f.DATE_MUTATION >= DATEADD(YEAR, -2, CURRENT_DATE())
GROUP BY mois
ORDER BY mois;
```

### 7.4 Transactions avec géolocalisation précise

```sql
SELECT
    a.ADDRESS_FULL,
    a.LONGITUDE,
    a.LATITUDE,
    f.VALEUR_FONCIERE,
    f.SURFACE_REELLE_BATI,
    t.TYPE_LOCAL
FROM GOLD.fact_mutation f
JOIN GOLD.dim_address_enriched a ON f.ADDRESS_ID = a.ADDRESS_ID
JOIN GOLD.dim_type_local t ON f.TYPE_LOCAL_ID = t.TYPE_LOCAL_ID
WHERE f.GEOCODING_MATCH_LEVEL IN ('EXACT', 'SANS_TYPE')
  AND f.DATE_MUTATION >= '2024-01-01'
  AND t.TYPE_LOCAL = 'APPARTEMENT'
ORDER BY f.VALEUR_FONCIERE DESC
LIMIT 100;
```

### 7.5 Qualité du géocodage

```sql
SELECT
    GEOCODING_MATCH_LEVEL,
    COUNT(*) AS nb_transactions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pourcentage
FROM GOLD.fact_mutation
GROUP BY GEOCODING_MATCH_LEVEL
ORDER BY
    CASE GEOCODING_MATCH_LEVEL
        WHEN 'EXACT' THEN 1
        WHEN 'SANS_TYPE' THEN 2
        WHEN 'VOIE_SEULE' THEN 3
        WHEN 'CODE_POSTAL' THEN 4
        WHEN 'COMMUNE' THEN 5
        WHEN 'NO_MATCH' THEN 6
    END;
```

---

## 8. Tests de Qualité (dbt)

### 8.1 Tests Génériques

```yaml
# schema.yml
models:
  - name: fact_mutation
    columns:
      - name: ADDRESS_ID
        tests:
          - not_null
          - relationships:
              to: ref('dim_address_enriched')
              field: ADDRESS_ID

      - name: DATE_MUTATION
        tests:
          - not_null

      - name: ADDRESS_MATCH_STRATEGY
        tests:
          - not_null
          - accepted_values:
              values: ['MATCH_ADDRESS', 'FALLBACK_COMMUNE', 'NO_MATCH']

      - name: NATURE_MUTATION
        tests:
          - accepted_values:
              values: ['Vente']
```

### 8.2 Tests Custom

```sql
-- tests/assert_valeur_fonciere_positive.sql
SELECT *
FROM {{ ref('fact_mutation') }}
WHERE VALEUR_FONCIERE <= 0
```

```sql
-- tests/assert_coordinates_in_france.sql
SELECT *
FROM {{ ref('dim_address_enriched') }}
WHERE LATITUDE IS NOT NULL
  AND (LATITUDE < 41.0 OR LATITUDE > 51.5
       OR LONGITUDE < -5.5 OR LONGITUDE > 10.0)
```

---

## 9. Lineage dbt

```
┌─────────────────┐
│ source.bronze.  │
│ DVF_RAW_VARCHAR │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌─────────────────┐
│   dvf_silver    │      │   ban_addresses │◀── source.bronze.BAN_ADRESSES
└────────┬────────┘      └────────┬────────┘
         │                        │
         │                        ▼
         │               ┌─────────────────────┐
         │               │ ban_addresses_      │
         │               │   normalized        │
         │               └────────┬────────────┘
         │                        │
         ├────────────────────────┤
         │                        │
         ▼                        ▼
┌─────────────────┐      ┌─────────────────────┐
│   dim_address   │      │ dim_address_enriched│
└────────┬────────┘      └────────┬────────────┘
         │                        │
         ▼                        │
┌─────────────────┐               │
│   dim_commune   │               │
└────────┬────────┘               │
         │                        │
         │     ┌──────────────────┘
         │     │
         ▼     ▼
┌─────────────────────────────────────────┐
│              fact_mutation               │
└─────────────────────────────────────────┘
         ▲     ▲     ▲
         │     │     │
┌────────┴─┐ ┌─┴────┐ ┌┴───────────────┐
│dim_type_ │ │dim_  │ │dim_code_postal │
│  local   │ │parce │ │                │
└──────────┘ │lle   │ └────────────────┘
             └──────┘
```

---

*Document généré le 2026-01-20 | Version 1.0*
