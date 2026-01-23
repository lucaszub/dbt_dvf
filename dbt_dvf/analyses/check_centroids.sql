-- Analyse des centroids communes avec beaucoup de ventes
SELECT 
    CODE_COMMUNE, 
    NOM_COMMUNE, 
    NB_VENTES, 
    LATITUDE_CENTROID, 
    LONGITUDE_CENTROID
FROM {{ ref('gold_kpi_commune') }}
WHERE (LATITUDE_CENTROID = 0 OR LONGITUDE_CENTROID = 0)
  AND NB_VENTES > 100
ORDER BY NB_VENTES DESC
LIMIT 20
