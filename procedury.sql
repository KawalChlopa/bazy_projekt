-- PROCEDURY
DELIMITER //
DROP PROCEDURE IF EXISTS aktualizacja_statusu_weryfikacji//
CREATE PROCEDURE aktualizacja_statusu_weryfikacji (
    IN p_email VARCHAR(255)
)
BEGIN
    UPDATE Uzytkownik 
    SET status_weryfikacji = TRUE 
    WHERE email = p_email;
END//

DROP PROCEDURE IF EXISTS dodaj_kurs//
CREATE PROCEDURE dodaj_kurs (
    IN p_id_meczu INT,
    IN p_nazwa_typu VARCHAR(255),
    IN p_kurs DECIMAL(10, 2),
    OUT p_id_kursu INT
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
    
    -- szczegóły
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

DROP PROCEDURE IF EXISTS dodaj_transakcje//

CREATE PROCEDURE dodaj_transakcje (
    IN p_id_uzytkownika INT,
    IN p_kwota DECIMAL(10, 2),
    IN p_typ_operacji VARCHAR(50),
    IN p_saldo_po_operacji DECIMAL(10, 2)
)
BEGIN
    DECLARE v_id_transakcji INT;
    -- Sprawdzenie parametrów wejściowych
IF p_id_uzytkownika IS NULL OR p_kwota IS NULL OR p_typ_operacji IS NULL OR p_saldo_po_operacji IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Wszystkie parametry są wymagane';
    END IF;

START TRANSACTION;
 
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
    
    COMMIT;

END//

DROP PROCEDURE IF EXISTS postaw_zaklad//
CREATE PROCEDURE postaw_zaklad (
    IN p_id_uzytkownika INT,
    IN p_id_kursu INT,
    IN p_kwota_postawiona DECIMAL(10, 2),
    OUT p_id_zakladu INT
)
BEGIN
    DECLARE v_balans DECIMAL(10,2);
    DECLARE v_id_meczu INT;
    DECLARE v_kurs DECIMAL(10,2);
    DECLARE v_status_meczu VARCHAR(50);
    DECLARE v_potencjalna_wygrana DECIMAL(10,2);
    DECLARE v_id_transakcji BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    -- Sprawdzenie użytkownika i balansu
    SELECT balans INTO v_balans
    FROM Uzytkownik 
    WHERE id_uzytkownika = p_id_uzytkownika
    FOR UPDATE;
    
    IF v_balans IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Użytkownik nie istnieje';
    END IF;
    
    IF v_balans < p_kwota_postawiona THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Niewystarczające środki na koncie';
    END IF;
    
    -- Sprawdzenie kursu
    SELECT km.id_meczu, km.kurs, m.status 
    INTO v_id_meczu, v_kurs, v_status_meczu
    FROM Kursy_Meczu km
    JOIN Mecz m ON km.id_meczu = m.id_meczu
    WHERE km.id = p_id_kursu AND km.status = TRUE;
    
    IF v_id_meczu IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nieprawidłowy kurs lub kurs nieaktywny';
    END IF;
    
    -- Obliczenie potencjalnej wygranej
    SET v_potencjalna_wygrana = p_kwota_postawiona * v_kurs;
    
    -- Zapisanie transakcji
    INSERT INTO Transakcje (kwota, data, typ_operacji)
    VALUES (-p_kwota_postawiona, NOW(), 'Postawienie zakładu');
    
    SET v_id_transakcji = LAST_INSERT_ID();
    
    -- Zapisanie w księgowości
    INSERT INTO Ksiegowosc (id_uzytkownika, id_transakcji)
    VALUES (p_id_uzytkownika, v_id_transakcji);
    
    -- Aktualizacja historii salda
    INSERT INTO Historia_Salda (
        id_uzytkownika, 
        saldo_po_operacji, 
        zmiana_balansu, 
        id_transakcji
    ) VALUES (
        p_id_uzytkownika, 
        v_balans - p_kwota_postawiona, 
        -p_kwota_postawiona,
        v_id_transakcji
    );
    
    -- Zapisanie zakładu
    INSERT INTO Zaklad (
        id_meczu,
        id_uzytkownika,
        kurs_meczu,
        wynik,
        kwota_postawiona,
        potencjalna_wygrana,
        status_zakladu,
        data_postawienia
    ) VALUES (
        v_id_meczu,
        p_id_uzytkownika,
        p_id_kursu,
        FALSE,
        p_kwota_postawiona,
        v_potencjalna_wygrana,
        'Oczekujący',
        NOW()
    );
    
    SET p_id_zakladu = LAST_INSERT_ID();
    
    -- Aktualizacja balansu użytkownika
    UPDATE Uzytkownik 
    SET balans = balans - p_kwota_postawiona
    WHERE id_uzytkownika = p_id_uzytkownika;
    
        IF p_id_zakladu IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nie udało się utworzyć zakładu';
    END IF;
    
 
    COMMIT;
END//

DROP PROCEDURE IF EXISTS reset_hasla//
CREATE PROCEDURE reset_hasla (
    IN p_nazwa VARCHAR(255),
    IN p_new_password VARCHAR(255)
)
BEGIN
        IF p_nazwa IS NULL OR p_nazwa = '' OR p_new_password IS NULL OR LENGTH(p_new_password) < 8 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nieprawidłowe dane wejściowe';
    END IF;

    IF p_nazwa REGEXP '[^a-zA-Z0-9_]' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Niedozwolone znaki w nazwie';
    END IF;
    UPDATE Uzytkownik 
    SET haslo = p_new_password 
    WHERE nazwa = p_nazwa;
END//

DROP PROCEDURE IF EXISTS rozlicz_mecz//
CREATE PROCEDURE rozlicz_mecz (
    IN p_id_meczu INT
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

DROP PROCEDURE IF EXISTS tworzenie_uzytkownika//
CREATE PROCEDURE tworzenie_uzytkownika (
    IN p_nazwa VARCHAR(255),
    IN p_haslo VARCHAR(255),
    IN p_email VARCHAR(255),
    IN p_balans DECIMAL(10, 2),
    IN p_rola VARCHAR(50),
    IN p_status_weryfikacji BOOLEAN
)
BEGIN
        IF p_nazwa REGEXP '[^a-zA-Z0-9_]' OR LENGTH(p_nazwa) < 3 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nieprawidłowa nazwa użytkownika';
    END IF;

    IF p_email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nieprawidłowy email';
    END IF;

    IF p_rola NOT IN ('Uzytkownik', 'Administrator', 'Moderator') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nieprawidłowa rola';
    END IF;
    INSERT INTO Uzytkownik (nazwa, haslo, email, balans, data_utworzenia, rola, status_weryfikacji)
    VALUES (p_nazwa, p_haslo, p_email, p_balans, NOW(), p_rola, p_status_weryfikacji);
    SELECT LAST_INSERT_ID() as id_uzytkownika;
END//

DROP PROCEDURE IF EXISTS usun_uzytkownika//
CREATE PROCEDURE usun_uzytkownika (
    IN p_id_uzytkownika INT
)
BEGIN
    DELETE FROM Uzytkownik 
    WHERE id_uzytkownika = p_id_uzytkownika;
END//

DROP PROCEDURE IF EXISTS aktualizuj_kurs//
CREATE PROCEDURE aktualizuj_kurs (
    IN p_mecz_id INT,
    IN p_kurs_id INT,
    IN p_nowy_kurs DECIMAL(10, 2)
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

DROP PROCEDURE IF EXISTS znajdz_mecz//
CREATE PROCEDURE znajdz_mecz (
    IN p_search_query VARCHAR(255)
)
BEGIN
        IF p_search_query IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Puste zapytanie';
    END IF;

    IF p_search_query != 'all' AND p_search_query REGEXP '[^a-zA-Z0-9 ]' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Niedozwolone znaki w zapytaniu';
    END IF;
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
    WHERE p_search_query = 'all' OR dg.nazwa LIKE CONCAT('%', p_search_query, '%')
    OR dgos.nazwa LIKE CONCAT('%', p_search_query, '%') AND LOWER(m.status) = 'oczekujący';
END//

DELIMITER ;

-- WIDOKI

DROP VIEW IF EXISTS aktywne_kursy;
CREATE VIEW aktywne_kursy AS
SELECT `km`.`id` AS `id`, `km`.`id_meczu` AS `id_meczu`, `km`.`nazwa_typu` AS `nazwa_typu`, `km`.`kurs` AS `kurs`, `km`.`status` AS `status`, `km`.`data_utworzenia` AS `data_utworzenia` 
FROM `Bukmacher`.`Kursy_Meczu` `km` 
WHERE (`km`.`status` = TRUE);

DROP VIEW IF EXISTS statystyki_uzytkownika;
CREATE VIEW statystyki_uzytkownika AS
SELECT `Bukmacher`.`Zaklad`.`id_uzytkownika` AS `id_uzytkownika`, 
       COUNT(CASE WHEN (`Bukmacher`.`Zaklad`.`wynik` = TRUE) THEN 1 END) AS `wygrane_zaklady`, 
       COUNT(CASE WHEN (`Bukmacher`.`Zaklad`.`wynik` = FALSE) THEN 1 END) AS `przegrane_zaklady`, 
       SUM(CASE WHEN (`Bukmacher`.`Zaklad`.`wynik` = TRUE) THEN `Bukmacher`.`Zaklad`.`potencjalna_wygrana` ELSE 0 END) AS `suma_wygranych`, 
       SUM(CASE WHEN (`Bukmacher`.`Zaklad`.`wynik` = FALSE) THEN `Bukmacher`.`Zaklad`.`kwota_postawiona` ELSE 0 END) AS `suma_przegranych`, 
       SUM(`Bukmacher`.`Zaklad`.`kwota_postawiona`) AS `suma_postawionych`, 
       ROUND(((COUNT(CASE WHEN (`Bukmacher`.`Zaklad`.`wynik` = TRUE) THEN 1 END) * 100.0) / NULLIF(COUNT(0),0)),2) AS `procent_wygranych` 
FROM `Bukmacher`.`Zaklad` 
WHERE (`Bukmacher`.`Zaklad`.`status_zakladu` IN ('Wygrany','Przegrany')) 
GROUP BY `Bukmacher`.`Zaklad`.`id_uzytkownika`;

DROP VIEW IF EXISTS szczegoly_meczu;
CREATE VIEW szczegoly_meczu AS
SELECT `m`.`id_meczu` AS `id_meczu`, 
       `dg`.`nazwa` AS `gospodarz`, 
       `dgos`.`nazwa` AS `gosc`, 
       `m`.`data_meczu` AS `data_meczu`, 
       `m`.`gole_gospodarzy` AS `gole_gospodarzy`, 
       `m`.`gole_gosci` AS `gole_gosci`, 
       `m`.`status` AS `status` 
FROM ((`Bukmacher`.`Mecz` `m` 
JOIN `Bukmacher`.`Druzyny` `dg` ON((`m`.`id_gospodarzy` = `dg`.`id_druzyny`))) 
JOIN `Bukmacher`.`Druzyny` `dgos` ON((`m`.`id_gosci` = `dgos`.`id_druzyny`)));

DROP VIEW IF EXISTS uzytkownik_historia_balansu;
CREATE VIEW uzytkownik_historia_balansu AS
SELECT `hs`.`id_uzytkownika` AS `id_uzytkownika`, 
       `hs`.`zmiana_balansu` AS `zmiana_balansu`, 
       `hs`.`saldo_po_operacji` AS `saldo_po_operacji`, 
       `t`.`typ_operacji` AS `typ_operacji`, 
       `t`.`data` AS `data`, 
       `t`.`kwota` AS `kwota` 
FROM (`Bukmacher`.`Historia_Salda` `hs` 
JOIN `Bukmacher`.`Transakcje` `t` ON((`hs`.`id_transakcji` = `t`.`id`)));

DROP VIEW IF EXISTS uzytkownik_szczegoly;
CREATE VIEW uzytkownik_szczegoly AS
SELECT `Bukmacher`.`Uzytkownik`.`id_uzytkownika` AS `id_uzytkownika`, 
       `Bukmacher`.`Uzytkownik`.`nazwa` AS `nazwa`, 
       `Bukmacher`.`Uzytkownik`.`haslo` AS `haslo`, 
       `Bukmacher`.`Uzytkownik`.`email` AS `email`, 
       `Bukmacher`.`Uzytkownik`.`balans` AS `balans`, 
       `Bukmacher`.`Uzytkownik`.`data_utworzenia` AS `data_utworzenia`, 
       `Bukmacher`.`Uzytkownik`.`rola` AS `rola`, 
       `Bukmacher`.`Uzytkownik`.`status_weryfikacji` AS `status_weryfikacji` 
FROM `Bukmacher`.`Uzytkownik`;

DROP VIEW IF EXISTS widok_uzytkownik_transakcje;
CREATE VIEW widok_uzytkownik_transakcje AS
SELECT `k`.`id_uzytkownika` AS `id_uzytkownika`, 
       `t`.`typ_operacji` AS `typ_operacji`, 
       SUM(`t`.`kwota`) AS `suma_kwota`, 
       COUNT(`t`.`id`) AS `liczba_transakcji` 
FROM (`Bukmacher`.`Transakcje` `t` 
JOIN `Bukmacher`.`Ksiegowosc` `k` ON((`t`.`id` = `k`.`id_transakcji`))) 
GROUP BY `k`.`id_uzytkownika`, `t`.`typ_operacji`;

-- Widok dla składu drużyny
DROP VIEW IF EXISTS sklad_druzyny;
CREATE VIEW sklad_druzyny AS
SELECT 
    z.id_zawodnika,
    z.imie,
    z.nazwisko,
    z.pozycja,
    z.numer_koszulki,
    d.id_druzyny,
    d.nazwa as nazwa_druzyny,
    CASE 
        WHEN z.pozycja = 'Trener' THEN 1
        ELSE 0
    END as is_trener
FROM Zawodnicy z
JOIN Druzyny d ON z.id_druzyny = d.id_druzyny;

DROP VIEW IF EXISTS podstawowa_jedenastka;
-- Widok dla podstawowej jedenastki
CREATE VIEW podstawowa_jedenastka AS
SELECT 
    z.id_zawodnika,
    z.imie,
    z.nazwisko,
    z.pozycja,
    z.numer_koszulki,
    d.id_druzyny,
    d.nazwa as nazwa_druzyny
FROM Zawodnicy z
JOIN Druzyny d ON z.id_druzyny = d.id_druzyny
WHERE z.pozycja != 'Trener'
ORDER BY 
    CASE z.pozycja
        WHEN 'Bramkarz' THEN 1
        WHEN 'Obrońca' THEN 2
        WHEN 'Pomocnik' THEN 3
        WHEN 'Napastnik' THEN 4
        ELSE 5
    END,
    z.numer_koszulki;

DELIMITER //

DROP PROCEDURE IF EXISTS dodaj_zdarzenie_meczu//
CREATE PROCEDURE dodaj_zdarzenie_meczu(
    IN p_id_zawodnika INT,
    IN p_id_meczu INT,
    IN p_czas_zdarzenia INT,
    IN p_typ_zdarzenia VARCHAR(50),
    IN p_dodatkowe_informacje VARCHAR(255)
)
BEGIN
    INSERT INTO Zdarzenia_w_meczu (
        id_zawodnika,
        id_meczu,
        czas_zdarzenia,
        typ_zdarzenia,
        dodatkowe_informacje
    ) VALUES (
        p_id_zawodnika,
        p_id_meczu,
        p_czas_zdarzenia,
        p_typ_zdarzenia,
        p_dodatkowe_informacje
    );
END//

DROP PROCEDURE IF EXISTS pobierz_zdarzenia_meczu//
CREATE PROCEDURE pobierz_zdarzenia_meczu(
    IN p_id_meczu INT
)
BEGIN
    SELECT * FROM zdarzenia_meczu_szczegoly
    WHERE id_meczu = p_id_meczu
    ORDER BY czas_zdarzenia;
END//

DROP PROCEDURE IF EXISTS pobierz_sklad_druzyny//
CREATE PROCEDURE pobierz_sklad_druzyny(
    IN p_id_druzyny INT
)
BEGIN
    -- Pobierz trenera (zakładając, że trener ma pozycję 'Trener' w tabeli Zawodnicy)
    SELECT 
        z.id_zawodnika,
        z.imie,
        z.nazwisko,
        z.pozycja,
        z.data_urodzenia
    FROM Zawodnicy z
    WHERE z.id_druzyny = p_id_druzyny 
    AND z.pozycja = 'Trener'
    LIMIT 1;
    
    -- Pobierz zawodników (wszystkich oprócz trenera)
    SELECT 
        z.id_zawodnika,
        z.imie,
        z.nazwisko,
        z.pozycja,
        z.numer_koszulki as numer,
        z.data_urodzenia
    FROM Zawodnicy z
    WHERE z.id_druzyny = p_id_druzyny 
    AND z.pozycja != 'Trener'
    ORDER BY z.numer_koszulki ASC;
END//


DROP EVENT IF EXISTS sprawdz_status_meczu//

CREATE EVENT sprawdz_status_meczu
ON SCHEDULE EVERY 1 MINUTE
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    CALL aktualizuj_status_meczu();
END //

DROP PROCEDURE IF EXISTS dezaktywuj_kurs//
CREATE PROCEDURE dezaktywuj_kurs(
    IN p_id_meczu INT,
    IN p_id_kursu INT
)
BEGIN
    DECLARE v_status_meczu VARCHAR(50);
    DECLARE v_ilosc_zakladow INT;
    DECLARE v_czy_aktywny BOOLEAN;
    
    -- Sprawdzenie statusu meczu
    SELECT status INTO v_status_meczu 
    FROM Mecz 
    WHERE id_meczu = p_id_meczu;
    
    -- Sprawdzenie czy kurs jest aktywny
    SELECT status INTO v_czy_aktywny
    FROM Kursy_Meczu
    WHERE id = p_id_kursu AND id_meczu = p_id_meczu;
    
    -- Sprawdzenie ilości aktywnych zakładów na ten kurs
    SELECT COUNT(*) INTO v_ilosc_zakladow
    FROM Zaklad
    WHERE kurs_meczu = p_id_kursu;
    
    -- Walidacja
    IF v_status_meczu IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Mecz nie istnieje';
    END IF;
    
    IF v_czy_aktywny IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Kurs nie istnieje dla tego meczu';
    END IF;
    
    IF NOT v_czy_aktywny THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Kurs jest już nieaktywny';
    END IF;
    
    IF v_status_meczu != 'Oczekujący' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nie można dezaktywować kursu - mecz już się rozpoczął lub zakończył';
    END IF;
    
    IF v_ilosc_zakladow > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nie można dezaktywować kursu - istnieją aktywne zakłady';
    END IF;
    
    -- Dezaktywacja kursu
    UPDATE Kursy_Meczu
    SET status = FALSE
    WHERE id = p_id_kursu AND id_meczu = p_id_meczu;
    
    -- Potwierdzenie wykonania
    SELECT 'Kurs został pomyślnie dezaktywowany' AS message;
    
END//
DELIMITER //

DROP PROCEDURE IF EXISTS aktualizuj_status_meczu//
CREATE PROCEDURE aktualizuj_status_meczu()
BEGIN
    DECLARE v_id_meczu BIGINT;
    DECLARE done INT DEFAULT FALSE;
    
    DECLARE cur_mecze CURSOR FOR
        SELECT id_meczu 
        FROM Mecz 
        WHERE status = 'Oczekujący' 
        AND data_meczu <= NOW();
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    START TRANSACTION;
    
    OPEN cur_mecze;
    
    read_loop: LOOP
        FETCH cur_mecze INTO v_id_meczu;
        
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        UPDATE Kursy_Meczu 
        SET status = FALSE 
        WHERE id_meczu = v_id_meczu 
        AND status = TRUE;
        
        CALL rozlicz_mecz(v_id_meczu);
        
    END LOOP;
    
    CLOSE cur_mecze;
    
    COMMIT;
END//
DELIMITER ;