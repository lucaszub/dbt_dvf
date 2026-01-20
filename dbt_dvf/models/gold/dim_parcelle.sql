WITH clean AS (
  SELECT
    /* Normalisation + trim */
    UPPER(TRIM(PREFIXE_DE_SECTION)) AS PREFIXE_DE_SECTION_N,
    UPPER(TRIM(SECTION))            AS SECTION_N,
    TRIM(NO_PLAN)                   AS NO_PLAN_N,
    TRIM(COALESCE(NO_VOLUME, ''))   AS NO_VOLUME_N   -- volume optionnel
  FROM {{ ref('dvf_silver') }}
)
SELECT
  /* Clé technique parcelle */
  HASH(
    COALESCE(PREFIXE_DE_SECTION_N, '') || '|' ||
    COALESCE(SECTION_N, '')            || '|' ||
    COALESCE(NO_PLAN_N, '')            || '|' ||
    COALESCE(NO_VOLUME_N, '')
  ) AS PARCELLE_ID,

  /* Attributs (version normalisée) */
  PREFIXE_DE_SECTION_N AS PREFIXE_DE_SECTION,
  SECTION_N            AS SECTION,
  NO_PLAN_N            AS NO_PLAN,
  NULLIF(NO_VOLUME_N, '') AS NO_VOLUME,  -- remettre NULL si vide

  /* Flag qualité : 1 = identifiant parcelle incomplet (SECTION ou NO_PLAN manquants) */
  CASE
    WHEN SECTION_N IS NULL OR NO_PLAN_N IS NULL THEN 1
    ELSE 0
  END AS IS_PARTIAL,

  CURRENT_TIMESTAMP() AS CREATED_AT
FROM clean
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY PREFIXE_DE_SECTION_N, SECTION_N, NO_PLAN_N, NO_VOLUME_N
  ORDER BY SECTION_N, NO_PLAN_N
) = 1