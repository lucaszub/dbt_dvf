{% test prix_median_positif(model, column_name) %}
  -- Test custom : vérifie que le prix médian est strictement positif
  -- Retourne les lignes en erreur (prix médian <= 0 ou NULL)
  SELECT *
  FROM {{ model }}
  WHERE {{ column_name }} IS NOT NULL
    AND {{ column_name }} <= 0
{% endtest %}
