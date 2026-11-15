USE chinook;

-- Questão 1:
SELECT 
    s.TABLE_NAME AS tabela,
    s.INDEX_NAME AS nome_indice,
    CASE 
        WHEN s.INDEX_NAME = 'PRIMARY' THEN 'Chave Primária (PK)'
        WHEN k.REFERENCED_TABLE_NAME IS NOT NULL THEN 'Chave Estrangeira (FK)'
        ELSE 'Índice Secundário Comum'
    END AS papel_no_banco,
    GROUP_CONCAT(DISTINCT s.COLUMN_NAME ORDER BY s.SEQ_IN_INDEX SEPARATOR ', ') AS colunas_indexadas
FROM information_schema.statistics s
LEFT JOIN information_schema.key_column_usage k 
    ON s.TABLE_SCHEMA = k.TABLE_SCHEMA 
   AND s.TABLE_NAME = k.TABLE_NAME 
   AND s.COLUMN_NAME = k.COLUMN_NAME
   AND s.INDEX_NAME = k.CONSTRAINT_NAME
   AND k.REFERENCED_TABLE_NAME IS NOT NULL
WHERE s.TABLE_SCHEMA = 'chinook'
GROUP BY s.TABLE_NAME, s.INDEX_NAME, papel_no_banco
ORDER BY s.TABLE_NAME, s.INDEX_NAME;
