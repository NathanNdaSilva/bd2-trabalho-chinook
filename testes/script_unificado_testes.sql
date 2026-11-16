-- ============================================================================
-- TAREFA 10: SCRIPT UNIFICADO DE TESTES E DOCUMENTAÇÃO
-- SGBD: MySQL
-- Banco de Dados: Chinook
-- Descrição: Este script executa cenários de sucesso e falha (erros esperados)
-- para validar as regras semânticas, gatilhos (triggers), stored procedures e 
-- o validador de Diagrama de Transição de Estados (DTE) desenvolvidos.
-- ============================================================================

USE chinook;

-- ----------------------------------------------------------------------------
-- PREPARAÇÃO (SETUP)
-- Garantir que a base está limpa de dados de testes anteriores
-- ----------------------------------------------------------------------------
DELETE FROM InvoiceLine WHERE InvoiceId IN (9998, 9999);
DELETE FROM Invoice WHERE InvoiceId IN (9998, 9999);
DELETE FROM Customer WHERE CustomerId = 9999;


-- ============================================================================
-- PARTE 1 - TESTES
-- ============================================================================

SELECT 'INICIANDO TESTES DA PARTE 1' AS Status_Execucao;

-- TESTE: Tarefa 2 - sp_remover_indices
-- Vamos criar uma tabela temporária com índices para testar a remoção dinâmica
CREATE TABLE teste_remocao_indices (
    id INT PRIMARY KEY,
    nome VARCHAR(50),
    email VARCHAR(50),
    INDEX idx_nome (nome),
    UNIQUE INDEX uk_email (email)
);

SELECT 'Antes da remoção:' AS sp_remover_indices, INDEX_NAME 
FROM information_schema.STATISTICS 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'teste_remocao_indices';

CALL sp_remover_indices('teste_remocao_indices');

SELECT 'Depois da remoção (deve retornar vazio se não for PK):' AS sp_remover_indices, INDEX_NAME 
FROM information_schema.STATISTICS 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'teste_remocao_indices' AND INDEX_NAME != 'PRIMARY';

DROP TABLE teste_remocao_indices;


-- TESTE: Tarefa 5 - Validador DTE (Invoice.Status)
-- ----------------------------------------------------------------------------
SELECT 'Testando DTE (Invoice.Status)...' AS Status_Execucao;

-- 1. Sucesso: Inserção de fatura com estado inicial válido ('ABERTA')
INSERT INTO Invoice (InvoiceId, CustomerId, InvoiceDate, BillingAddress, Total, Status)
VALUES (9999, 1, NOW(), 'Rua Teste DTE', 10.00, 'ABERTA');

-- 2. Sucesso: Transição ABERTA -> PAGA
UPDATE Invoice SET Status = 'PAGA' WHERE InvoiceId = 9999;

-- 3. Sucesso: Transição PAGA -> ESTORNADA
UPDATE Invoice SET Status = 'ESTORNADA' WHERE InvoiceId = 9999;

-- 4. Erro Esperado: Transição proibida ESTORNADA -> ABERTA
-- Descomente a linha abaixo para ver a exceção SQL:
-- UPDATE Invoice SET Status = 'ABERTA' WHERE InvoiceId = 9999;


-- ============================================================================
-- PARTE 2 - TESTES
-- ============================================================================

SELECT 'INICIANDO TESTES DA PARTE 2' AS Status_Execucao;

-- TESTE: Tarefas 7 e 8 - Regras Semânticas 1 (Triggers e Procedures)
-- Regra 1: Somente 'Sales Support Agent' pode ser representante de suporte.
-- Obs: EmployeeId = 3 (Jane Peacock) é Sales Support Agent. EmployeeId = 1 (Andrew Adams) é General Manager.
-- ----------------------------------------------------------------------------
SELECT 'Testando Regra Semântica 1 (Customer/Employee)...' AS Status_Execucao;

-- 1. Erro Esperado: Inserir cliente com funcionário que NÃO é 'Sales Support Agent' (via Trigger)
-- Descomente a linha abaixo para ver a exceção SQL:
-- INSERT INTO Customer (CustomerId, FirstName, LastName, Email, SupportRepId) 
-- VALUES (9999, 'Teste', 'Falha', 'teste@falha.com', 1);

-- 2. Sucesso: Inserir cliente com funcionário correto ('Sales Support Agent')
INSERT INTO Customer (CustomerId, FirstName, LastName, Email, SupportRepId) 
VALUES (9999, 'Teste', 'Sucesso', 'teste@sucesso.com', 3);

-- 3. Erro Esperado: Atualizar cliente para representante inválido via Procedure (sp_definir_representante_suporte)
-- Descomente a linha abaixo para ver a exceção SQL:
-- CALL sp_definir_representante_suporte(9999, 1);

-- 4. Sucesso: Atualizar cliente via Procedure para representante válido
CALL sp_definir_representante_suporte(9999, 4); -- Margaret Park é Sales Support Agent


-- TESTE: Tarefas 7 e 8 - Regras Semânticas 2 (Triggers e Procedures)
-- Regra 2: O preço unitário na fatura não pode ser menor que o do catálogo.
-- Obs: TrackId = 1 tem UnitPrice = 0.99 no catálogo da Chinook.
-- ----------------------------------------------------------------------------
SELECT 'Testando Regra Semântica 2 (InvoiceLine/Track)...' AS Status_Execucao;

-- Criamos uma nova fatura (InvoiceId = 9998) para os testes de itens
INSERT INTO Invoice (InvoiceId, CustomerId, InvoiceDate, BillingAddress, Total, Status)
VALUES (9998, 1, NOW(), 'Rua Teste Regras', 0.00, 'ABERTA');

-- 1. Erro Esperado: Inserir item com valor menor que o catálogo (via Trigger / Procedure)
-- Descomente a linha abaixo para ver a exceção SQL:
-- CALL sp_inserir_item_fatura(9998, 1, 0.50, 1); 

-- 2. Sucesso: Inserir item com valor igual ou superior ao catálogo
CALL sp_inserir_item_fatura(9998, 1, 0.99, 2);


-- TESTE: Tarefa 9 - Integridade da Coluna Redundante Total
-- A fatura 9998 recebeu 2 itens de 0.99 através da procedure acima.
-- Vamos verificar se a trigger AFTER INSERT ou a própria procedure atualizaram o Invoice.Total
-- ----------------------------------------------------------------------------
SELECT 'Testando Sincronização do Invoice.Total...' AS Status_Execucao;

SELECT InvoiceId, Total AS Total_Calculado_Esperado_1_98 
FROM Invoice WHERE InvoiceId = 9998;

-- 1. Sucesso: Inserção direta acionando Trigger AFTER INSERT
-- TrackId 2 custa 0.99. Vamos cobrar 1.99.
INSERT INTO InvoiceLine (InvoiceLineId, InvoiceId, TrackId, UnitPrice, Quantity)
VALUES (99999, 9998, 2, 1.99, 1);

SELECT InvoiceId, Total AS Total_Apos_Insert_Esperado_3_97 
FROM Invoice WHERE InvoiceId = 9998;

-- 2. Sucesso: Atualização de quantidade acionando Trigger AFTER UPDATE
UPDATE InvoiceLine SET Quantity = 2 WHERE InvoiceLineId = 99999;

SELECT InvoiceId, Total AS Total_Apos_Update_Esperado_5_96 
FROM Invoice WHERE InvoiceId = 9998;

-- 3. Erro Esperado: Tentativa de quebrar a integridade mudando o Total diretamente
-- Descomente a linha abaixo para ver a exceção SQL (bloqueio pela trigger trg_invoice_total_bu):
-- UPDATE Invoice SET Total = 999.99 WHERE InvoiceId = 9998;


-- ============================================================================
-- LIMPEZA FINAL (TEARDOWN)
-- Retornando a base de dados ao estado original
-- ============================================================================
SELECT 'LIMPANDO DADOS DE TESTE...' AS Status_Execucao;

DELETE FROM InvoiceLine WHERE InvoiceId IN (9998, 9999);
DELETE FROM Invoice WHERE InvoiceId IN (9998, 9999);
DELETE FROM Customer WHERE CustomerId = 9999;

SELECT 'TODOS OS TESTES CONCLUÍDOS COM SUCESSO!' AS Status_Final;
