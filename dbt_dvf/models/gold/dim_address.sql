WITH clean AS (
  SELECT
    /* Normalisation + écrasement des espaces multiples */
    UPPER(TRIM(NO_VOIE))                                         AS NO_VOIE_N,
    UPPER(TRIM(TYPE_DE_VOIE))                                    AS TYPE_DE_VOIE_N,
    UPPER(REGEXP_REPLACE(TRIM(VOIE), '\\s+', ' '))               AS VOIE_N,
    TRIM(CODE_POSTAL)                                            AS CODE_POSTAL_N,
    UPPER(REGEXP_REPLACE(TRIM(COMMUNE), '\\s+', ' '))            AS COMMUNE_N,
    TRIM(CODE_DEPARTEMENT)                                       AS CODE_DEPARTEMENT_N
  FROM {{ ref('stg_dvf_transactions') }}
)
SELECT
  /* Clé texte (HEX de 64 bits) – évite tout problème de précision dans Power BI */
    TO_CHAR(
    HASH(
      COALESCE(NO_VOIE_N, '')          || '|' ||
      COALESCE(TYPE_DE_VOIE_N, '')     || '|' ||
      COALESCE(VOIE_N, '')             || '|' ||
      COALESCE(CODE_POSTAL_N, '')      || '|' ||
      COALESCE(COMMUNE_N, '')          || '|' ||
      COALESCE(CODE_DEPARTEMENT_N, '')
    ),
    'XXXXXXXXXXXXXXXX'
  ) AS ADDRESS_ID,

  /* Colonnes métiers (normalisées) */
  NO_VOIE_N            AS NO_VOIE,
  TYPE_DE_VOIE_N       AS TYPE_DE_VOIE,
  VOIE_N               AS VOIE,
  CODE_POSTAL_N        AS CODE_POSTAL,
  COMMUNE_N            AS COMMUNE,
  CODE_DEPARTEMENT_N   AS CODE_DEPARTEMENT,

  /* Libellé lisible basé sur les versions normalisées */
  CONCAT(
    COALESCE(NO_VOIE_N, ''), ' ',
    COALESCE(TYPE_DE_VOIE_N, ''), ' ',
    COALESCE(VOIE_N, ''), ' ',
    COALESCE(CODE_POSTAL_N, ''), ' ',
    COALESCE(COMMUNE_N, '')
  ) AS ADDRESS,

  CURRENT_TIMESTAMP() AS CREATED_AT
FROM clean
/* Déduplication fiable : mêmes champs, coalescés comme dans le hash */
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