/*
  ============================================================================
  ANALYSE DE QUALITÉ - Matching Adresses DVF ↔ BAN
  ============================================================================

  Ce fichier d'analyse permet de monitorer la qualité du géocodage
  des adresses DVF avec la Base Adresse Nationale (BAN).

  Utilisation :
    dbt compile --select analysis:address_matching_quality
    Puis exécuter la requête générée dans Snowflake

  Métriques calculées :
    1. Distribution des niveaux de matching (EXACT, SANS_TYPE, etc.)
    2. Taux de couverture géographique (% avec coordonnées GPS)
    3. Distribution des scores de matching
    4. Analyse par département
*/

-- ============================================================================
-- 1. DISTRIBUTION DES NIVEAUX DE MATCHING
-- ============================================================================

WITH matching_distribution AS (
  SELECT
    MATCH_LEVEL,
    MATCH_SCORE,
    COUNT(*) AS nb_addresses,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_addresses,
    COUNT(CASE WHEN LONGITUDE IS NOT NULL THEN 1 END) AS nb_with_coords,
    ROUND(
      COUNT(CASE WHEN LONGITUDE IS NOT NULL THEN 1 END) * 100.0 / COUNT(*),
      2
    ) AS pct_with_coords
  FROM {{ ref('dim_address_enriched') }}
  GROUP BY MATCH_LEVEL, MATCH_SCORE
  ORDER BY MATCH_SCORE DESC
),

-- ============================================================================
-- 2. COUVERTURE GÉOGRAPHIQUE GLOBALE
-- ============================================================================

geographic_coverage AS (
  SELECT
    COUNT(*) AS total_addresses,
    COUNT(CASE WHEN LONGITUDE IS NOT NULL THEN 1 END) AS addresses_with_gps,
    ROUND(
      COUNT(CASE WHEN LONGITUDE IS NOT NULL THEN 1 END) * 100.0 / COUNT(*),
      2
    ) AS pct_geocoded,
    COUNT(CASE WHEN BAN_ID IS NOT NULL THEN 1 END) AS addresses_with_ban_id,
    ROUND(
      COUNT(CASE WHEN BAN_ID IS NOT NULL THEN 1 END) * 100.0 / COUNT(*),
      2
    ) AS pct_with_ban_id
  FROM {{ ref('dim_address_enriched') }}
),

-- ============================================================================
-- 3. ANALYSE PAR DÉPARTEMENT
-- ============================================================================

quality_by_department AS (
  SELECT
    CODE_DEPARTEMENT,
    COUNT(*) AS nb_addresses,
    COUNT(CASE WHEN MATCH_LEVEL = 'EXACT' THEN 1 END) AS nb_exact,
    COUNT(CASE WHEN MATCH_LEVEL = 'SANS_TYPE' THEN 1 END) AS nb_sans_type,
    COUNT(CASE WHEN MATCH_LEVEL = 'VOIE_SEULE' THEN 1 END) AS nb_voie_seule,
    COUNT(CASE WHEN MATCH_LEVEL = 'CODE_POSTAL' THEN 1 END) AS nb_code_postal,
    COUNT(CASE WHEN MATCH_LEVEL = 'COMMUNE' THEN 1 END) AS nb_commune,
    COUNT(CASE WHEN MATCH_LEVEL = 'NO_MATCH' THEN 1 END) AS nb_no_match,
    ROUND(
      COUNT(CASE WHEN LONGITUDE IS NOT NULL THEN 1 END) * 100.0 / COUNT(*),
      2
    ) AS pct_geocoded,
    ROUND(AVG(MATCH_SCORE), 2) AS avg_match_score
  FROM {{ ref('dim_address_enriched') }}
  WHERE CODE_DEPARTEMENT IS NOT NULL
  GROUP BY CODE_DEPARTEMENT
  ORDER BY CODE_DEPARTEMENT
),

-- ============================================================================
-- 4. TYPE DE POSITION BAN (précision du positionnement)
-- ============================================================================

position_type_distribution AS (
  SELECT
    COALESCE(TYPE_POSITION, 'NULL') AS TYPE_POSITION,
    COUNT(*) AS nb_addresses,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_addresses,
    CASE TYPE_POSITION
      WHEN 'HOUSENUMBER' THEN 'Numéro exact (précision < 10m)'
      WHEN 'INTERPOLATION' THEN 'Numéro interpolé (précision ~10-50m)'
      WHEN 'STREET' THEN 'Centroïde de rue (précision ~50-200m)'
      WHEN 'LOCALITY' THEN 'Lieu-dit (précision ~200-500m)'
      WHEN 'MUNICIPALITY' THEN 'Centroïde commune (précision > 500m)'
      ELSE 'Pas de coordonnées'
    END AS precision_description
  FROM {{ ref('dim_address_enriched') }}
  GROUP BY TYPE_POSITION
  ORDER BY COUNT(*) DESC
),

-- ============================================================================
-- 5. ÉCHANTILLON D'ADRESSES PAR NIVEAU DE MATCHING
-- ============================================================================

sample_by_match_level AS (
  SELECT
    MATCH_LEVEL,
    ADDRESS_FULL,
    CODE_POSTAL,
    COMMUNE,
    LONGITUDE,
    LATITUDE,
    BAN_ID,
    MATCH_SCORE
  FROM {{ ref('dim_address_enriched') }}
  QUALIFY ROW_NUMBER() OVER (PARTITION BY MATCH_LEVEL ORDER BY RANDOM()) <= 5
  ORDER BY MATCH_SCORE DESC, MATCH_LEVEL
),

-- ============================================================================
-- 6. TOP 10 COMMUNES AVEC LE MOINS BON MATCHING
-- ============================================================================

worst_matching_communes AS (
  SELECT
    COMMUNE,
    CODE_DEPARTEMENT,
    COUNT(*) AS nb_addresses,
    COUNT(CASE WHEN MATCH_LEVEL IN ('NO_MATCH', 'COMMUNE', 'CODE_POSTAL') THEN 1 END) AS nb_low_quality,
    ROUND(
      COUNT(CASE WHEN MATCH_LEVEL IN ('NO_MATCH', 'COMMUNE', 'CODE_POSTAL') THEN 1 END) * 100.0 / COUNT(*),
      2
    ) AS pct_low_quality,
    ROUND(AVG(MATCH_SCORE), 2) AS avg_match_score
  FROM {{ ref('dim_address_enriched') }}
  WHERE COMMUNE IS NOT NULL
  GROUP BY COMMUNE, CODE_DEPARTEMENT
  HAVING COUNT(*) >= 10  -- Au moins 10 adresses pour être significatif
  ORDER BY pct_low_quality DESC
  LIMIT 10
)

-- ============================================================================
-- RÉSULTATS - Sélectionnez la section qui vous intéresse
-- ============================================================================

-- Décommentez la section que vous voulez analyser :

-- Section 1 : Distribution des niveaux de matching
SELECT
  '=== DISTRIBUTION DES NIVEAUX DE MATCHING ===' AS section,
  NULL AS match_level,
  NULL AS match_score,
  NULL AS nb_addresses,
  NULL AS pct_addresses,
  NULL AS nb_with_coords,
  NULL AS pct_with_coords
UNION ALL
SELECT
  NULL,
  MATCH_LEVEL,
  MATCH_SCORE,
  nb_addresses,
  pct_addresses,
  nb_with_coords,
  pct_with_coords
FROM matching_distribution

UNION ALL

-- Section 2 : Couverture géographique globale
SELECT
  '=== COUVERTURE GÉOGRAPHIQUE GLOBALE ===' AS section,
  NULL, NULL, NULL, NULL, NULL, NULL
UNION ALL
SELECT
  'Total adresses',
  NULL,
  NULL,
  total_addresses,
  NULL,
  NULL,
  NULL
FROM geographic_coverage
UNION ALL
SELECT
  'Adresses géocodées',
  NULL,
  NULL,
  addresses_with_gps,
  pct_geocoded,
  NULL,
  NULL
FROM geographic_coverage
UNION ALL
SELECT
  'Adresses avec BAN_ID',
  NULL,
  NULL,
  addresses_with_ban_id,
  pct_with_ban_id,
  NULL,
  NULL
FROM geographic_coverage

-- Section 3 : Type de position (décommentez si besoin)
/*
SELECT * FROM position_type_distribution;
*/

-- Section 4 : Qualité par département (décommentez si besoin)
/*
SELECT * FROM quality_by_department;
*/

-- Section 5 : Échantillon par niveau (décommentez si besoin)
/*
SELECT * FROM sample_by_match_level;
*/

-- Section 6 : Pires communes (décommentez si besoin)
/*
SELECT * FROM worst_matching_communes;
*/
