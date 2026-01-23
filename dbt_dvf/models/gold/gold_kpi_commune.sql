-- Modèle gold_kpi_commune.sql
-- KPIs agrégés par commune et année
-- Story 1.3: Modèles agrégés niveau Commune et Code Postal
-- Objectif : Fournir des données pré-agrégées pour le drill-down commune de l'application Streamlit
-- Performance cible : < 2 minutes exécution

{{
  config(
    materialized='table'
  )
}}

WITH transactions AS (
  SELECT
    -- Utiliser CODE_INSEE comme CODE_COMMUNE (code INSEE de la commune)
    dae.CODE_INSEE AS CODE_COMMUNE,
    dc.COMMUNE AS NOM_COMMUNE,
    dc.CODE_DEPARTEMENT,
    EXTRACT(YEAR FROM fm.DATE_MUTATION) AS ANNEE,
    fm.VALEUR_FONCIERE,
    fm.SURFACE_REELLE_BATI,
    fm.LATITUDE,
    fm.LONGITUDE,
    dtl.TYPE_LOCAL
  FROM {{ ref('fct_mutation') }} fm
  LEFT JOIN {{ ref('dim_address_enriched') }} dae
    ON fm.ADDRESS_ID = dae.ADDRESS_ID
  LEFT JOIN {{ ref('dim_commune') }} dc
    ON fm.COMMUNE_ID = dc.COMMUNE_ID
  LEFT JOIN {{ ref('dim_type_local') }} dtl
    ON fm.TYPE_LOCAL_ID = dtl.TYPE_LOCAL_ID
  WHERE fm.VALEUR_FONCIERE IS NOT NULL
    AND fm.SURFACE_REELLE_BATI IS NOT NULL
    AND fm.SURFACE_REELLE_BATI > 0
    AND dae.CODE_INSEE IS NOT NULL
)

SELECT
  CODE_COMMUNE,
  NOM_COMMUNE,
  CODE_DEPARTEMENT,
  ANNEE,

  -- Métriques globales
  MEDIAN(VALEUR_FONCIERE / NULLIF(SURFACE_REELLE_BATI, 0)) AS PRIX_MEDIAN_M2,
  COUNT(*) AS NB_VENTES,

  -- Métriques par type de bien - Appartements
  MEDIAN(
    CASE WHEN TYPE_LOCAL = 'APPARTEMENT'
    THEN VALEUR_FONCIERE / NULLIF(SURFACE_REELLE_BATI, 0) END
  ) AS PRIX_MEDIAN_APPARTEMENT,

  -- Métriques par type de bien - Maisons
  MEDIAN(
    CASE WHEN TYPE_LOCAL = 'MAISON'
    THEN VALEUR_FONCIERE / NULLIF(SURFACE_REELLE_BATI, 0) END
  ) AS PRIX_MEDIAN_MAISON,

  -- Centroids géographiques (avec COALESCE pour éviter NULL)
  COALESCE(AVG(LATITUDE), 0) AS LATITUDE_CENTROID,
  COALESCE(AVG(LONGITUDE), 0) AS LONGITUDE_CENTROID,

  -- Seuil de données suffisantes (FR15: minimum 5 transactions)
  CASE WHEN COUNT(*) >= 5 THEN TRUE ELSE FALSE END AS HAS_SUFFICIENT_DATA

FROM transactions
WHERE CODE_COMMUNE IS NOT NULL
GROUP BY CODE_COMMUNE, NOM_COMMUNE, CODE_DEPARTEMENT, ANNEE
ORDER BY CODE_DEPARTEMENT, CODE_COMMUNE, ANNEE
