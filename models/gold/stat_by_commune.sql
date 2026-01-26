WITH DVF_SILVER_ID AS (
    SELECT
        MD5(
            CONCAT(
                UPPER(TRIM(COALESCE(CODE_POSTAL, ''))), '|',
                UPPER(TRIM(COALESCE(REMOVE_ACCENTS(COMMUNE), ''))), '|',
                UPPER(TRIM(COALESCE(NO_VOIE, ''))), '|',
                UPPER(TRIM(COALESCE(VOIE, '')))
            )
        ) as ID,
        DATE_MUTATION,
        CONCAT(NO_VOIE, ' ', TYPE_DE_VOIE, ' ', VOIE, ' ', CODE_POSTAL, ' ', COMMUNE) AS ADRESSE,
        VALEUR_FONCIERE,
        TYPE_LOCAL,
        NO_VOIE,
        SURFACE_REELLE_BATI,
        nombre_pieces_principales,
        surface_terrain,
        TYPE_DE_VOIE,
        VOIE,
        CODE_POSTAL,
        COMMUNE,
        CODE_DEPARTEMENT
    FROM DVF_SILVER 
    --WHERE CODE_POSTAL = '44400'
    WHERE TYPE_LOCAL IS NOT NULL
),
BAN_ADDRESSES_ID AS (
    SELECT 
        MD5(
            CONCAT(
                UPPER(TRIM(COALESCE(CODE_POSTAL, ''))), '|',
                UPPER(TRIM(COALESCE(REMOVE_ACCENTS(NOM_COMMUNE), ''))), '|',
                UPPER(TRIM(COALESCE(NUMERO, ''))), '|',
                UPPER(TRIM(COALESCE(REGEXP_REPLACE(NOM_AFNOR, '^[^ ]+ ', ''), '')))
            )
        ) as ID,
        CONCAT(NUMERO, ' ', NOM_AFNOR, ' ', CODE_POSTAL, ' ', REMOVE_ACCENTS(NOM_COMMUNE)) AS ADRESSE,
        NOM_AFNOR,
        NUMERO,
        CODE_DEPARTEMENT,
        CODE_POSTAL,
        REMOVE_ACCENTS(NOM_COMMUNE) as NOM_COMMUNE,
        LATITUDE,
        LONGITUDE
    FROM BAN_ADDRESSES 
    --WHERE CODE_POSTAL = '44400'
),
df_join as (
SELECT
    DVF.ID,
    BA.ADRESSE as ADRESSE_BAN,
    DVF.TYPE_LOCAL,
    BA.CODE_DEPARTEMENT,
    dvf.nombre_pieces_principales,
    dvf.surface_terrain,
    DVF.VALEUR_FONCIERE,
    DVF.DATE_MUTATION,
    BA.LATITUDE,
    BA.LONGITUDE
FROM DVF_SILVER_ID AS DVF
LEFT JOIN BAN_ADDRESSES_ID AS BA
    ON DVF.ID = BA.ID
)
select 
    YEAR(DATE_MUTATION) AS ANNEE,    
    CODE_DEPARTEMENT,
    COUNT(*) as nb_vente,
    MEDIAN(VALEUR_FONCIERE)
    
from df_join 
group by annee, CODE_DEPARTEMENT