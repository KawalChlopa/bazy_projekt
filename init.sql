CREATE TABLE `Uzytkownik`(
    `id_uzytkownika` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `nazwa` VARCHAR(50) NOT NULL,
    `haslo` VARCHAR(255) NOT NULL,
    `email` VARCHAR(50) NOT NULL,
    `balans` DECIMAL(8, 2) NOT NULL,
    `data_utworzenia` DATE NOT NULL,
    `rola` VARCHAR(50) NOT NULL,
    `status_weryfikacji` BOOLEAN NOT NULL
);
CREATE TABLE `Druzyny`(
    `id_druzyny` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `nazwa` VARCHAR(50) NOT NULL,
    `kraj` VARCHAR(50) NOT NULL,
    `rok_zalozenia` DATETIME NOT NULL,
    `stadion` VARCHAR(50) NOT NULL,
    `sezon` BIGINT NOT NULL
);
CREATE TABLE `Transakcje`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `kwota` DECIMAL(8, 2) NOT NULL,
    `typ_operacji` VARCHAR(50) NOT NULL,
    `data` DATETIME NOT NULL
);
CREATE TABLE `Mecz`(
    `id_meczu` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_gospodarzy` BIGINT NOT NULL,
    `id_gosci` BIGINT NOT NULL,
    `gole_gospodarzy` INT NOT NULL,
    `gole_gosci` INT NOT NULL,
    `data_meczu` DATETIME NOT NULL,
    `sedzia` VARCHAR(255) NOT NULL,
    `zwyciestwo_gospodarzy` BOOLEAN NOT NULL,
    `zwyciestwo_gosci` BOOLEAN NOT NULL,
    `status` VARCHAR(50) NOT NULL
);
CREATE TABLE `Statystyki_Zawodnikow`(
    `id_statystyk` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_meczu` BIGINT NOT NULL,
    `id_zawodnika` BIGINT NOT NULL,
    `gole` INT NOT NULL,
    `zolte_kartki` INT NOT NULL,
    `czerwone_kartki` INT NOT NULL
);
CREATE TABLE `Zaklad`(
    `id_zakladu` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_meczu` BIGINT NOT NULL,
    `id_uzytkownika` BIGINT NOT NULL,
    `wynik` BOOLEAN NOT NULL,
    `kwota_postawiona` DECIMAL(8, 2) NOT NULL,
    `potencjalna_wygrana` DECIMAL(8, 2) NOT NULL,
    `status_zakladu` VARCHAR(50) NOT NULL,
    `data_postawienia` DATETIME NOT NULL,
    `kurs_meczu` BIGINT NOT NULL
);
CREATE TABLE `Zawodnicy`(
    `id_zawodnika` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_druzyny` BIGINT NOT NULL,
    `imie` VARCHAR(50) NOT NULL,
    `nazwisko` VARCHAR(50) NOT NULL,
    `pozycja` VARCHAR(255) NOT NULL,
    `data_urodzenia` DATETIME NOT NULL,
    `numer_koszulki` INT NOT NULL
);
CREATE TABLE `Kursy_Meczu`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_meczu` BIGINT NOT NULL,
    `nazwa_typu` VARCHAR(255) NOT NULL,
    `kurs` DECIMAL(8, 2) NOT NULL,
    `status` BOOLEAN NOT NULL,
    `data_utworzenia` DATETIME NOT NULL
);
CREATE TABLE `Ksiegowosc`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_uzytkownika` BIGINT NOT NULL,
    `id_transakcji` BIGINT NOT NULL
);
CREATE TABLE `Zdarzenia_w_meczu`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_zawodnika` BIGINT NOT NULL,
    `id_meczu` BIGINT NOT NULL,
    `czas_zdarzenia` INT NOT NULL,
    `typ_zdarzenia` VARCHAR(50) NOT NULL,
    `dodatkowe_informacje` VARCHAR(255) NOT NULL
);
CREATE TABLE `Historia_Salda`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_uzytkownika` BIGINT NOT NULL,
    `saldo_po_operacji` DECIMAL(8, 2) NOT NULL,
    `zmiana_balansu` DECIMAL(8, 2) NOT NULL,
    `id_transakcji` BIGINT NOT NULL
);
ALTER TABLE
    `Historia_Salda` ADD CONSTRAINT `historia_salda_id_transakcji_foreign` FOREIGN KEY(`id_transakcji`) REFERENCES `Transakcje`(`id`);
ALTER TABLE
    `Mecz` ADD CONSTRAINT `mecz_data_meczu_foreign` FOREIGN KEY(`data_meczu`) REFERENCES `Kursy_Meczu`(`id_meczu`);
ALTER TABLE
    `Zdarzenia_w_meczu` ADD CONSTRAINT `zdarzenia_w_meczu_id_zawodnika_foreign` FOREIGN KEY(`id_zawodnika`) REFERENCES `Zawodnicy`(`id_zawodnika`);
ALTER TABLE
    `Zdarzenia_w_meczu` ADD CONSTRAINT `zdarzenia_w_meczu_id_meczu_foreign` FOREIGN KEY(`id_meczu`) REFERENCES `Mecz`(`id_meczu`);
ALTER TABLE
    `Ksiegowosc` ADD CONSTRAINT `ksiegowosc_id_transakcji_foreign` FOREIGN KEY(`id_transakcji`) REFERENCES `Transakcje`(`id`);
ALTER TABLE
    `Mecz` ADD CONSTRAINT `mecz_id_gospodarzy_foreign` FOREIGN KEY(`id_gospodarzy`) REFERENCES `Druzyny`(`id_druzyny`);
ALTER TABLE
    `Statystyki_Zawodnikow` ADD CONSTRAINT `statystyki_zawodnikow_id_meczu_foreign` FOREIGN KEY(`id_meczu`) REFERENCES `Mecz`(`id_meczu`);
ALTER TABLE
    `Mecz` ADD CONSTRAINT `mecz_id_gosci_foreign` FOREIGN KEY(`id_gosci`) REFERENCES `Druzyny`(`id_druzyny`);
ALTER TABLE
    `Statystyki_Zawodnikow` ADD CONSTRAINT `statystyki_zawodnikow_id_zawodnika_foreign` FOREIGN KEY(`id_zawodnika`) REFERENCES `Zawodnicy`(`id_zawodnika`);
ALTER TABLE
    `Zaklad` ADD CONSTRAINT `zaklad_id_meczu_foreign` FOREIGN KEY(`id_meczu`) REFERENCES `Mecz`(`id_meczu`);
ALTER TABLE
    `Historia_Salda` ADD CONSTRAINT `historia_salda_id_uzytkownika_foreign` FOREIGN KEY(`id_uzytkownika`) REFERENCES `Uzytkownik`(`id_uzytkownika`);
ALTER TABLE
    `Zaklad` ADD CONSTRAINT `zaklad_id_uzytkownika_foreign` FOREIGN KEY(`id_uzytkownika`) REFERENCES `Uzytkownik`(`id_uzytkownika`);
ALTER TABLE
    `Ksiegowosc` ADD CONSTRAINT `ksiegowosc_id_uzytkownika_foreign` FOREIGN KEY(`id_uzytkownika`) REFERENCES `Uzytkownik`(`id_uzytkownika`);
ALTER TABLE
    `Zaklad` ADD CONSTRAINT `zaklad_kurs_meczu_foreign` FOREIGN KEY(`kurs_meczu`) REFERENCES `Kursy_Meczu`(`id`);
