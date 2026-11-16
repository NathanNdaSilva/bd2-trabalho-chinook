USE chinook;

-- Questão 3: Consultar chaves estrangeiras no catálogo
SELECT 
    tc.CONSTRAINT_NAME AS nome_fk,
    tc.TABLE_NAME AS tabela_origem,
    kcu.COLUMN_NAME AS coluna_origem,
    kcu.REFERENCED_TABLE_NAME AS tabela_destino,
    kcu.REFERENCED_COLUMN_NAME AS coluna_destino
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA 
   AND tc.TABLE_NAME = kcu.TABLE_NAME 
   AND tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
WHERE tc.CONSTRAINT_SCHEMA = 'chinook'
  AND tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
ORDER BY tc.TABLE_NAME, tc.CONSTRAINT_NAME;
