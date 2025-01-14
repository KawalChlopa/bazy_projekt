CREATE TABLE `Użytkownik`(
    `id_użytkownika` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `nazwa` VARCHAR(50) NOT NULL,
    `hasło` VARCHAR(255) NOT NULL,
    `email` VARCHAR(50) NOT NULL,
    `balans` DECIMAL(8, 2) NOT NULL,
    `data_utworzenia` DATE NOT NULL,
    `rola` VARCHAR(50) NOT NULL,
    `status_weryfikacji` BOOLEAN NOT NULL
);
CREATE TABLE `Drużyny`(
    `id_drużyny` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `nazwa` VARCHAR(50) NOT NULL,
    `kraj` VARCHAR(50) NOT NULL,
    `rok_założenia` DATETIME NOT NULL,
    `stadion` VARCHAR(50) NOT NULL,
    `sezon` BIGINT NOT NULL
);
CREATE TABLE `Tansakcje`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `kwota` DECIMAL(8, 2) NOT NULL,
    `typ_operacji` VARCHAR(50) NOT NULL,
    `data` DATETIME NOT NULL
);
CREATE TABLE `Mecz`(
    `id_meczu` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_gospodarzy` BIGINT NOT NULL,
    `id_gości` BIGINT NOT NULL,
    `gole_gospodarzy` INT NOT NULL,
    `gole_gości` INT NOT NULL,
    `data_meczu` DATETIME NOT NULL,
    `sędzia` VARCHAR(255) NOT NULL,
    `zwycięstwo_gospodarzy` BOOLEAN NOT NULL,
    `zwycięstwo_gości` BOOLEAN NOT NULL,
    `status` VARCHAR(50) NOT NULL
);
CREATE TABLE `Statystyki Zawodników`(
    `id_statystyk` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_meczu` BIGINT NOT NULL,
    `id_zawodnika` BIGINT NOT NULL,
    `gole` INT NOT NULL,
    `żółte_kartki` INT NOT NULL,
    `czerwone_kartki` INT NOT NULL
);
CREATE TABLE `Zakład`(
    `id_zakładu` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_meczu` BIGINT NOT NULL,
    `id_użytkownika` BIGINT NOT NULL,
    `wynik` BOOLEAN NOT NULL,
    `kwota_postawiona` DECIMAL(8, 2) NOT NULL,
    `potencjalna_wygrana` DECIMAL(8, 2) NOT NULL,
    `status_zakładu` VARCHAR(50) NOT NULL,
    `data_postawienia` DATETIME NOT NULL,
    `kurs_meczu` BIGINT NOT NULL
);
CREATE TABLE `Zawodnicy`(
    `id_zawodnika` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_drużyny` BIGINT NOT NULL,
    `imię` VARCHAR(50) NOT NULL,
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
CREATE TABLE `Księgowość`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_użytkownika` BIGINT NOT NULL,
    `id_transakcji` BIGINT NOT NULL
);
CREATE TABLE `Historia Salda`(
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `id_użytkownika` BIGINT NOT NULL,
    `saldo_po_operacji` DECIMAL(8, 2) NOT NULL,
    `zmiana_balansu` DECIMAL(8, 2) NOT NULL,
    `id_transakcji` BIGINT NOT NULL
);
ALTER TABLE
    `Historia Salda` ADD CONSTRAINT `historia salda_id_transakcji_foreign` FOREIGN KEY(`id_transakcji`) REFERENCES `Tansakcje`(`id`);
ALTER TABLE
    `Księgowość` ADD CONSTRAINT `księgowość_id_transakcji_foreign` FOREIGN KEY(`id_transakcji`) REFERENCES `Tansakcje`(`id`);
ALTER TABLE
    `Mecz` ADD CONSTRAINT `mecz_id_gospodarzy_foreign` FOREIGN KEY(`id_gospodarzy`) REFERENCES `Drużyny`(`id_drużyny`);
ALTER TABLE
    `Statystyki Zawodników` ADD CONSTRAINT `statystyki zawodników_id_meczu_foreign` FOREIGN KEY(`id_meczu`) REFERENCES `Mecz`(`id_meczu`);
ALTER TABLE
    `Mecz` ADD CONSTRAINT `mecz_id_gości_foreign` FOREIGN KEY(`id_gości`) REFERENCES `Drużyny`(`id_drużyny`);
ALTER TABLE
    `Statystyki Zawodników` ADD CONSTRAINT `statystyki zawodników_id_zawodnika_foreign` FOREIGN KEY(`id_zawodnika`) REFERENCES `Zawodnicy`(`id_zawodnika`);
ALTER TABLE
    `Zakład` ADD CONSTRAINT `zakład_id_meczu_foreign` FOREIGN KEY(`id_meczu`) REFERENCES `Mecz`(`id_meczu`);
ALTER TABLE
    `Kursy_Meczu` ADD CONSTRAINT `kursy_meczu_id_meczu_foreign` FOREIGN KEY(`id_meczu`) REFERENCES `Mecz`(`id_meczu`);
ALTER TABLE
    `Historia Salda` ADD CONSTRAINT `historia salda_id_użytkownika_foreign` FOREIGN KEY(`id_użytkownika`) REFERENCES `Użytkownik`(`id_użytkownika`);
ALTER TABLE
    `Zakład` ADD CONSTRAINT `zakład_id_użytkownika_foreign` FOREIGN KEY(`id_użytkownika`) REFERENCES `Użytkownik`(`id_użytkownika`);
ALTER TABLE
    `Księgowość` ADD CONSTRAINT `księgowość_id_użytkownika_foreign` FOREIGN KEY(`id_użytkownika`) REFERENCES `Użytkownik`(`id_użytkownika`);
ALTER TABLE
    `Zakład` ADD CONSTRAINT `zakład_kurs_meczu_foreign` FOREIGN KEY(`kurs_meczu`) REFERENCES `Kursy_Meczu`(`id`);