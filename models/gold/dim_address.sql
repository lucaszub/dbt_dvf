SELECT 
    ba.join_key,
    CONCAT(ba.NUMERO, ' ', ba.NOM_AFNOR, ' ', ba.CODE_POSTAL, ' ', {{ remove_accents('ba.NOM_COMMUNE') }}) AS ADRESSE,
    {{ remove_accents('ba.NOM_AFNOR') }} AS NOM_AFNOR,
    ba.NUMERO,
    ba.CODE_DEPARTEMENT,
    ba.CODE_POSTAL,
    {{ remove_accents('ba.NOM_COMMUNE') }} AS NOM_COMMUNE,
    ba.LATITUDE,
    ba.LONGITUDE
FROM {{ ref('ban_addresses') }} AS ba