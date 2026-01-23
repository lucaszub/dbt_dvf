WITH clean AS (
  SELECT
    /* Normalisations alignées avec les DIMs */
    UPPER(TRIM(NO_VOIE))                                        AS NO_VOIE_N,
    UPPER(TRIM(TYPE_DE_VOIE))                                   AS TYPE_DE_VOIE_N,
    UPPER(REGEXP_REPLACE(TRIM(VOIE), '\\s+', ' '))              AS VOIE_N,
    TRIM(CODE_POSTAL)                                           AS CODE_POSTAL_N,
    UPPER(REGEXP_REPLACE(TRIM(COMMUNE), '\\s+', ' '))           AS COMMUNE_N,
    TRIM(CODE_DEPARTEMENT)                                      AS CODE_DEPARTEMENT_N,

    UPPER(TRIM(PREFIXE_DE_SECTION))                             AS PREFIXE_DE_SECTION_N,
    UPPER(TRIM(SECTION))                                        AS SECTION_N,
    TRIM(NO_PLAN)                                               AS NO_PLAN_N,
    TRIM(COALESCE(NO_VOLUME, ''))                               AS NO_VOLUME_N,

    COALESCE(UPPER(TRIM(TYPE_LOCAL)), 'INCONNU')                AS TYPE_LOCAL_N,

    /* Mesures & attributs (casts tolérants) */
    DATE_MUTATION,
    NATURE_MUTATION,
    TRY_TO_NUMBER(REPLACE(VALEUR_FONCIERE, ',', '.'))           AS VALEUR_FONCIERE,
    TRY_TO_NUMBER(REPLACE(SURFACE_REELLE_BATI, ',', '.'))       AS SURFACE_REELLE_BATI,
    TRY_TO_NUMBER(REPLACE(SURFACE_TERRAIN, ',', '.'))           AS SURFACE_TERRAIN,
    TRY_TO_NUMBER(NOMBRE_PIECES_PRINCIPALES)                    AS NOMBRE_PIECES_PRINCIPALES,

    /* Colonnes brutes conservées pour debug et analyse */
    NO_VOIE, BTQ, TYPE_DE_VOIE, CODE_VOIE, CODE_POSTAL, COMMUNE, VOIE,
    CODE_DEPARTEMENT, PREFIXE_DE_SECTION, SECTION, NO_PLAN, NO_VOLUME, TYPE_LOCAL
  FROM {{ ref('stg_dvf_transactions') }}
  WHERE NATURE_MUTATION IN ('Vente')
),

dim_address_enriched AS (
  SELECT
    ADDRESS_ID,
    NO_VOIE,
    TYPE_DE_VOIE,
    VOIE,
    CODE_POSTAL,
    COMMUNE,
    CODE_DEPARTEMENT,
    -- Enrichissement BAN
    BAN_ID,
    CODE_INSEE,
    LONGITUDE,
    LATITUDE,
    MATCH_LEVEL,
    MATCH_SCORE
  FROM {{ ref('dim_address_enriched') }}
),

dim_commune AS (
  SELECT COMMUNE_ID, COMMUNE, CODE_DEPARTEMENT
  FROM {{ ref('dim_commune') }}
),

dim_parcelle AS (
  SELECT PARCELLE_ID, PREFIXE_DE_SECTION, SECTION, NO_PLAN, NO_VOLUME
  FROM {{ ref('dim_parcelle') }}
),

dim_type_local AS (
  SELECT TYPE_LOCAL_ID, COALESCE(UPPER(TRIM(TYPE_LOCAL)), 'INCONNU') AS TYPE_LOCAL_N
  FROM {{ ref('dim_type_local') }}
),

dim_code_postal AS (
  SELECT CODE_POSTAL_ID, CODE_POSTAL, CODE_DEPARTEMENT
  FROM {{ ref('dim_code_postal') }}
)

SELECT
  /* FKs */
  /* Address avec fallback (aucun NULL) */
  COALESCE(
    da.ADDRESS_ID,
    TO_CHAR(HASH('UNKNOWN|' || c.COMMUNE_N || '|' || c.CODE_DEPARTEMENT_N), 'XXXXXXXXXXXXXXXX')
  ) AS ADDRESS_ID,

  dc.COMMUNE_ID,
  dp.PARCELLE_ID,
  dtl.TYPE_LOCAL_ID,
  dcp.CODE_POSTAL_ID,

  /* Enrichissement géographique BAN */
  da.BAN_ID,
  da.CODE_INSEE,
  da.LONGITUDE,
  da.LATITUDE,

  /* Qualité du géocodage (traçabilité) */
  da.MATCH_LEVEL AS GEOCODING_MATCH_LEVEL,
  da.MATCH_SCORE AS GEOCODING_MATCH_SCORE,
  CASE
    WHEN da.ADDRESS_ID IS NOT NULL THEN 'MATCH_ADDRESS'
    WHEN dc.COMMUNE_ID IS NOT NULL THEN 'FALLBACK_COMMUNE'
    ELSE 'NO_MATCH'
  END AS ADDRESS_MATCH_STRATEGY,

  /* Mesures & attributs de transaction */
  c.DATE_MUTATION,
  c.NATURE_MUTATION,
  c.VALEUR_FONCIERE,
  c.SURFACE_REELLE_BATI,
  c.NOMBRE_PIECES_PRINCIPALES,
  c.SURFACE_TERRAIN,

  CURRENT_TIMESTAMP() AS CREATED_AT

FROM clean c
/* Adresse enrichie BAN – jointure sur 6 champs normalisés */
/* COALESCE utilisé pour NO_VOIE et TYPE_DE_VOIE car souvent NULL (35% des transactions) */
LEFT JOIN dim_address_enriched da
  ON COALESCE(da.NO_VOIE, '')          = COALESCE(c.NO_VOIE_N, '')
 AND COALESCE(da.TYPE_DE_VOIE, '')     = COALESCE(c.TYPE_DE_VOIE_N, '')
 AND COALESCE(da.VOIE, '')             = COALESCE(c.VOIE_N, '')
 AND da.CODE_POSTAL                    = c.CODE_POSTAL_N
 AND da.COMMUNE                        = c.COMMUNE_N
 AND da.CODE_DEPARTEMENT               = c.CODE_DEPARTEMENT_N

/* Commune */
LEFT JOIN dim_commune dc
  ON dc.COMMUNE          = c.COMMUNE_N
 AND dc.CODE_DEPARTEMENT = c.CODE_DEPARTEMENT_N

/* Type de local */
LEFT JOIN dim_type_local dtl
  ON dtl.TYPE_LOCAL_N    = c.TYPE_LOCAL_N

/* Parcelle (NO_VOLUME : NULL/vides alignés via NVL) */
LEFT JOIN dim_parcelle dp
  ON dp.PREFIXE_DE_SECTION = c.PREFIXE_DE_SECTION_N
 AND dp.SECTION            = c.SECTION_N
 AND dp.NO_PLAN            = c.NO_PLAN_N
 AND NVL(dp.NO_VOLUME, '') = c.NO_VOLUME_N

/* Code postal (CP + département) */
LEFT JOIN dim_code_postal dcp
  ON dcp.CODE_POSTAL      = c.CODE_POSTAL_N
 AND dcp.CODE_DEPARTEMENT = c.CODE_DEPARTEMENT_N