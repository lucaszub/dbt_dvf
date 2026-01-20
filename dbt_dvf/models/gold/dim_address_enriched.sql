{{
  config(
    materialized='table',
    database='VALFONC_ANALYTICS_DBT',
    schema='GOLD'
  )
}}

/*
  ============================================================================
  DIM_ADDRESS_ENRICHED - Dimension adresse enrichie avec géocodage BAN
  ============================================================================

  Objectif : Créer une dimension adresse unique enrichie avec :
    - Coordonnées GPS (longitude, latitude)
    - Coordonnées Lambert 93 (x, y)
    - Métadonnées de qualité (niveau de matching, score)
    - Informations cadastrales BAN

  Stratégie de matching multi-niveaux (du plus précis au moins précis) :
    1. EXACT         : numéro + nom voie complet + CP + commune (score 100)
    2. SANS_TYPE     : numéro + voie sans type + CP + commune (score 90)
    3. VOIE_SEULE    : nom voie + CP + commune, sans numéro (score 70)
    4. CODE_POSTAL   : centroïde du code postal (score 50)
    5. COMMUNE       : centroïde de la commune via code INSEE (score 30)
    6. NO_MATCH      : aucun match trouvé (score 0)
*/

WITH dvf_addresses_base AS (
  -- Extraction des adresses uniques depuis DVF avec normalisation
  SELECT
    UPPER(TRIM(NO_VOIE)) AS NO_VOIE_N,
    UPPER(TRIM(TYPE_DE_VOIE)) AS TYPE_DE_VOIE_N,
    UPPER(REGEXP_REPLACE(TRIM(VOIE), '\\s+', ' ')) AS VOIE_N,
    TRIM(CODE_POSTAL) AS CODE_POSTAL_N,
    UPPER(REGEXP_REPLACE(TRIM(COMMUNE), '\\s+', ' ')) AS COMMUNE_N,
    TRIM(CODE_DEPARTEMENT) AS CODE_DEPARTEMENT_N
  FROM {{ ref('dvf_silver') }}
  WHERE CODE_POSTAL IS NOT NULL
    AND COMMUNE IS NOT NULL
),

dvf_addresses_with_keys AS (
  SELECT
    -- Clé unique de l'adresse (hash des champs DVF)
    TO_CHAR(
      HASH(
        COALESCE(NO_VOIE_N, '') || '|' ||
        COALESCE(TYPE_DE_VOIE_N, '') || '|' ||
        COALESCE(VOIE_N, '') || '|' ||
        COALESCE(CODE_POSTAL_N, '') || '|' ||
        COALESCE(COMMUNE_N, '') || '|' ||
        COALESCE(CODE_DEPARTEMENT_N, '')
      ),
      'XXXXXXXXXXXXXXXX'
    ) AS ADDRESS_ID,

    NO_VOIE_N,
    TYPE_DE_VOIE_N,
    VOIE_N,
    CODE_POSTAL_N,
    COMMUNE_N,
    CODE_DEPARTEMENT_N,

    -- Construction du nom de voie complet (type + voie)
    CASE
      WHEN TYPE_DE_VOIE_N IS NOT NULL AND VOIE_N IS NOT NULL
        THEN TYPE_DE_VOIE_N || ' ' || VOIE_N
      WHEN VOIE_N IS NOT NULL
        THEN VOIE_N
      ELSE NULL
    END AS NOM_VOIE_COMPLET,

    -- ========== CLÉS DE MATCHING (alignées avec BAN) ==========

    -- Clé niveau 1 : EXACT (avec type de voie)
    CONCAT(
      COALESCE(NO_VOIE_N, ''),
      '|',
      '', -- DVF n'a pas de répétition (bis, ter)
      '|',
      COALESCE(
        CASE
          WHEN TYPE_DE_VOIE_N IS NOT NULL AND VOIE_N IS NOT NULL
            THEN TYPE_DE_VOIE_N || ' ' || VOIE_N
          WHEN VOIE_N IS NOT NULL
            THEN VOIE_N
          ELSE ''
        END,
        ''
      ),
      '|',
      COALESCE(CODE_POSTAL_N, ''),
      '|',
      COALESCE(COMMUNE_N, '')
    ) AS MATCH_KEY_EXACT,

    -- Clé niveau 2 : SANS_TYPE (juste la voie, sans type)
    CONCAT(
      COALESCE(NO_VOIE_N, ''),
      '|',
      COALESCE(VOIE_N, ''),
      '|',
      COALESCE(CODE_POSTAL_N, ''),
      '|',
      COALESCE(COMMUNE_N, '')
    ) AS MATCH_KEY_SANS_TYPE,

    -- Clé niveau 3 : VOIE_SEULE (sans numéro)
    CONCAT(
      COALESCE(
        CASE
          WHEN TYPE_DE_VOIE_N IS NOT NULL AND VOIE_N IS NOT NULL
            THEN TYPE_DE_VOIE_N || ' ' || VOIE_N
          WHEN VOIE_N IS NOT NULL
            THEN VOIE_N
          ELSE ''
        END,
        ''
      ),
      '|',
      COALESCE(CODE_POSTAL_N, ''),
      '|',
      COALESCE(COMMUNE_N, '')
    ) AS MATCH_KEY_VOIE,

    -- Clé niveau 4 : CODE_POSTAL
    CONCAT(
      COALESCE(CODE_POSTAL_N, ''),
      '|',
      COALESCE(COMMUNE_N, '')
    ) AS MATCH_KEY_CODE_POSTAL

  FROM dvf_addresses_base
),

dvf_addresses_unique AS (
  -- Déduplication des adresses DVF
  SELECT *
  FROM dvf_addresses_with_keys
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
      COALESCE(NO_VOIE_N, ''),
      COALESCE(TYPE_DE_VOIE_N, ''),
      COALESCE(VOIE_N, ''),
      COALESCE(CODE_POSTAL_N, ''),
      COALESCE(COMMUNE_N, ''),
      COALESCE(CODE_DEPARTEMENT_N, '')
    ORDER BY NO_VOIE_N
  ) = 1
),

ban_normalized AS (
  -- Import BAN normalisé
  SELECT *
  FROM {{ ref('ban_addresses_normalized') }}
),

-- ============================================================================
-- MATCHING MULTI-NIVEAUX (du plus précis au moins précis)
-- ============================================================================

-- NIVEAU 1 : EXACT MATCH
matched_exact AS (
  SELECT
    dvf.ADDRESS_ID,
    dvf.NO_VOIE_N,
    dvf.TYPE_DE_VOIE_N,
    dvf.VOIE_N,
    dvf.CODE_POSTAL_N,
    dvf.COMMUNE_N,
    dvf.CODE_DEPARTEMENT_N,
    dvf.NOM_VOIE_COMPLET,

    ban.BAN_ID,
    ban.CODE_INSEE,
    ban.ID_FANTOIR,
    ban.LONGITUDE,
    ban.LATITUDE,
    ban.X_LAMBERT93,
    ban.Y_LAMBERT93,
    ban.TYPE_POSITION,
    ban.SOURCE_POSITION,
    ban.PARCELLES_CADASTRALES,
    ban.LIBELLE_ACHEMINEMENT,
    ban.NOM_AFNOR,
    ban.QUALITY_SCORE AS BAN_QUALITY_SCORE,

    'EXACT' AS MATCH_LEVEL,
    100 AS MATCH_SCORE

  FROM dvf_addresses_unique dvf
  INNER JOIN ban_normalized ban
    ON dvf.MATCH_KEY_EXACT = ban.MATCH_KEY_EXACT

  -- En cas de plusieurs matchs BAN, prendre le meilleur (qualité + précision)
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY dvf.ADDRESS_ID
    ORDER BY ban.QUALITY_SCORE DESC, ban.PRECISION_SCORE DESC
  ) = 1
),

-- NIVEAU 2 : SANS TYPE DE VOIE
matched_sans_type AS (
  SELECT
    dvf.ADDRESS_ID,
    dvf.NO_VOIE_N,
    dvf.TYPE_DE_VOIE_N,
    dvf.VOIE_N,
    dvf.CODE_POSTAL_N,
    dvf.COMMUNE_N,
    dvf.CODE_DEPARTEMENT_N,
    dvf.NOM_VOIE_COMPLET,

    ban.BAN_ID,
    ban.CODE_INSEE,
    ban.ID_FANTOIR,
    ban.LONGITUDE,
    ban.LATITUDE,
    ban.X_LAMBERT93,
    ban.Y_LAMBERT93,
    ban.TYPE_POSITION,
    ban.SOURCE_POSITION,
    ban.PARCELLES_CADASTRALES,
    ban.LIBELLE_ACHEMINEMENT,
    ban.NOM_AFNOR,
    ban.QUALITY_SCORE AS BAN_QUALITY_SCORE,

    'SANS_TYPE' AS MATCH_LEVEL,
    90 AS MATCH_SCORE

  FROM dvf_addresses_unique dvf
  INNER JOIN ban_normalized ban
    ON dvf.MATCH_KEY_SANS_TYPE = ban.MATCH_KEY_SANS_TYPE
  WHERE dvf.ADDRESS_ID NOT IN (SELECT ADDRESS_ID FROM matched_exact)

  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY dvf.ADDRESS_ID
    ORDER BY ban.QUALITY_SCORE DESC, ban.PRECISION_SCORE DESC
  ) = 1
),

-- NIVEAU 3 : VOIE SEULE (sans numéro - centroïde de la rue)
matched_voie AS (
  SELECT
    dvf.ADDRESS_ID,
    dvf.NO_VOIE_N,
    dvf.TYPE_DE_VOIE_N,
    dvf.VOIE_N,
    dvf.CODE_POSTAL_N,
    dvf.COMMUNE_N,
    dvf.CODE_DEPARTEMENT_N,
    dvf.NOM_VOIE_COMPLET,

    ban.BAN_ID,
    ban.CODE_INSEE,
    ban.ID_FANTOIR,
    -- Moyenne des coordonnées de la voie (centroïde)
    AVG(ban.LONGITUDE) AS LONGITUDE,
    AVG(ban.LATITUDE) AS LATITUDE,
    AVG(ban.X_LAMBERT93) AS X_LAMBERT93,
    AVG(ban.Y_LAMBERT93) AS Y_LAMBERT93,
    'STREET' AS TYPE_POSITION,
    MAX(ban.SOURCE_POSITION) AS SOURCE_POSITION,
    MAX(ban.PARCELLES_CADASTRALES) AS PARCELLES_CADASTRALES,
    MAX(ban.LIBELLE_ACHEMINEMENT) AS LIBELLE_ACHEMINEMENT,
    MAX(ban.NOM_AFNOR) AS NOM_AFNOR,
    AVG(ban.QUALITY_SCORE) AS BAN_QUALITY_SCORE,

    'VOIE_SEULE' AS MATCH_LEVEL,
    70 AS MATCH_SCORE

  FROM dvf_addresses_unique dvf
  INNER JOIN ban_normalized ban
    ON dvf.MATCH_KEY_VOIE = ban.MATCH_KEY_VOIE
  WHERE dvf.ADDRESS_ID NOT IN (
    SELECT ADDRESS_ID FROM matched_exact
    UNION ALL
    SELECT ADDRESS_ID FROM matched_sans_type
  )
  GROUP BY
    dvf.ADDRESS_ID,
    dvf.NO_VOIE_N,
    dvf.TYPE_DE_VOIE_N,
    dvf.VOIE_N,
    dvf.CODE_POSTAL_N,
    dvf.COMMUNE_N,
    dvf.CODE_DEPARTEMENT_N,
    dvf.NOM_VOIE_COMPLET,
    ban.BAN_ID,
    ban.CODE_INSEE,
    ban.ID_FANTOIR

  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY dvf.ADDRESS_ID
    ORDER BY AVG(ban.QUALITY_SCORE) DESC
  ) = 1
),

-- NIVEAU 4 : CODE POSTAL (centroïde du code postal)
matched_code_postal AS (
  SELECT
    dvf.ADDRESS_ID,
    dvf.NO_VOIE_N,
    dvf.TYPE_DE_VOIE_N,
    dvf.VOIE_N,
    dvf.CODE_POSTAL_N,
    dvf.COMMUNE_N,
    dvf.CODE_DEPARTEMENT_N,
    dvf.NOM_VOIE_COMPLET,

    NULL AS BAN_ID,
    MAX(ban.CODE_INSEE) AS CODE_INSEE,
    NULL AS ID_FANTOIR,
    AVG(ban.LONGITUDE) AS LONGITUDE,
    AVG(ban.LATITUDE) AS LATITUDE,
    AVG(ban.X_LAMBERT93) AS X_LAMBERT93,
    AVG(ban.Y_LAMBERT93) AS Y_LAMBERT93,
    'LOCALITY' AS TYPE_POSITION,
    'COMPUTED_CENTROID' AS SOURCE_POSITION,
    NULL AS PARCELLES_CADASTRALES,
    MAX(ban.LIBELLE_ACHEMINEMENT) AS LIBELLE_ACHEMINEMENT,
    NULL AS NOM_AFNOR,
    AVG(ban.QUALITY_SCORE) AS BAN_QUALITY_SCORE,

    'CODE_POSTAL' AS MATCH_LEVEL,
    50 AS MATCH_SCORE

  FROM dvf_addresses_unique dvf
  INNER JOIN ban_normalized ban
    ON dvf.MATCH_KEY_CODE_POSTAL = ban.MATCH_KEY_CODE_POSTAL
  WHERE dvf.ADDRESS_ID NOT IN (
    SELECT ADDRESS_ID FROM matched_exact
    UNION ALL
    SELECT ADDRESS_ID FROM matched_sans_type
    UNION ALL
    SELECT ADDRESS_ID FROM matched_voie
  )
  GROUP BY
    dvf.ADDRESS_ID,
    dvf.NO_VOIE_N,
    dvf.TYPE_DE_VOIE_N,
    dvf.VOIE_N,
    dvf.CODE_POSTAL_N,
    dvf.COMMUNE_N,
    dvf.CODE_DEPARTEMENT_N,
    dvf.NOM_VOIE_COMPLET
),

-- NIVEAU 5 : COMMUNE (centroïde de la commune via code INSEE)
matched_commune AS (
  SELECT
    dvf.ADDRESS_ID,
    dvf.NO_VOIE_N,
    dvf.TYPE_DE_VOIE_N,
    dvf.VOIE_N,
    dvf.CODE_POSTAL_N,
    dvf.COMMUNE_N,
    dvf.CODE_DEPARTEMENT_N,
    dvf.NOM_VOIE_COMPLET,

    NULL AS BAN_ID,
    ban.CODE_INSEE,
    NULL AS ID_FANTOIR,
    AVG(ban.LONGITUDE) AS LONGITUDE,
    AVG(ban.LATITUDE) AS LATITUDE,
    AVG(ban.X_LAMBERT93) AS X_LAMBERT93,
    AVG(ban.Y_LAMBERT93) AS Y_LAMBERT93,
    'MUNICIPALITY' AS TYPE_POSITION,
    'COMPUTED_CENTROID' AS SOURCE_POSITION,
    NULL AS PARCELLES_CADASTRALES,
    MAX(ban.LIBELLE_ACHEMINEMENT) AS LIBELLE_ACHEMINEMENT,
    NULL AS NOM_AFNOR,
    AVG(ban.QUALITY_SCORE) AS BAN_QUALITY_SCORE,

    'COMMUNE' AS MATCH_LEVEL,
    30 AS MATCH_SCORE

  FROM dvf_addresses_unique dvf
  INNER JOIN ban_normalized ban
    ON dvf.CODE_POSTAL_N = ban.CODE_POSTAL
    AND dvf.COMMUNE_N = ban.NOM_COMMUNE
  WHERE dvf.ADDRESS_ID NOT IN (
    SELECT ADDRESS_ID FROM matched_exact
    UNION ALL
    SELECT ADDRESS_ID FROM matched_sans_type
    UNION ALL
    SELECT ADDRESS_ID FROM matched_voie
    UNION ALL
    SELECT ADDRESS_ID FROM matched_code_postal
  )
  GROUP BY
    dvf.ADDRESS_ID,
    dvf.NO_VOIE_N,
    dvf.TYPE_DE_VOIE_N,
    dvf.VOIE_N,
    dvf.CODE_POSTAL_N,
    dvf.COMMUNE_N,
    dvf.CODE_DEPARTEMENT_N,
    dvf.NOM_VOIE_COMPLET,
    ban.CODE_INSEE
),

-- NIVEAU 6 : NO_MATCH (aucun enrichissement possible)
no_match AS (
  SELECT
    dvf.ADDRESS_ID,
    dvf.NO_VOIE_N,
    dvf.TYPE_DE_VOIE_N,
    dvf.VOIE_N,
    dvf.CODE_POSTAL_N,
    dvf.COMMUNE_N,
    dvf.CODE_DEPARTEMENT_N,
    dvf.NOM_VOIE_COMPLET,

    NULL AS BAN_ID,
    NULL AS CODE_INSEE,
    NULL AS ID_FANTOIR,
    NULL AS LONGITUDE,
    NULL AS LATITUDE,
    NULL AS X_LAMBERT93,
    NULL AS Y_LAMBERT93,
    NULL AS TYPE_POSITION,
    NULL AS SOURCE_POSITION,
    NULL AS PARCELLES_CADASTRALES,
    NULL AS LIBELLE_ACHEMINEMENT,
    NULL AS NOM_AFNOR,
    NULL AS BAN_QUALITY_SCORE,

    'NO_MATCH' AS MATCH_LEVEL,
    0 AS MATCH_SCORE

  FROM dvf_addresses_unique dvf
  WHERE dvf.ADDRESS_ID NOT IN (
    SELECT ADDRESS_ID FROM matched_exact
    UNION ALL
    SELECT ADDRESS_ID FROM matched_sans_type
    UNION ALL
    SELECT ADDRESS_ID FROM matched_voie
    UNION ALL
    SELECT ADDRESS_ID FROM matched_code_postal
    UNION ALL
    SELECT ADDRESS_ID FROM matched_commune
  )
),

-- ============================================================================
-- UNION DE TOUS LES NIVEAUX
-- ============================================================================

all_matches AS (
  SELECT * FROM matched_exact
  UNION ALL
  SELECT * FROM matched_sans_type
  UNION ALL
  SELECT * FROM matched_voie
  UNION ALL
  SELECT * FROM matched_code_postal
  UNION ALL
  SELECT * FROM matched_commune
  UNION ALL
  SELECT * FROM no_match
)

-- ============================================================================
-- RÉSULTAT FINAL
-- ============================================================================

SELECT
  -- ========== IDENTIFIANTS ==========
  ADDRESS_ID,
  BAN_ID,

  -- ========== ADRESSE DVF (normalisée) ==========
  NO_VOIE_N AS NO_VOIE,
  TYPE_DE_VOIE_N AS TYPE_DE_VOIE,
  VOIE_N AS VOIE,
  CODE_POSTAL_N AS CODE_POSTAL,
  COMMUNE_N AS COMMUNE,
  CODE_DEPARTEMENT_N AS CODE_DEPARTEMENT,

  -- Adresse complète formatée
  CONCAT(
    COALESCE(NO_VOIE_N, ''), ' ',
    COALESCE(TYPE_DE_VOIE_N, ''), ' ',
    COALESCE(VOIE_N, ''), ', ',
    COALESCE(CODE_POSTAL_N, ''), ' ',
    COALESCE(COMMUNE_N, '')
  ) AS ADDRESS_FULL,

  -- ========== ENRICHISSEMENT BAN ==========
  CODE_INSEE,
  ID_FANTOIR,

  -- ========== COORDONNÉES GÉOGRAPHIQUES ==========
  LONGITUDE,
  LATITUDE,
  X_LAMBERT93,
  Y_LAMBERT93,

  -- ========== QUALITÉ DU GÉOCODAGE ==========
  MATCH_LEVEL,
  MATCH_SCORE,
  TYPE_POSITION,
  SOURCE_POSITION,
  BAN_QUALITY_SCORE,

  -- ========== ENRICHISSEMENT CADASTRAL ==========
  PARCELLES_CADASTRALES,
  LIBELLE_ACHEMINEMENT,
  NOM_AFNOR,

  -- ========== AUDIT ==========
  CURRENT_TIMESTAMP() AS CREATED_AT,
  CURRENT_TIMESTAMP() AS UPDATED_AT

FROM all_matches
