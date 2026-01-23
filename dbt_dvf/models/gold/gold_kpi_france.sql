-- Modèle gold_kpi_france.sql
-- KPIs agrégés au niveau France par année
-- Objectif : Fournir des données pré-agrégées pour la vue France de l'application Streamlit
-- Performance cible : < 5s chargement

WITH transactions AS (
  SELECT
    EXTRACT(YEAR FROM fm.DATE_MUTATION) AS ANNEE,
    fm.VALEUR_FONCIERE,
    fm.SURFACE_REELLE_BATI,
    dtl.TYPE_LOCAL
  FROM {{ ref('fct_mutation') }} fm
  LEFT JOIN {{ ref('dim_type_local') }} dtl
    ON fm.TYPE_LOCAL_ID = dtl.TYPE_LOCAL_ID
  WHERE fm.VALEUR_FONCIERE IS NOT NULL
    AND fm.SURFACE_REELLE_BATI IS NOT NULL
    AND fm.SURFACE_REELLE_BATI > 0
)

SELECT
  ANNEE,

  -- Métriques globales
  MEDIAN(VALEUR_FONCIERE / SURFACE_REELLE_BATI) AS PRIX_MEDIAN_M2,
  COUNT(*) AS NB_VENTES,

  -- Métriques par type de bien - Appartements
  MEDIAN(
    CASE WHEN TYPE_LOCAL = 'APPARTEMENT'
    THEN VALEUR_FONCIERE / SURFACE_REELLE_BATI END
  ) AS PRIX_MEDIAN_APPARTEMENT,

  SUM(CASE WHEN TYPE_LOCAL = 'APPARTEMENT' THEN 1 ELSE 0 END) AS NB_VENTES_APPARTEMENT,

  -- Métriques par type de bien - Maisons
  MEDIAN(
    CASE WHEN TYPE_LOCAL = 'MAISON'
    THEN VALEUR_FONCIERE / SURFACE_REELLE_BATI END
  ) AS PRIX_MEDIAN_MAISON,

  SUM(CASE WHEN TYPE_LOCAL = 'MAISON' THEN 1 ELSE 0 END) AS NB_VENTES_MAISON

FROM transactions
GROUP BY ANNEE
ORDER BY ANNEE
