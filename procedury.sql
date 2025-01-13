DELIMITER //

-- PROCEDURY
CREATE PROCEDURE aktualizacja_statusu_weryfikacji (
    IN p_email INT,
)
BEGIN
    UPDATE Uzytkownik 
    SET status_weryfikacji = TRUE 
    WHERE email = p_email;
END//

CREATE PROCEDURE dodaj_kurs (
    IN p_id_meczu INT,
    IN p_nazwa_typu VARCHAR(255),
    IN p_kurs Decimal(10, 2),
    OUT p_id_kursu INT,
)
BEGIN
    -- Deklaracja zmiennych dla statusu meczu
    DECLARE v_status_meczu VARCHAR(50);
    DECLARE v_data_meczu DATETIME;
    
    -- Status meczu i data
    SELECT status, data_meczu INTO v_status_meczu, v_data_meczu
    FROM Mecz 
    WHERE id_meczu = p_id_meczu;
    
    -- czy mecz istnieje
    IF v_status_meczu IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Mecz o podanym ID nie istnieje';
    END IF;
    
    -- czy mecz nie jest zakończony
    IF v_status_meczu = 'Zakończony' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nie można dodać kursu do zakończonego meczu';
    END IF;
    
    -- Sprawdzamy czy mecz się nie rozpoczął
    IF v_data_meczu <= NOW() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nie można dodać kursu do rozpoczętego meczu';
    END IF;
    
    -- czy kurs jest większy od 1
    IF p_kurs <= 1 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Kurs musi być większy od 1';
    END IF;
    
    -- Sprawdzamy czy taki typ kursu już istnieje dla tego meczu
    IF EXISTS (
        SELECT 1 
        FROM Kursy_Meczu 
        WHERE id_meczu = p_id_meczu 
        AND nazwa_typu = p_nazwa_typu 
        AND status = TRUE
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ten typ kursu już istnieje dla tego meczu';
    END IF;
    
    -- poprawność typu kursu
    IF p_nazwa_typu NOT IN ('zwycięstwo gospodarzy', 'remis', 'zwycięstwo gości') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nieprawidłowy typ kursu. Dozwolone typy: zwycięstwo gospodarzy, remis, zwycięstwo gości';
    END IF;
    
    
    INSERT INTO Kursy_Meczu (
        id_meczu, 
        nazwa_typu, 
        kurs, 
        status, 
        data_utworzenia
    ) VALUES (
        p_id_meczu,
        p_nazwa_typu,
        p_kurs,
        TRUE,
        NOW()
    );
    
    
    SET p_id_kursu = LAST_INSERT_ID();
    
  	-- szczegóły ooooo
    SELECT 
        k.id,
        k.nazwa_typu,
        k.kurs,
        k.data_utworzenia,
        m.data_meczu,
        CONCAT(d1.nazwa, ' vs ', d2.nazwa) as nazwa_meczu
    FROM Kursy_Meczu k
    JOIN Mecz m ON k.id_meczu = m.id_meczu
    JOIN Druzyny d1 ON m.id_gospodarzy = d1.id_druzyny
    JOIN Druzyny d2 ON m.id_gosci = d2.id_druzyny
    WHERE k.id = p_id_kursu;
    
END//

CREATE PROCEDURE dodaj_transakcje (
    IN p_id_uzytkownika INT,
    IN p_kwota DECIMAL(10, 2),
    IN p_typ_operacji VARCHAR(50),
    IN p_saldo_po_operacji DECIMAL(10, 2),
)
BEGIN
    DECLARE v_id_transakcji INT;
    
 
    IF p_kwota > 0 OR p_typ_operacji = 'Postawienie zakładu' THEN
        INSERT INTO Transakcje (kwota, typ_operacji, data)
        VALUES (p_kwota, p_typ_operacji, NOW());
        
        SET v_id_transakcji = LAST_INSERT_ID();
        
        INSERT INTO Ksiegowosc (id_uzytkownika, id_transakcji)
        VALUES (p_id_uzytkownika, v_id_transakcji);
        
        INSERT INTO Historia_Salda (id_uzytkownika, zmiana_balansu, saldo_po_operacji, id_transakcji)
        VALUES (p_id_uzytkownika, 
                IF(p_typ_operacji = 'Postawienie zakładu', -p_kwota, p_kwota),
                p_saldo_po_operacji, 
                v_id_transakcji);
    END IF;
END//

CREATE PROCEDURE postaw_zaklad (
    IN p_id_uzytkownika INT,
    IN p_id_kursu INT,
    IN p_kwota_postawiona DECIMAL(10, 2),
    IN p_id_zakladu INT,
)

BEGIN
    DECLARE v_balans DECIMAL(10,2);
    DECLARE v_id_meczu INT;
    DECLARE v_kurs DECIMAL(10,2);
    DECLARE v_status_meczu VARCHAR(50);
    DECLARE v_potencjalna_wygrana DECIMAL(10,2);
    
    START TRANSACTION;
    
    -- Sprawdź balans użytkownika
    SELECT balans INTO v_balans
    FROM Uzytkownik 
    WHERE id_uzytkownika = p_id_uzytkownika
    FOR UPDATE;
    
    IF v_balans < p_kwota_postawiona THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Niewystarczające środki na koncie';
    END IF;
    
    -- Pobierz informacje o kursie i meczu
    SELECT km.id_meczu, km.kurs, m.status 
    INTO v_id_meczu, v_kurs, v_status_meczu
    FROM Kursy_Meczu km
    JOIN Mecz m ON km.id_meczu = m.id_meczu
    WHERE km.id = p_id_kursu;
    
    IF v_status_meczu NOT IN ('oczekujący', 'nowy', 'zaplanowany') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Mecz nie jest dostępny do obstawiania';
    END IF;
    
    -- Oblicz potencjalną wygraną
    SET v_potencjalna_wygrana = p_kwota_postawiona * v_kurs;
    
    -- Zapisz zakład
    INSERT INTO Zaklad (id_meczu, id_uzytkownika, wynik, kwota_postawiona, 
                       potencjalna_wygrana, status_zakladu, data_postawienia, kurs_meczu)
    VALUES (v_id_meczu, p_id_uzytkownika, FALSE, p_kwota_postawiona, 
            v_potencjalna_wygrana, 'Oczekujący', NOW(), p_id_kursu);
    
    SET p_id_zakladu = LAST_INSERT_ID();
    
    -- Aktualizuj balans użytkownika
    UPDATE Uzytkownik 
    SET balans = balans - p_kwota_postawiona
    WHERE id_uzytkownika = p_id_uzytkownika;
    
    -- Dodaj transakcję
    CALL dodaj_transakcje(p_id_uzytkownika, p_kwota_postawiona, 'Postawienie zakładu', 
                           v_balans - p_kwota_postawiona);
    
    COMMIT;
END//

CREATE PROCEDURE reset_hasla (
    IN p_nazwa VARCHAR(255),
    IN p_new_password VARCHAR(255),
)
BEGIN
    UPDATE Uzytkownik 
    SET haslo = p_new_password 
    WHERE nazwa = p_nazwa;
END//

CREATE PROCEDURE rozlicz_mecz (
    IN p_id_meczu INT,
)
BEGIN
    DECLARE v_gole_gospodarzy INT;
    DECLARE v_gole_gosci INT;
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_id_zakladu, v_id_uzytkownika INT;
    DECLARE v_kwota_postawiona, v_potencjalna_wygrana, v_current_balance DECIMAL(10,2);
    DECLARE v_nazwa_typu VARCHAR(50);
    
    DECLARE cur_zaklady CURSOR FOR
        SELECT z.id_zakladu, z.id_uzytkownika, z.kwota_postawiona, 
               z.potencjalna_wygrana, km.nazwa_typu
        FROM Zaklad z
        JOIN Kursy_Meczu km ON z.kurs_meczu = km.id
        WHERE z.id_meczu = p_id_meczu AND z.status_zakladu = 'Oczekujący';
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    START TRANSACTION;
    
    -- Pobierz wynik meczu
    SELECT gole_gospodarzy, gole_gosci 
    INTO v_gole_gospodarzy, v_gole_gosci
    FROM Mecz 
    WHERE id_meczu = p_id_meczu;
    
    OPEN cur_zaklady;
    
    read_loop: LOOP
        FETCH cur_zaklady INTO v_id_zakladu, v_id_uzytkownika, 
                              v_kwota_postawiona, v_potencjalna_wygrana, v_nazwa_typu;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Sprawdź czy zakład wygrał
        SET @wygrany = CASE
            WHEN v_nazwa_typu = 'zwycięstwo gospodarzy' AND v_gole_gospodarzy > v_gole_gosci THEN TRUE
            WHEN v_nazwa_typu = 'remis' AND v_gole_gospodarzy = v_gole_gosci THEN TRUE
            WHEN v_nazwa_typu = 'zwycięstwo gości' AND v_gole_gospodarzy < v_gole_gosci THEN TRUE
            ELSE FALSE
        END;
        
        -- Aktualizuj status zakładu
        UPDATE Zaklad 
        SET status_zakladu = IF(@wygrany, 'Wygrany', 'Przegrany'),
            wynik = @wygrany
        WHERE id_zakladu = v_id_zakladu;
        
        -- Jeśli wygrany, wypłać wygraną
        IF @wygrany THEN
            SELECT balans INTO v_current_balance
            FROM Uzytkownik
            WHERE id_uzytkownika = v_id_uzytkownika
            FOR UPDATE;
            
            UPDATE Uzytkownik 
            SET balans = balans + v_potencjalna_wygrana
            WHERE id_uzytkownika = v_id_uzytkownika;
            
            CALL dodaj_transakcje(v_id_uzytkownika, v_potencjalna_wygrana, 
                                  'Wygrana zakładu', v_current_balance + v_potencjalna_wygrana);
        ELSE
            SELECT balans INTO v_current_balance
            FROM Uzytkownik
            WHERE id_uzytkownika = v_id_uzytkownika;
            
            CALL dodaj_transakcje(v_id_uzytkownika, 0, 'Przegrana zakładu', v_current_balance);
        END IF;
    END LOOP;
    
    CLOSE cur_zaklady;
    
    -- Zaktualizuj status meczu
    UPDATE Mecz 
    SET status = 'Zakończony',
        zwyciestwo_gospodarzy = v_gole_gospodarzy > v_gole_gosci,
        zwyciestwo_gosci = v_gole_gospodarzy < v_gole_gosci
    WHERE id_meczu = p_id_meczu;
    
    COMMIT;
END//

CREATE PROCEDURE tworzenie_uzytkownika (
    IN p_nazwa VARCHAR(255),
    IN p_haslo VARCHAR(255),
    IN p_email VARCHAR(255),
    IN p_balans DECIMAL(10, 2),
    IN p_rola VARCHAR(50),
    IN p_status_weryfikacji BOOLEAN,
)

BEGIN
    INSERT INTO Uzytkownik (nazwa, haslo, email, balans, data_utworzenia, rola, status_weryfikacji)
    VALUES (p_nazwa, p_haslo, p_email, p_balans, NOW(), p_rola, p_status_weryfikacji);
    SELECT LAST_INSERT_ID() as id_uzytkownika;
END//

CREATE PROCEDURE usun_uzytkownika (
    IN p_id_uzytkownika INT,
)
BEGIN
    DELETE FROM Uzytkownik 
    WHERE id_uzytkownika = p_id_uzytkownika;
END//

CREATE PROCEDURE zaaktualizuj_kurs (
    IN p_mecz_id INT,
    IN p_kurs_id INT,
    IN p_nowy_kurs DECIMAL(10, 2),
)
BEGIN
    UPDATE Kursy_Meczu 
    SET kurs = p_nowy_kurs
    WHERE id = p_kurs_id 
    AND id_meczu = p_mecz_id 
    AND status = TRUE;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nie znaleziono aktywnego kursu';
    END IF;
END//

CREATE PROCEDURE znajdz_mecz (
    IN p_search_query VARCHAR(255),
)
BEGIN
    SELECT DISTINCT
        m.id_meczu,
        dg.nazwa AS gospodarz,
        dgos.nazwa AS gosc,
        m.data_meczu,
        m.gole_gospodarzy,
        m.gole_gosci,
        m.status
    FROM Mecz m
    JOIN Druzyny dg ON m.id_gospodarzy = dg.id_druzyny
    JOIN Druzyny dgos ON m.id_gosci = dgos.id_druzyny
    WHERE p_search_query = 'all' 
    OR dg.nazwa LIKE CONCAT('%', p_search_query, '%')
    OR dgos.nazwa LIKE CONCAT('%', p_search_query, '%')
    AND m.status = 'Oczekujący';
END//

DELIMITER ;

-- WIDOKI

CREATE VIEW aktywne_kursy AS
select `km`.`id` AS `id`,`km`.`id_meczu` AS `id_meczu`,`km`.`nazwa_typu` AS `nazwa_typu`,`km`.`kurs` AS `kurs`,`km`.`status` AS `status`,`km`.`data_utworzenia` AS `data_utworzenia` from `Bukmacher`.`Kursy_Meczu` `km` where (`km`.`status` = true);

CREATE VIEW statystyki_uzytkownika AS
select `Bukmacher`.`Zaklad`.`id_uzytkownika` AS `id_uzytkownika`,count((case when (`Bukmacher`.`Zaklad`.`wynik` = true) then 1 end)) AS `wygrane_zaklady`,count((case when (`Bukmacher`.`Zaklad`.`wynik` = false) then 1 end)) AS `przegrane_zaklady`,sum((case when (`Bukmacher`.`Zaklad`.`wynik` = true) then `Bukmacher`.`Zaklad`.`potencjalna_wygrana` else 0 end)) AS `suma_wygranych`,sum((case when (`Bukmacher`.`Zaklad`.`wynik` = false) then `Bukmacher`.`Zaklad`.`kwota_postawiona` else 0 end)) AS `suma_przegranych`,sum(`Bukmacher`.`Zaklad`.`kwota_postawiona`) AS `suma_postawionych`,round(((count((case when (`Bukmacher`.`Zaklad`.`wynik` = true) then 1 end)) * 100.0) / nullif(count(0),0)),2) AS `procent_wygranych` from `Bukmacher`.`Zaklad` where (`Bukmacher`.`Zaklad`.`status_zakladu` in ('Wygrany','Przegrany')) group by `Bukmacher`.`Zaklad`.`id_uzytkownika`;

CREATE VIEW szczegoly_meczu AS
select `m`.`id_meczu` AS `id_meczu`,`dg`.`nazwa` AS `gospodarz`,`dgos`.`nazwa` AS `gosc`,`m`.`data_meczu` AS `data_meczu`,`m`.`gole_gospodarzy` AS `gole_gospodarzy`,`m`.`gole_gosci` AS `gole_gosci`,`m`.`status` AS `status` from ((`Bukmacher`.`Mecz` `m` join `Bukmacher`.`Druzyny` `dg` on((`m`.`id_gospodarzy` = `dg`.`id_druzyny`))) join `Bukmacher`.`Druzyny` `dgos` on((`m`.`id_gosci` = `dgos`.`id_druzyny`)));

CREATE VIEW uzytkownik_historia_balansu AS
select `hs`.`id_uzytkownika` AS `id_uzytkownika`,`hs`.`zmiana_balansu` AS `zmiana_balansu`,`hs`.`saldo_po_operacji` AS `saldo_po_operacji`,`t`.`typ_operacji` AS `typ_operacji`,`t`.`data` AS `data`,`t`.`kwota` AS `kwota` from (`Bukmacher`.`Historia_Salda` `hs` join `Bukmacher`.`Transakcje` `t` on((`hs`.`id_transakcji` = `t`.`id`)));

CREATE VIEW uzytkownik_szczegoly AS
select `Bukmacher`.`Uzytkownik`.`id_uzytkownika` AS `id_uzytkownika`,`Bukmacher`.`Uzytkownik`.`nazwa` AS `nazwa`,`Bukmacher`.`Uzytkownik`.`haslo` AS `haslo`,`Bukmacher`.`Uzytkownik`.`email` AS `email`,`Bukmacher`.`Uzytkownik`.`balans` AS `balans`,`Bukmacher`.`Uzytkownik`.`data_utworzenia` AS `data_utworzenia`,`Bukmacher`.`Uzytkownik`.`rola` AS `rola`,`Bukmacher`.`Uzytkownik`.`status_weryfikacji` AS `status_weryfikacji` from `Bukmacher`.`Uzytkownik`;

CREATE VIEW widok_uzytkownik_transakcje AS
select `k`.`id_uzytkownika` AS `id_uzytkownika`,`t`.`typ_operacji` AS `typ_operacji`,sum(`t`.`kwota`) AS `suma_kwota`,count(`t`.`id`) AS `liczba_transakcji` from (`Bukmacher`.`Transakcje` `t` join `Bukmacher`.`Ksiegowosc` `k` on((`t`.`id` = `k`.`id_transakcji`))) group by `k`.`id_uzytkownika`,`t`.`typ_operacji`;