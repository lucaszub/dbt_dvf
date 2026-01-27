SELECT
    DVF.join_key,
    DVF.DATE_MUTATION,
    --BA.ADRESSE as ADRESSE_BAN,
    DTL.type_local_sk,
    dvf.nombre_pieces_principales,
    dvf.surface_terrain,
    DVF.VALEUR_FONCIERE,
    
    BA.LATITUDE,
    BA.LONGITUDE
FROM 
  {{ ref('dvf_silver') }} AS DVF
LEFT JOIN {{ ref('ban_addresses') }} AS BA
    ON DVF.join_key = BA.join_key
LEFT JOIN {{ ref('dim_type_local') }} AS DTL
    ON DVF.TYPE_LOCAL = DTL.TYPE_LOCAL
