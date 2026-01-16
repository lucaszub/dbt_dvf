

WITH clean AS (
  SELECT
    TRIM(CODE_POSTAL)                          AS CODE_POSTAL_N,
    UPPER(REGEXP_REPLACE(TRIM(COMMUNE), '\\s+', ' ')) AS COMMUNE_N,
    TRIM(CODE_DEPARTEMENT)                     AS CODE_DEPARTEMENT_N,
    UPPER(REGEXP_REPLACE(TRIM(VOIE), '\\s+', ' ')) AS VOIE_N
  FROM {{ ref('dvf_silver') }}
  WHERE CODE_POSTAL IS NOT NULL
)
SELECT
  /* Clé technique (texte hex) stable : CP + département */
  TO_CHAR(HASH(
    COALESCE(CODE_POSTAL_N, '') || '|' || COALESCE(CODE_DEPARTEMENT_N, '')
  ), 'XXXXXXXXXXXXXXXX') AS CODE_POSTAL_ID,

  CODE_POSTAL_N       AS CODE_POSTAL,
  COMMUNE_N           AS COMMUNE,           -- libellé principal associé
  CODE_DEPARTEMENT_N  AS CODE_DEPARTEMENT,
  VOIE_N              AS VOIE,

  /* (Optionnel) placeholders pour la carto si tu enrichis plus tard */
  /* LATITUDE FLOAT, LONGITUDE FLOAT, */

  CURRENT_TIMESTAMP() AS CREATED_AT
FROM clean
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY CODE_POSTAL_N, CODE_DEPARTEMENT_N
  ORDER BY COMMUNE_N
) = 1


