USE chinook;

DELIMITER $$


-- REGRA 1: só 'Sales Support Agent' pode ser representante de suporte
DROP PROCEDURE IF EXISTS sp_definir_representante_suporte$$

CREATE DEFINER = CURRENT_USER PROCEDURE sp_definir_representante_suporte(
    IN p_customer_id INT,
    IN p_employee_id INT
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_title VARCHAR(30);

    IF NOT EXISTS (SELECT 1 FROM Customer WHERE CustomerId = p_customer_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cliente não encontrado.';
    END IF;

    SELECT Title INTO v_title
    FROM Employee
    WHERE EmployeeId = p_employee_id;

    IF v_title IS NULL AND NOT EXISTS
        (SELECT 1 FROM Employee WHERE EmployeeId = p_employee_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Funcionário não encontrado.';
    END IF;

    -- Regra 1: o cargo precisa ser 'Sales Support Agent'
    IF v_title IS NULL OR v_title <> 'Sales Support Agent' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Regra 1: somente funcionários com cargo Sales Support Agent podem ser representantes de suporte.';
    END IF;

    UPDATE Customer
    SET SupportRepId = p_employee_id
    WHERE CustomerId = p_customer_id;
END$$


-- REGRA 2: UnitPrice da InvoiceLine >= UnitPrice da Track
DROP PROCEDURE IF EXISTS sp_inserir_item_fatura$$

CREATE DEFINER = CURRENT_USER PROCEDURE sp_inserir_item_fatura(
    IN p_invoice_id  INT,
    IN p_track_id    INT,
    IN p_unit_price  DECIMAL(10,2),
    IN p_quantity    INT
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_preco_catalogo DECIMAL(10,2);
    DECLARE v_proximo_id     INT;

    IF NOT EXISTS (SELECT 1 FROM Invoice WHERE InvoiceId = p_invoice_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Fatura não encontrada.';
    END IF;

    SELECT UnitPrice INTO v_preco_catalogo
    FROM Track
    WHERE TrackId = p_track_id;

    IF v_preco_catalogo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Música não encontrada.';
    END IF;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A quantidade deve ser maior que zero.';
    END IF;

    -- Regra 2: preço cobrado não pode ser menor que o do catálogo
    IF p_unit_price IS NULL OR p_unit_price < v_preco_catalogo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Regra 2: o preço unitário do item não pode ser inferior ao preço de catálogo da música.';
    END IF;

    SELECT COALESCE(MAX(InvoiceLineId), 0) + 1
      INTO v_proximo_id
    FROM InvoiceLine;

    INSERT INTO InvoiceLine (InvoiceLineId, InvoiceId, TrackId, UnitPrice, Quantity)
    VALUES (v_proximo_id, p_invoice_id, p_track_id, p_unit_price, p_quantity);
END$$

DELIMITER ;



-- USUÁRIO COM ACESSO SOMENTE AOS PROCEDIMENTOS
DROP USER IF EXISTS 'usuario_regras'@'localhost';
CREATE USER 'usuario_regras'@'localhost' IDENTIFIED BY 'Senha@123';

GRANT EXECUTE ON PROCEDURE chinook.sp_definir_representante_suporte
    TO 'usuario_regras'@'localhost';
GRANT EXECUTE ON PROCEDURE chinook.sp_inserir_item_fatura
    TO 'usuario_regras'@'localhost';

FLUSH PRIVILEGES;
