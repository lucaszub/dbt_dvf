with BASE as (
    SELECT 
        (TO_DATE(DATE_MUTATION, 'DD/MM/YYYY')) as DATE_MUTATION,
        NATURE_MUTATION,
        TO_NUMBER(REPLACE(VALEUR_FONCIERE, ',', '.')) AS VALEUR_FONCIERE,
        NO_VOIE,
        BTQ,
        TYPE_DE_VOIE,
        CODE_VOIE,
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
        NATURE_CULTURE,
        TO_NUMBER(REPLACE(SURFACE_TERRAIN, ',', '.')) AS SURFACE_TERRAIN
             
    FROM 
        {{ source('bronze', 'DVF_RAW_VARCHAR') }}
    WHERE 
        VALEUR_FONCIERE IS NOT NULL  
        AND NATURE_MUTATION IN ('Vente')
        AND TO_NUMBER(REPLACE(VALEUR_FONCIERE, ',', '.')) > 20000
)
SELECT 
    MD5(
        CONCAT(
            UPPER(TRIM(COALESCE(CODE_POSTAL, ''))), '|',
            UPPER(TRIM(COALESCE({{ remove_accents('COMMUNE') }}, ''))), '|',
            UPPER(TRIM(COALESCE(NO_VOIE, ''))), '|',
            UPPER(TRIM(COALESCE(VOIE, '')))
        )
    ) as join_key,
    * 
FROM BASE