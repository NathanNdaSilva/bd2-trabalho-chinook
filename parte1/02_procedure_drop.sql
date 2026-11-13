DELIMITER $$

DROP PROCEDURE IF EXISTS sp_remover_indices$$

CREATE PROCEDURE sp_remover_indices(IN p_tabela VARCHAR(64))
BEGIN
    DECLARE v_indice VARCHAR(64);
    DECLARE v_fim    INT DEFAULT 0;
    DECLARE v_tem_pk INT DEFAULT 0;

    DECLARE cur_indices CURSOR FOR
        SELECT DISTINCT INDEX_NAME
        FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME   = p_tabela
          AND INDEX_NAME  <> 'PRIMARY';

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim = 1;

    -- Remove as FKs que saem da tabela
    BEGIN
        DECLARE v_fk     VARCHAR(64);
        DECLARE v_fim_fk INT DEFAULT 0;

        DECLARE cur_fks CURSOR FOR
            SELECT CONSTRAINT_NAME
            FROM information_schema.TABLE_CONSTRAINTS
            WHERE TABLE_SCHEMA    = DATABASE()
              AND TABLE_NAME      = p_tabela
              AND CONSTRAINT_TYPE = 'FOREIGN KEY';

        DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim_fk = 1;

        OPEN cur_fks;
        loop_fks: LOOP
            FETCH cur_fks INTO v_fk;
            IF v_fim_fk = 1 THEN
                LEAVE loop_fks;
            END IF;

            SET @sql = CONCAT('ALTER TABLE `', p_tabela,
                              '` DROP FOREIGN KEY `', v_fk, '`');
            PREPARE stmt FROM @sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        END LOOP;
        CLOSE cur_fks;
    END;

    -- Remove as FKs de outras tabelas que chegam nessa tabela
    BEGIN
        DECLARE v_tab_ref VARCHAR(64);
        DECLARE v_fk_ref  VARCHAR(64);
        DECLARE v_fim_ref INT DEFAULT 0;

        DECLARE cur_refs CURSOR FOR
            SELECT TABLE_NAME, CONSTRAINT_NAME
            FROM information_schema.REFERENTIAL_CONSTRAINTS
            WHERE CONSTRAINT_SCHEMA   = DATABASE()
              AND REFERENCED_TABLE_NAME = p_tabela;

        DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim_ref = 1;

        OPEN cur_refs;
        loop_refs: LOOP
            FETCH cur_refs INTO v_tab_ref, v_fk_ref;
            IF v_fim_ref = 1 THEN
                LEAVE loop_refs;
            END IF;

            SET @sql = CONCAT('ALTER TABLE `', v_tab_ref,
                              '` DROP FOREIGN KEY `', v_fk_ref, '`');
            PREPARE stmt FROM @sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        END LOOP;
        CLOSE cur_refs;
    END;

    -- Remove os índices comuns, únicos, fulltext, etc.
    OPEN cur_indices;
    loop_indices: LOOP
        FETCH cur_indices INTO v_indice;
        IF v_fim = 1 THEN
            LEAVE loop_indices;
        END IF;

        SET @sql = CONCAT('DROP INDEX `', v_indice, '` ON `', p_tabela, '`');
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP;
    CLOSE cur_indices;

    -- Remove a chave primária, se existir
    SELECT COUNT(*) INTO v_tem_pk
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA    = DATABASE()
      AND TABLE_NAME      = p_tabela
      AND CONSTRAINT_TYPE = 'PRIMARY KEY';

    IF v_tem_pk > 0 THEN
        SET @sql = CONCAT('ALTER TABLE `', p_tabela, '` DROP PRIMARY KEY');
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$

DELIMITER ;
