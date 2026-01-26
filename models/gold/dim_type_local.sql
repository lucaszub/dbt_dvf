-- Option 1 : Avec sous-requête (recommandé)
SELECT 
    ROW_NUMBER() OVER (ORDER BY TYPE_LOCAL) AS type_local_sk,
    TYPE_LOCAL
FROM (
    SELECT DISTINCT TYPE_LOCAL 
    FROM {{ ref('dvf_silver') }}
    WHERE TYPE_LOCAL IS NOT NULL
)