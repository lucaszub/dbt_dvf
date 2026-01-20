{{
  config(
    materialized='view',
    database='VALFONC_ANALYTICS_DBT',
    schema='SILVER'
  )
}}

/*
  ============================================================================
  BAN ADDRESSES NORMALIZED - Couche Silver optimisée pour le matching
  ============================================================================

  Objectif : Préparer les adresses BAN avec des clés de matching multiples
             pour faciliter la jointure avec DVF à différents niveaux de précision

  Niveaux de matching supportés :
    1. EXACT        : numéro + nom voie complet + CP + commune
    2. SANS_TYPE    : numéro + voie (sans type) + CP + commune
    3. VOIE_SEULE   : nom voie + CP + commune (sans numéro)
    4. CODE_POSTAL  : code postal + commune
    5. COMMUNE      : code INSEE seul (centroïde commune)
*/

WITH ban_base AS (
  SELECT
    -- ========== IDENTIFIANTS ==========
    TRIM("id") AS BAN_ID,
    TRIM("id_fantoir") AS ID_FANTOIR,

    -- ========== ADRESSE BRUTE ==========
    TRIM("numero") AS NUMERO_RAW,
    UPPER(TRIM("rep")) AS REPETITION,
    UPPER(REGEXP_REPLACE(TRIM("nom_voie"), '\\s+', ' ')) AS NOM_VOIE_RAW,
    TRIM("code_postal") AS CODE_POSTAL,
    TRIM("code_insee") AS CODE_INSEE,
    UPPER(REGEXP_REPLACE(TRIM("nom_commune"), '\\s+', ' ')) AS NOM_COMMUNE,
    TRIM("code_insee_ancienne_commune") AS CODE_INSEE_ANCIENNE_COMMUNE,
    UPPER(REGEXP_REPLACE(TRIM(NULLIF("nom_ancienne_commune", '')), '\\s+', ' ')) AS NOM_ANCIENNE_COMMUNE,
    TRIM("departement") AS CODE_DEPARTEMENT,

    -- ========== COORDONNÉES ==========
    TRY_TO_NUMBER(REPLACE("x", ',', '.')) AS X_LAMBERT93,
    TRY_TO_NUMBER(REPLACE("y", ',', '.')) AS Y_LAMBERT93,
    TRY_TO_NUMBER(REPLACE("lon", ',', '.')) AS LONGITUDE,
    TRY_TO_NUMBER(REPLACE("lat", ',', '.')) AS LATITUDE,

    -- ========== MÉTADONNÉES QUALITÉ ==========
    UPPER(TRIM("type_position")) AS TYPE_POSITION,
    UPPER(TRIM("source_position")) AS SOURCE_POSITION,
    UPPER(TRIM("source_nom_voie")) AS SOURCE_NOM_VOIE,
    TRIM("certification_commune") AS CERTIFICATION_COMMUNE,
    "alias" AS ALIAS,

    -- ========== ENRICHISSEMENT ==========
    UPPER(REGEXP_REPLACE(TRIM(NULLIF("nom_ld", '')), '\\s+', ' ')) AS NOM_LIEU_DIT,
    UPPER(REGEXP_REPLACE(TRIM("libelle_acheminement"), '\\s+', ' ')) AS LIBELLE_ACHEMINEMENT,
    UPPER(REGEXP_REPLACE(TRIM("nom_afnor"), '\\s+', ' ')) AS NOM_AFNOR,
    TRIM("cad_parcelles") AS PARCELLES_CADASTRALES

  FROM {{ source('bronze', 'BAN_ADRESSES') }}
  WHERE "id" IS NOT NULL
    AND "code_postal" IS NOT NULL
    AND "code_insee" IS NOT NULL
),

ban_with_keys AS (
  SELECT
    *,

    -- ========== CLÉS DE MATCHING NORMALISÉES ==========

    -- Numéro normalisé (avec répétition si présente)
    CASE
      WHEN REPETITION IS NOT NULL THEN NUMERO_RAW || ' ' || REPETITION
      ELSE NUMERO_RAW
    END AS NUMERO_COMPLET,

    -- Nom de voie sans type (extraction)
    -- Supprime les types courants : RUE, AVENUE, BOULEVARD, PLACE, etc.
    REGEXP_REPLACE(
      NOM_VOIE_RAW,
      '^(RUE|AVENUE|AVE|AV|BOULEVARD|BD|PLACE|PL|CHEMIN|CHE|IMPASSE|IMP|ALLEE|ALL|ROUTE|RTE|QUAI|SQUARE|SQ|PASSAGE|VOIE|COURS|CRS|MAIL|ESPLANADE|PROMENADE|PARC|VILLA|COUR|HAMEAU|CITE|RESIDENCE|RES|LOTISSEMENT|LOT)\\s+',
      ''
    ) AS NOM_VOIE_SANS_TYPE,

    -- Clé exacte niveau 1 (numéro + voie complète + CP + commune)
    CONCAT(
      COALESCE(NUMERO_RAW, ''),
      '|',
      COALESCE(REPETITION, ''),
      '|',
      COALESCE(NOM_VOIE_RAW, ''),
      '|',
      COALESCE(CODE_POSTAL, ''),
      '|',
      COALESCE(NOM_COMMUNE, '')
    ) AS MATCH_KEY_EXACT,

    -- Clé niveau 2 (numéro + voie sans type + CP + commune)
    CONCAT(
      COALESCE(NUMERO_RAW, ''),
      '|',
      COALESCE(
        REGEXP_REPLACE(
          NOM_VOIE_RAW,
          '^(RUE|AVENUE|AVE|AV|BOULEVARD|BD|PLACE|PL|CHEMIN|CHE|IMPASSE|IMP|ALLEE|ALL|ROUTE|RTE|QUAI|SQUARE|SQ|PASSAGE|VOIE|COURS|CRS|MAIL|ESPLANADE|PROMENADE|PARC|VILLA|COUR|HAMEAU|CITE|RESIDENCE|RES|LOTISSEMENT|LOT)\\s+',
          ''
        ),
        ''
      ),
      '|',
      COALESCE(CODE_POSTAL, ''),
      '|',
      COALESCE(NOM_COMMUNE, '')
    ) AS MATCH_KEY_SANS_TYPE,

    -- Clé niveau 3 (voie seule + CP + commune, sans numéro)
    CONCAT(
      COALESCE(NOM_VOIE_RAW, ''),
      '|',
      COALESCE(CODE_POSTAL, ''),
      '|',
      COALESCE(NOM_COMMUNE, '')
    ) AS MATCH_KEY_VOIE,

    -- Clé niveau 4 (code postal + commune uniquement)
    CONCAT(
      COALESCE(CODE_POSTAL, ''),
      '|',
      COALESCE(NOM_COMMUNE, '')
    ) AS MATCH_KEY_CODE_POSTAL,

    -- Clé niveau 5 (code INSEE seul)
    CODE_INSEE AS MATCH_KEY_COMMUNE,

    -- ========== SCORE DE PRÉCISION ==========
    -- Score basé sur la précision du positionnement
    CASE TYPE_POSITION
      WHEN 'HOUSENUMBER' THEN 100
      WHEN 'INTERPOLATION' THEN 80
      WHEN 'STREET' THEN 60
      WHEN 'LOCALITY' THEN 40
      WHEN 'MUNICIPALITY' THEN 20
      ELSE 10
    END AS PRECISION_SCORE,

    -- Score de certification
    CASE
      WHEN CERTIFICATION_COMMUNE = '1' THEN 10
      ELSE 0
    END AS CERTIFICATION_SCORE,

    -- Score total (combiné)
    CASE TYPE_POSITION
      WHEN 'HOUSENUMBER' THEN 100
      WHEN 'INTERPOLATION' THEN 80
      WHEN 'STREET' THEN 60
      WHEN 'LOCALITY' THEN 40
      WHEN 'MUNICIPALITY' THEN 20
      ELSE 10
    END +
    CASE WHEN CERTIFICATION_COMMUNE = '1' THEN 10 ELSE 0 END AS QUALITY_SCORE,

    -- ========== AUDIT ==========
    CURRENT_TIMESTAMP() AS CREATED_AT

  FROM ban_base
)

SELECT * FROM ban_with_keys
WHERE LONGITUDE IS NOT NULL
  AND LATITUDE IS NOT NULL
  -- Filtre sur les coordonnées valides pour la France métropolitaine
  AND LATITUDE BETWEEN 41.0 AND 51.5
  AND LONGITUDE BETWEEN -5.5 AND 10.0
