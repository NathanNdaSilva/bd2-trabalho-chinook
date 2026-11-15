-- Questão 4:

-- 1. Extrai tipagem e atributos das colunas da tabela

DELIMITER $$

DROP PROCEDURE IF EXISTS ObterTipagemColunasTabela$$

CREATE PROCEDURE ObterTipagemColunasTabela(
    IN p_schema VARCHAR(64),
    IN p_tabela VARCHAR(64)
)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS temp_colunas_tabela;

    CREATE TEMPORARY TABLE temp_colunas_tabela (
        posicao INT,
        coluna VARCHAR(64),
        tipo VARCHAR(64),
        auto_increment VARCHAR(20),
        aceita_null VARCHAR(10),
        valor_default VARCHAR(64)
    );

    INSERT INTO temp_colunas_tabela (
        posicao, 
        coluna, 
        tipo, 
        auto_increment,
        aceita_null, 
        valor_default
    )
    SELECT 
        ORDINAL_POSITION AS posicao,
        COLUMN_NAME AS coluna,
        COLUMN_TYPE AS tipo,
        IF(EXTRA LIKE '%auto_increment%', 'AUTO_INCREMENT', '') AS auto_increment,
        IF(IS_NULLABLE = 'NO', 'NOT NULL', 'NULL') AS aceita_null,
        IF(COLUMN_DEFAULT IS NOT NULL, CONCAT('DEFAULT ', COLUMN_DEFAULT), '') AS valor_default
    FROM information_schema.columns
    WHERE TABLE_SCHEMA = p_schema
      AND TABLE_NAME = p_tabela
    ORDER BY ORDINAL_POSITION;
END$$

DELIMITER ;

-- 2. Extrai restrições (PK, FK, UNIQUE e CHECK)

DELIMITER $$

DROP PROCEDURE IF EXISTS ObterRestricoesTabela$$

CREATE PROCEDURE ObterRestricoesTabela(
    IN p_schema VARCHAR(64),
    IN p_tabela VARCHAR(64)
)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS temp_restricoes_tabela;

    CREATE TEMPORARY TABLE temp_restricoes_tabela (
        posicao INT AUTO_INCREMENT PRIMARY KEY,
        nome_constraint VARCHAR(64),
        tipo_constraint VARCHAR(64),
        coluna VARCHAR(255),
        tabela_destino VARCHAR(64),
        coluna_destino VARCHAR(64),
        expressao_check TEXT
    );

    -- 2.1. Insere a PRIMARY KEY 
    INSERT INTO temp_restricoes_tabela (
        nome_constraint, tipo_constraint, coluna, tabela_destino, coluna_destino, expressao_check
    )
    SELECT 
        'PRIMARY' AS nome_constraint,
        'PRIMARY KEY' AS tipo_constraint,
        GROUP_CONCAT(CONCAT('`', kcu.COLUMN_NAME, '`') ORDER BY kcu.ORDINAL_POSITION SEPARATOR ', ') AS coluna,
        NULL AS tabela_destino,
        NULL AS coluna_destino,
        NULL AS expressao_check
    FROM information_schema.table_constraints tc
    INNER JOIN information_schema.key_column_usage kcu
        ON tc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA
       AND tc.TABLE_NAME = kcu.TABLE_NAME
       AND tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    WHERE tc.CONSTRAINT_SCHEMA = p_schema 
      AND tc.TABLE_NAME = p_tabela
      AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
    GROUP BY tc.CONSTRAINT_NAME;

    -- 2.2. Insere as demais restrições 
    INSERT INTO temp_restricoes_tabela (
        nome_constraint, tipo_constraint, coluna, tabela_destino, coluna_destino, expressao_check
    )
    SELECT 
        tc.CONSTRAINT_NAME,
        tc.CONSTRAINT_TYPE,
        kcu.COLUMN_NAME,
        kcu.REFERENCED_TABLE_NAME,
        kcu.REFERENCED_COLUMN_NAME,
        cc.CHECK_CLAUSE
    FROM information_schema.table_constraints tc
    LEFT JOIN information_schema.key_column_usage kcu
        ON tc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA
       AND tc.TABLE_NAME = kcu.TABLE_NAME
       AND tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    LEFT JOIN information_schema.check_constraints cc
        ON tc.CONSTRAINT_SCHEMA = cc.CONSTRAINT_SCHEMA
       AND tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
    WHERE tc.CONSTRAINT_SCHEMA = p_schema 
      AND tc.TABLE_NAME = p_tabela
      AND tc.CONSTRAINT_TYPE != 'PRIMARY KEY'
    ORDER BY tc.CONSTRAINT_TYPE, tc.CONSTRAINT_NAME, kcu.ORDINAL_POSITION;
END$$

DELIMITER ;

-- 3. Gera os comandos CREATE TABLE e FKs do esquema
DELIMITER $$

DROP PROCEDURE IF EXISTS GerarCreateTablesSchema$$

CREATE PROCEDURE GerarCreateTablesSchema(IN p_schema VARCHAR(64))
BEGIN
    DECLARE v_fim_tabelas INT DEFAULT FALSE;
    DECLARE v_tabela VARCHAR(64);
    DECLARE v_linha VARCHAR(500);
    DECLARE v_qtd_elementos INT DEFAULT 0;
    DECLARE v_contador INT DEFAULT 0;

    DECLARE cursor_tabelas CURSOR FOR
        SELECT TABLE_NAME
        FROM information_schema.tables
        WHERE TABLE_SCHEMA = p_schema AND TABLE_TYPE = 'BASE TABLE'
        ORDER BY TABLE_NAME;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim_tabelas = TRUE;

    DROP TEMPORARY TABLE IF EXISTS temp_create_tables;
    CREATE TEMPORARY TABLE temp_create_tables (
        id INT AUTO_INCREMENT PRIMARY KEY,
        linha_texto TEXT
    );

    DROP TEMPORARY TABLE IF EXISTS temp_fks_alter;
    CREATE TEMPORARY TABLE temp_fks_alter (
        id INT AUTO_INCREMENT PRIMARY KEY,
        linha_texto TEXT
    );

    OPEN cursor_tabelas;

    loop_tabelas: LOOP
        FETCH cursor_tabelas INTO v_tabela;

        IF v_fim_tabelas THEN
            LEAVE loop_tabelas;
        END IF;

        INSERT INTO temp_create_tables (linha_texto) VALUES (CONCAT('CREATE TABLE `', v_tabela, '` ('));

        CALL ObterTipagemColunasTabela(p_schema, v_tabela);
        CALL ObterRestricoesTabela(p_schema, v_tabela);

        SELECT COUNT(*) INTO v_qtd_elementos 
        FROM (
            SELECT coluna FROM temp_colunas_tabela
            UNION ALL
            SELECT coluna FROM temp_restricoes_tabela WHERE tipo_constraint IN ('PRIMARY KEY', 'UNIQUE', 'CHECK')
        ) AS itens;

        SET v_contador = 0;

        -- Loop de Colunas
        BEGIN
            DECLARE v_fim_colunas INT DEFAULT FALSE;
            DECLARE v_coluna, v_tipo, v_auto_inc, v_null, v_def VARCHAR(64);

            DECLARE cursor_colunas CURSOR FOR
                SELECT coluna, tipo, auto_increment, aceita_null, valor_default
                FROM temp_colunas_tabela ORDER BY posicao;

            DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim_colunas = TRUE;

            OPEN cursor_colunas;

            loop_colunas: LOOP
                FETCH cursor_colunas INTO v_coluna, v_tipo, v_auto_inc, v_null, v_def;
                IF v_fim_colunas THEN LEAVE loop_colunas; END IF;

                SET v_contador = v_contador + 1;
                SET v_linha = CONCAT('    `', v_coluna, '` ', v_tipo);

                IF v_auto_inc != '' THEN SET v_linha = CONCAT(v_linha, ' ', v_auto_inc); END IF;
                IF v_null != '' THEN SET v_linha = CONCAT(v_linha, ' ', v_null); END IF;
                IF v_def != '' THEN SET v_linha = CONCAT(v_linha, ' ', v_def); END IF;

                IF v_contador < v_qtd_elementos THEN
                    SET v_linha = CONCAT(v_linha, ',');
                END IF;

                INSERT INTO temp_create_tables (linha_texto) VALUES (v_linha);
            END LOOP loop_colunas;

            CLOSE cursor_colunas;
        END;

        -- Loop de Restrições
        BEGIN
            DECLARE v_fim_cons INT DEFAULT FALSE;
            DECLARE v_nome_cons, v_tipo_cons, v_col, v_tab_dest, v_col_dest VARCHAR(64);
            DECLARE v_exp_chk TEXT;

            DECLARE cursor_restricoes CURSOR FOR
                SELECT nome_constraint, tipo_constraint, coluna, tabela_destino, coluna_destino, expressao_check
                FROM temp_restricoes_tabela ORDER BY posicao;

            DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim_cons = TRUE;

            OPEN cursor_restricoes;

            loop_restricoes: LOOP
                FETCH cursor_restricoes INTO v_nome_cons, v_tipo_cons, v_col, v_tab_dest, v_col_dest, v_exp_chk;
                IF v_fim_cons THEN LEAVE loop_restricoes; END IF;

                IF v_tipo_cons = 'FOREIGN KEY' THEN
                    INSERT INTO temp_fks_alter (linha_texto)
                    VALUES (CONCAT('ALTER TABLE `', v_tabela, '` ADD CONSTRAINT `', v_nome_cons, '` FOREIGN KEY (`', v_col, '`) REFERENCES `', v_tab_dest, '` (`', v_col_dest, '`);'));
                ELSE
                    SET v_contador = v_contador + 1;

                    IF v_tipo_cons = 'PRIMARY KEY' THEN
                        SET v_linha = CONCAT('    PRIMARY KEY (', v_col, ')');
                    ELSEIF v_tipo_cons = 'UNIQUE' THEN
                        SET v_linha = CONCAT('    CONSTRAINT `', v_nome_cons, '` UNIQUE (`', v_col, '`)');
                    ELSEIF v_tipo_cons = 'CHECK' THEN
                        SET v_linha = CONCAT('    CONSTRAINT `', v_nome_cons, '` CHECK ', v_exp_chk);
                    END IF;

                    IF v_contador < v_qtd_elementos THEN
                        SET v_linha = CONCAT(v_linha, ',');
                    END IF;

                    INSERT INTO temp_create_tables (linha_texto) VALUES (v_linha);
                END IF;

            END LOOP loop_restricoes;

            CLOSE cursor_restricoes;
        END;

        INSERT INTO temp_create_tables (linha_texto) VALUES (');');
        INSERT INTO temp_create_tables (linha_texto) VALUES ('');

    END LOOP loop_tabelas;

    CLOSE cursor_tabelas;

    INSERT INTO temp_create_tables (linha_texto) VALUES ('-- RESTRIÇÕES DE CHAVE ESTRANGEIRA (ALTER TABLE)');
    INSERT INTO temp_create_tables (linha_texto)
    SELECT linha_texto FROM temp_fks_alter ORDER BY id;

    SELECT linha_texto AS script_create_tables FROM temp_create_tables ORDER BY id;
END$$

DELIMITER ;

-- Exemplo de execução:
CALL GerarCreateTablesSchema('chinook');
