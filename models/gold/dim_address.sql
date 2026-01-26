 SELECT dvf.JOIN_KEY,
        CONCAT(NUMERO, ' ', NOM_AFNOR, ' ', dvf.CODE_POSTAL, ' ', {{ remove_accents('NOM_COMMUNE') }}) AS ADRESSE,
        NOM_AFNOR,
        {{ remove_accents('NOM_AFNOR') }}, 
        NUMERO,
        dvf.CODE_POSTAL,
        {{ remove_accents('NOM_COMMUNE') }} as NOM_COMMUNE,
        dvf.CODE_DEPARTEMENT,
        LATITUDE,
        LONGITUDE
    FROM {{ ref('ban_addresses') }} as ba
    left join {{ ref('dvf_silver') }} as dvf
    on ba.join_key = dvf.join_key