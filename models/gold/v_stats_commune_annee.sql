select  
dc.code_departement,
dc.commune,
cp.code_postal,
TL.TYPE_LOCAL,
YEAR(fm.date_mutation) as annee,
COUNT(*) as nb_vente,
ROUND(MEDIAN(fm.valeur_fonciere), 2) AS valeur_mediane,
ROUND(MEDIAN(fm.valeur_fonciere / NULLIF(fm.surface_reelle_bati, 0)),2) AS prix_median_m2

from 

   {{ ref('fact_mutation') }} as FM   
JOIN 
   {{ ref('dim_commune') }} as dc 
ON 
    FM.COMMUNE_ID = DC.COMMUNE_ID
JOIN 
   {{ ref('dim_code_postal') }} as CP
ON 
    FM.CODE_POSTAL_ID = cp.CODE_POSTAL_ID
JOIN 
   {{ ref('dim_type_local') }} as TL
ON FM.TYPE_LOCAL_ID = TL.TYPE_LOCAL_ID
where TL.TYPE_LOCAL not in ('INCONNU')
    AND FM.VALEUR_FONCIERE > 5000
    AND FM.SURFACE_REELLE_BATI > 0
    AND FM.VALEUR_FONCIERE / FM.SURFACE_REELLE_BATI BETWEEN 50 AND 50000

group by cp.code_postal, dc.commune, dc.code_departement,  TL.TYPE_LOCAL, YEAR(fm.date_mutation)