-- ============================================================================
-- PARTE 1 - ITEM 5: Validador Genérico de Diagrama de Transição de Estados (DTE)
-- SGBD: MySQL
-- ============================================================================

-- 1. LIMPEZA DE OBJETOS ANTERIORES (IDEMPOTÊNCIA)
DROP TRIGGER IF EXISTS trg_invoice_dte_bi;
DROP TRIGGER IF EXISTS trg_invoice_dte_bu;
DROP PROCEDURE IF EXISTS sp_validar_dte;
DROP TABLE IF EXISTS dte_transicoes;
DROP TABLE IF EXISTS dte_estados;

-- ============================================================================
-- 2. ESTRUTURA GENÉRICA DE METADADOS DO DTE (REUTILIZÁVEL PARA QUALQUER TABELA)
-- ============================================================================

CREATE TABLE dte_estados (
    tabela       VARCHAR(64) NOT NULL,
    coluna       VARCHAR(64) NOT NULL,
    estado       VARCHAR(50) NOT NULL,
    eh_inicial   TINYINT(1)  NOT NULL DEFAULT 0,
    eh_final     TINYINT(1)  NOT NULL DEFAULT 0,
    PRIMARY KEY (tabela, coluna, estado)
);

CREATE TABLE dte_transicoes (
    tabela          VARCHAR(64) NOT NULL,
    coluna          VARCHAR(64) NOT NULL,
    estado_origem   VARCHAR(50) NOT NULL,
    estado_destino  VARCHAR(50) NOT NULL,
    PRIMARY KEY (tabela, coluna, estado_origem, estado_destino),
    CONSTRAINT fk_dte_origem FOREIGN KEY (tabela, coluna, estado_origem)
        REFERENCES dte_estados (tabela, coluna, estado),
    CONSTRAINT fk_dte_destino FOREIGN KEY (tabela, coluna, estado_destino)
        REFERENCES dte_estados (tabela, coluna, estado)
);

-- ============================================================================
-- 3. MOTOR DE VALIDAÇÃO GENÉRICO (STORED PROCEDURE)
-- ============================================================================

DELIMITER $$

CREATE PROCEDURE sp_validar_dte(
    IN p_tabela       VARCHAR(64),
    IN p_coluna       VARCHAR(64),
    IN p_estado_atual VARCHAR(50),
    IN p_novo_estado  VARCHAR(50),
    IN p_operacao     VARCHAR(10) -- 'INSERT' ou 'UPDATE'
)
BEGIN
    DECLARE v_existe_estado INT DEFAULT 0;
    DECLARE v_eh_inicial    TINYINT(1) DEFAULT 0;
    DECLARE v_transicao_ok  INT DEFAULT 0;
    DECLARE v_msg_erro      VARCHAR(255);

    -- 3.1. Verifica se o novo estado é um valor válido cadastrado no DTE
    SELECT COUNT(*), COALESCE(MAX(eh_inicial), 0)
      INTO v_existe_estado, v_eh_inicial
      FROM dte_estados
     WHERE tabela = p_tabela
       AND coluna = p_coluna
       AND estado = p_novo_estado;

    IF v_existe_estado = 0 THEN
        SET v_msg_erro = CONCAT(
            'Erro DTE [', p_tabela, '.', p_coluna, ']: O estado "',
            COALESCE(p_novo_estado, 'NULL'), '" não pertence ao diagrama.'
        );
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg_erro;
    END IF;

    -- 3.2. Validação para operação de INSERT (deve ser um estado inicial)
    IF p_operacao = 'INSERT' THEN
        IF v_eh_inicial = 0 THEN
            SET v_msg_erro = CONCAT(
                'Erro DTE [', p_tabela, '.', p_coluna, ']: O estado "',
                p_novo_estado, '" não é um estado inicial válido para inserção.'
            );
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg_erro;
        END IF;
    END IF;

    -- 3.3. Validação para operação de UPDATE
    IF p_operacao = 'UPDATE' THEN
        -- Só valida transição se houve mudança efetiva de estado
        IF p_estado_atual <> p_novo_estado THEN
            SELECT COUNT(*)
              INTO v_transicao_ok
              FROM dte_transicoes
             WHERE tabela         = p_tabela
               AND coluna         = p_coluna
               AND estado_origem  = p_estado_atual
               AND estado_destino = p_novo_estado;

            IF v_transicao_ok = 0 THEN
                SET v_msg_erro = CONCAT(
                    'Erro DTE [', p_tabela, '.', p_coluna, ']: Transição proibida de "',
                    p_estado_atual, '" para "', p_novo_estado, '".'
                );
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg_erro;
            END IF;
        END IF;
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- 4. APLICAÇÃO PRÁTICA NO ESQUEMA CHINOOK (TABELA Invoice)
-- ============================================================================
-- Adiciona coluna Status na tabela Invoice com default 'ABERTA' para não 
-- quebrar os scripts dos demais integrantes do grupo.

SET @col_exists = (
    SELECT COUNT(*)
      FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME   = 'Invoice'
       AND COLUMN_NAME  = 'Status'
);

SET @sql_alter = IF(
    @col_exists = 0,
    'ALTER TABLE Invoice ADD COLUMN Status VARCHAR(50) NOT NULL DEFAULT ''ABERTA''',
    'SELECT 1'
);
PREPARE stmt FROM @sql_alter;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Cadastro dos Estados do ciclo de vida de uma Fatura (Invoice.Status)
-- Diagrama:
--   [ABERTA] ---> [PAGA] ---> [ESTORNADA]
--      |
--      +--------> [CANCELADA]
INSERT INTO dte_estados (tabela, coluna, estado, eh_inicial, eh_final) VALUES
    ('Invoice', 'Status', 'ABERTA',    1, 0),
    ('Invoice', 'Status', 'PAGA',      0, 0),
    ('Invoice', 'Status', 'CANCELADA', 0, 1),
    ('Invoice', 'Status', 'ESTORNADA', 0, 1);

-- Cadastro das Transições Permitidas
INSERT INTO dte_transicoes (tabela, coluna, estado_origem, estado_destino) VALUES
    ('Invoice', 'Status', 'ABERTA', 'PAGA'),
    ('Invoice', 'Status', 'ABERTA', 'CANCELADA'),
    ('Invoice', 'Status', 'PAGA',   'ESTORNADA');

-- Triggers que acoplam a tabela Invoice ao motor genérico sp_validar_dte
DELIMITER $$

CREATE TRIGGER trg_invoice_dte_bi
BEFORE INSERT ON Invoice
FOR EACH ROW
BEGIN
    CALL sp_validar_dte('Invoice', 'Status', NULL, NEW.Status, 'INSERT');
END$$

CREATE TRIGGER trg_invoice_dte_bu
BEFORE UPDATE ON Invoice
FOR EACH ROW
BEGIN
    CALL sp_validar_dte('Invoice', 'Status', OLD.Status, NEW.Status, 'UPDATE');
END$$

DELIMITER ;

-- ============================================================================
-- 5. CENÁRIO DE TESTE DEMONSTRATIVO
-- ============================================================================
-- Nota: Execute bloco a bloco ou observe os erros esperados nas linhas comentadas.

-- [TESTE 1 - SUCESSO] Inserção com estado inicial válido ('ABERTA')
INSERT INTO Invoice (InvoiceId, CustomerId, InvoiceDate, Total, Status)
VALUES (9999, 1, NOW(), 10.00, 'ABERTA');

-- [TESTE 2 - SUCESSO] Transição válida: ABERTA -> PAGA
UPDATE Invoice SET Status = 'PAGA' WHERE InvoiceId = 9999;

-- [TESTE 3 - SUCESSO] Transição válida: PAGA -> ESTORNADA
UPDATE Invoice SET Status = 'ESTORNADA' WHERE InvoiceId = 9999;

-- [TESTE 4 - FALHA ESPERADA] Transição inválida: ESTORNADA -> ABERTA (estado final não retrocede)
-- Descomente a linha abaixo para verificar o bloqueio do SGBD:
-- UPDATE Invoice SET Status = 'ABERTA' WHERE InvoiceId = 9999;
-- Resultado esperado: Error Code: 1644. Erro DTE [Invoice.Status]: Transição proibida de "ESTORNADA" para "ABERTA".

-- [TESTE 5 - FALHA ESPERADA] Inserção começando em estado não-inicial ('PAGA')
-- Descomente a linha abaixo para verificar o bloqueio do SGBD:
-- INSERT INTO Invoice (InvoiceId, CustomerId, InvoiceDate, Total, Status) VALUES (9998, 1, NOW(), 15.00, 'PAGA');
-- Resultado esperado: Error Code: 1644. Erro DTE [Invoice.Status]: O estado "PAGA" não é um estado inicial válido para inserção.

-- [TESTE 6 - FALHA ESPERADA] Inserção com estado inexistente no DTE ('AGUARDANDO')
-- Descomente a linha abaixo para verificar o bloqueio do SGBD:
-- INSERT INTO Invoice (InvoiceId, CustomerId, InvoiceDate, Total, Status) VALUES (9997, 1, NOW(), 15.00, 'AGUARDANDO');
-- Resultado esperado: Error Code: 1644. Erro DTE [Invoice.Status]: O estado "AGUARDANDO" não pertence ao diagrama.

-- Limpeza do registro de teste (opcional, para manter a base limpa)
DELETE FROM Invoice WHERE InvoiceId = 9999;
