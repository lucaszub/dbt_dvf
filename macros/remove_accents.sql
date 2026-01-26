{% macro remove_accents(column_name) %}
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(
        {{ column_name }},
        'É', 'E'), 'È', 'E'), 'Ê', 'E'), 'Ë', 'E'),
        'À', 'A'), 'Â', 'A'), 'Ä', 'A'),
        'Ù', 'U'), 'Û', 'U'), 'Ü', 'U'),
        'Ô', 'O'), 'Ö', 'O'),
        'Î', 'I'), 'Ï', 'I')
{% endmacro %}