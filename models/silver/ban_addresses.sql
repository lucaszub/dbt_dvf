
with base as (

SELECT
    -- Identifiants
    TRIM("id") AS ID,
    TRIM("id_fantoir") AS ID_FANTOIR,
    
    -- Adresse
    TRIM("numero") AS NUMERO,
    UPPER(TRIM("rep")) AS REPETITION,
    UPPER(REGEXP_REPLACE(TRIM("nom_voie"), '\\s+', ' ')) AS NOM_VOIE,
    TRIM("code_postal") AS CODE_POSTAL,
    
    -- Commune
    TRIM("code_insee") AS CODE_INSEE,
    UPPER(REGEXP_REPLACE(TRIM("nom_commune"), '\\s+', ' ')) AS NOM_COMMUNE,
    TRIM("code_insee_ancienne_commune") AS CODE_INSEE_ANCIENNE_COMMUNE,
    UPPER(REGEXP_REPLACE(TRIM(NULLIF("nom_ancienne_commune", '')), '\\s+', ' ')) AS NOM_ANCIENNE_COMMUNE,
    
    -- Coordonnées Lambert 93
    TRY_TO_NUMBER(REPLACE("x", ',', '.')) AS X_LAMBERT93,
    TRY_TO_NUMBER(REPLACE("y", ',', '.')) AS Y_LAMBERT93,
    
    -- Coordonnées GPS (WGS84)
    TRY_TO_NUMBER(REPLACE("lon", ',', '.')) AS LONGITUDE,
    TRY_TO_NUMBER(REPLACE("lat", ',', '.')) AS LATITUDE,
    
    -- Positionnement
    UPPER(TRIM("type_position")) AS TYPE_POSITION,
    "alias" AS ALIAS,
    
    -- Lieu-dit
    UPPER(REGEXP_REPLACE(TRIM(NULLIF("nom_ld", '')), '\\s+', ' ')) AS NOM_LIEU_DIT,
    
    -- Normalisation
    UPPER(REGEXP_REPLACE(TRIM("libelle_acheminement"), '\\s+', ' ')) AS LIBELLE_ACHEMINEMENT,
    UPPER(REGEXP_REPLACE(TRIM("nom_afnor"), '\\s+', ' ')) AS NOM_AFNOR,
    
    -- Métadonnées
    UPPER(TRIM("source_position")) AS SOURCE_POSITION,
    UPPER(TRIM("source_nom_voie")) AS SOURCE_NOM_VOIE,
    TRIM("certification_commune") AS CERTIFICATION_COMMUNE,
    
    -- Cadastre
    TRIM("cad_parcelles") AS PARCELLES_CADASTRALES,
    
    -- Département
    TRIM("departement") AS CODE_DEPARTEMENT,
    
    -- Audit
    CURRENT_TIMESTAMP() AS CREATED_AT

FROM {{ source('bronze', 'BAN_ADRESSES') }}
WHERE "id" IS NOT NULL
  AND "code_postal" IS NOT NULL
  AND "code_insee" IS NOT NULL
)
SELECT
   MD5(
        CONCAT(
            UPPER(TRIM(COALESCE(CODE_POSTAL, ''))), '|',
            UPPER(TRIM(COALESCE({{ remove_accents('NOM_COMMUNE') }}, ''))), '|',
            UPPER(TRIM(COALESCE(NUMERO, ''))), '|',
            UPPER(TRIM(COALESCE(REGEXP_REPLACE(NOM_AFNOR, '^[^ ]+ ', ''), '')))
        )
        ) as join_key,
    * from BASE