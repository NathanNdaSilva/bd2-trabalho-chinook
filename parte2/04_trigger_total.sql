-- ============================================================================
-- PARTE 2 - ITEM 4: Integridade da Coluna Redundante Total (Invoice vs InvoiceLine)
-- SGBD: MySQL
-- ============================================================================

-- 1. LIMPEZA DE OBJETOS ANTERIORES (IDEMPOTÊNCIA)
DROP TRIGGER IF EXISTS trg_invoice_total_bi;
DROP TRIGGER IF EXISTS trg_invoice_total_bu;
DROP TRIGGER IF EXISTS trg_invoiceline_total_ai;
DROP TRIGGER IF EXISTS trg_invoiceline_total_au;
DROP TRIGGER IF EXISTS trg_invoiceline_total_ad;
DROP PROCEDURE IF EXISTS sp_recalcular_total_invoice;
DROP PROCEDURE IF EXISTS sp_adicionar_item_e_atualizar_total;

-- ============================================================================
-- 2. CASO 1: IMPLEMENTAÇÃO VIA STORED PROCEDURES
-- ============================================================================

DELIMITER $$

-- 2.1. Procedure utilitária para recalcular o Total de uma fatura específica
CREATE PROCEDURE sp_recalcular_total_invoice(IN p_invoice_id INT)
BEGIN
    DECLARE v_novo_total DECIMAL(10, 2);

    SELECT COALESCE(SUM(UnitPrice * Quantity), 0.00)
      INTO v_novo_total
      FROM InvoiceLine
     WHERE InvoiceId = p_invoice_id;

    UPDATE Invoice
       SET Total = v_novo_total
     WHERE InvoiceId = p_invoice_id;
END$$

-- 2.2. Procedure transacional que insere um item na fatura e garante a 
--      consistência imediata do campo Total na tabela Invoice
CREATE PROCEDURE sp_adicionar_item_e_atualizar_total(
    IN p_invoice_id INT,
    IN p_track_id   INT,
    IN p_unit_price DECIMAL(10, 2),
    IN p_quantity   INT
)
BEGIN
    DECLARE v_proximo_id INT;
    DECLARE v_novo_total DECIMAL(10, 2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM Invoice WHERE InvoiceId = p_invoice_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Erro: Fatura (InvoiceId) não encontrada.';
    END IF;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Erro: A quantidade do item deve ser maior que zero.';
    END IF;

    IF p_unit_price IS NULL OR p_unit_price < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Erro: O preço unitário não pode ser negativo.';
    END IF;

    START TRANSACTION;

    SELECT COALESCE(MAX(InvoiceLineId), 0) + 1
      INTO v_proximo_id
      FROM InvoiceLine;

    INSERT INTO InvoiceLine (InvoiceLineId, InvoiceId, TrackId, UnitPrice, Quantity)
    VALUES (v_proximo_id, p_invoice_id, p_track_id, p_unit_price, p_quantity);

    -- Recalcula e atualiza explicitamente o Total da fatura
    SELECT COALESCE(SUM(UnitPrice * Quantity), 0.00)
      INTO v_novo_total
      FROM InvoiceLine
     WHERE InvoiceId = p_invoice_id;

    UPDATE Invoice
       SET Total = v_novo_total
     WHERE InvoiceId = p_invoice_id;

    COMMIT;
END$$

DELIMITER ;

-- ============================================================================
-- 3. CASO 2: IMPLEMENTAÇÃO VIA TRIGGERS (MANUTENÇÃO AUTOMÁTICA)
-- ============================================================================

DELIMITER $$

-- 3.1. Toda fatura recém-criada nasce obrigatoriamente com Total = 0.00 (sem itens)
CREATE TRIGGER trg_invoice_total_bi
BEFORE INSERT ON Invoice
FOR EACH ROW
BEGIN
    SET NEW.Total = 0.00;
END$$

-- 3.2. Impede atualização manual inconsistente diretamente na coluna Invoice.Total
CREATE TRIGGER trg_invoice_total_bu
BEFORE UPDATE ON Invoice
FOR EACH ROW
BEGIN
    DECLARE v_soma_real DECIMAL(10, 2);

    IF NEW.Total <> OLD.Total THEN
        SELECT COALESCE(SUM(UnitPrice * Quantity), 0.00)
          INTO v_soma_real
          FROM InvoiceLine
         WHERE InvoiceId = NEW.InvoiceId;

        IF NEW.Total <> v_soma_real THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Violação de Integridade: O campo Total de Invoice deve corresponder à soma de (UnitPrice * Quantity) em InvoiceLine.';
        END IF;
    END IF;
END$$

-- 3.3. Recalcula Invoice.Total após INSERT em InvoiceLine
CREATE TRIGGER trg_invoiceline_total_ai
AFTER INSERT ON InvoiceLine
FOR EACH ROW
BEGIN
    UPDATE Invoice
       SET Total = (
           SELECT COALESCE(SUM(UnitPrice * Quantity), 0.00)
             FROM InvoiceLine
            WHERE InvoiceId = NEW.InvoiceId
       )
     WHERE InvoiceId = NEW.InvoiceId;
END$$

-- 3.4. Recalcula Invoice.Total após UPDATE em InvoiceLine
--      (trata alteração de preço, quantidade ou transferência de item entre faturas)
CREATE TRIGGER trg_invoiceline_total_au
AFTER UPDATE ON InvoiceLine
FOR EACH ROW
BEGIN
    IF OLD.InvoiceId <> NEW.InvoiceId THEN
        UPDATE Invoice
           SET Total = (
               SELECT COALESCE(SUM(UnitPrice * Quantity), 0.00)
                 FROM InvoiceLine
                WHERE InvoiceId = OLD.InvoiceId
           )
         WHERE InvoiceId = OLD.InvoiceId;
    END IF;

    UPDATE Invoice
       SET Total = (
           SELECT COALESCE(SUM(UnitPrice * Quantity), 0.00)
             FROM InvoiceLine
            WHERE InvoiceId = NEW.InvoiceId
       )
     WHERE InvoiceId = NEW.InvoiceId;
END$$

-- 3.5. Recalcula Invoice.Total após DELETE em InvoiceLine
CREATE TRIGGER trg_invoiceline_total_ad
AFTER DELETE ON InvoiceLine
FOR EACH ROW
BEGIN
    UPDATE Invoice
       SET Total = (
           SELECT COALESCE(SUM(UnitPrice * Quantity), 0.00)
             FROM InvoiceLine
            WHERE InvoiceId = OLD.InvoiceId
       )
     WHERE InvoiceId = OLD.InvoiceId;
END$$

DELIMITER ;

-- ============================================================================
-- 4. CENÁRIOS DE TESTE DEMONSTRATIVOS
-- ============================================================================

-- [TESTE 1] Criar fatura tentando passar Total falso (500.00):
-- A trigger BEFORE INSERT força Total = 0.00
INSERT INTO Invoice (InvoiceId, CustomerId, InvoiceDate, Total)
VALUES (8888, 1, NOW(), 500.00);

SELECT InvoiceId, Total AS total_inicial_esperado_zero
  FROM Invoice WHERE InvoiceId = 8888;

-- [TESTE 2] Inserção via Stored Procedure (2 unidades de R$ 0.99 = R$ 1.98)
CALL sp_adicionar_item_e_atualizar_total(8888, 1, 0.99, 2);

SELECT InvoiceId, Total AS total_apos_procedure_1_98
  FROM Invoice WHERE InvoiceId = 8888;

-- [TESTE 3] Inserção direta em InvoiceLine (acionando trigger AFTER INSERT)
-- + 1 unidade de R$ 1.99 -> Total esperado: 1.98 + 1.99 = 3.97
INSERT INTO InvoiceLine (InvoiceLineId, InvoiceId, TrackId, UnitPrice, Quantity)
VALUES (88881, 8888, 2, 1.99, 1);

SELECT InvoiceId, Total AS total_apos_insert_trigger_3_97
  FROM Invoice WHERE InvoiceId = 8888;

-- [TESTE 4] Atualização de quantidade em InvoiceLine (acionando trigger AFTER UPDATE)
-- Alterar Quantity de 1 para 3 no item 88881 -> Total esperado: 1.98 + (1.99 * 3) = 7.95
UPDATE InvoiceLine SET Quantity = 3 WHERE InvoiceLineId = 88881;

SELECT InvoiceId, Total AS total_apos_update_trigger_7_95
  FROM Invoice WHERE InvoiceId = 8888;

-- [TESTE 5 - FALHA ESPERADA] Tentativa de fraudar Invoice.Total diretamente
-- Descomente a linha abaixo para validar o bloqueio pela trigger trg_invoice_total_bu:
-- UPDATE Invoice SET Total = 999.99 WHERE InvoiceId = 8888;
-- Resultado esperado: Error Code: 1644. Violação de Integridade: O campo Total de Invoice deve corresponder à soma...

-- [TESTE 6] Exclusão de item em InvoiceLine (acionando trigger AFTER DELETE)
DELETE FROM InvoiceLine WHERE InvoiceId = 8888;

SELECT InvoiceId, Total AS total_apos_delete_esperado_zero
  FROM Invoice WHERE InvoiceId = 8888;

-- Limpeza dos registros de teste
DELETE FROM Invoice WHERE InvoiceId = 8888;
