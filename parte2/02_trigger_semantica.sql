
Para implementar a regra semântica 1, criamos dois triggers na tabela customer: trg_validacao_bi e trg_validacao_bu. O primeiro executa antes da inserção (BEFORE INSERT) e o segundo antes da atualização (BEFORE UPDATE), garantindo a validação em relação a cada linha (FOR EACH ROW). O comando DELIMITER é utilizado para permitir o uso de múltiplos comandos no mesmo bloco. Dentro de cada trigger criou-se uma variável v_cargo VARCHAR(30). Quando uma operação fornece um representante, o trigger consulta a tabela employee, buscando a coluna Title e atribuindo o resultado a v_cargo. Em seguida, é feita uma verificação para ver se v_cargo é diferente de ‘Sales Support Agent’. Caso seja diferente, é disparada uma exceção e a operação de inserção/atualização é cancelada. 
```sql
  USE chinook_autoincrement;

DROP TRIGGER IF EXISTS trg_validacao_bi;
DROP TRIGGER IF EXISTS trg_validacao_bu;

DELIMITER //

CREATE TRIGGER trg_validacao_bi
BEFORE INSERT ON customer
FOR EACH ROW
BEGIN
	DECLARE v_cargo VARCHAR(30);
	
	IF NEW.SupportRepId IS NOT NULL THEN
		SELECT Title INTO v_cargo
		FROM employee
		WHERE EmployeeId = NEW.SupportRepId;

		IF v_cargo<>'Sales Support Agent' THEN
			SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Violação de Regra Semântica: O    funcionário deve ter o cargo Sales Support Agent.';
END IF;
	END IF;
END //

CREATE TRIGGER trg_validacao_bu
BEFORE UPDATE ON customer
FOR EACH ROW
BEGIN
	DECLARE v_cargo VARCHAR(30);
	
	IF NEW.SupportRepId IS NOT NULL THEN
		SELECT Title INTO v_cargo
		FROM employee
		WHERE EmployeeId = NEW.SupportRepId;

		IF v_cargo<> 'Sales Support Agent' THEN
			SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Violação de Regra Semântica: O    funcionário deve ter o cargo Sales Support Agent.';
END IF;
	END IF;
END //

DELIMITER ;
```
Para implementar a regra 2, criamos também dois triggers na tabela invoiceline: trg_validacao_preco_bi e trg_validacao_preco_bu. Como no exemplo anterior, o primeiro trigger refere-se a antes da inserção e o segundo antes da atualização. No gatilho, declarou-se a variável local v_precocatalogo DECIMAL(10,2). Durante a execução, o trigger utiliza a chave primária da faixa a ser vendida (NEW.TrackId) e realiza uma consulta na tabela track para capturar o preço unitário oficial do catálogo (UnitPrice), e armazena em v_preco_catalogo. Por fim, a comparação é feita entre a venda NEW.UnitPrice e o preço de tabela consultado (v_preco_catalogo). Caso o valor informado seja menor do que o preço do catálogo da música, o trigger é disparado com uma mensagem de erro e a operação é cancelada.

  ```sql
  USE chinook_autoincrement;

DROP TRIGGER IF EXISTS trg_validacao_preco_bi;
DROP TRIGGER IF EXISTS trg_validacao_preco_bu;

DELIMITER //
CREATE TRIGGER trg_validacao_preco_bi
BEFORE INSERT ON invoiceline
FOR EACH ROW
BEGIN
    DECLARE v_preco_catalogo DECIMAL(10,2);

    SELECT UnitPrice INTO v_preco_catalogo
    FROM track
    WHERE TrackId = NEW.TrackId;

    IF NEW.UnitPrice < v_preco_catalogo THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Violação de Regra Semântica: O preço unitário na fatura não pode ser inferior ao preço de catálogo da faixa musical.';
    END IF;
END //

CREATE TRIGGER trg_validacao_preco_bu
BEFORE UPDATE ON invoiceline
FOR EACH ROW
BEGIN
    DECLARE v_preco_catalogo DECIMAL(10,2);

    SELECT UnitPrice INTO v_preco_catalogo
    FROM track
    WHERE TrackId = NEW.TrackId;

    IF NEW.UnitPrice < v_preco_catalogo THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Violação de Regra Semântica: O preço unitário na fatura não pode ser inferior ao preço de catálogo da faixa musical.';
    END IF;
END //

DELIMITER ;

  ```
