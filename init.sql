CREATE TABLE Uzytkownik(
    id_uzytkownika INT AUTO_INCREMENT PRIMARY KEY,
    nazwa VARCHAR(50), 
    haslo VARCHAR(50), 
    email VARCHAR(50), 
    balans DECIMAL(10,2), 
    data_utworzenia DATETIME
);

CREATE TABLE Tranzakcje(
    id_tranzakcji INT AUTO_INCREMENT PRIMARY KEY,
    id_uzytkownika INT,
    FOREIGN KEY (id_uzytkownika) REFERENCES Uzytkownik(id_uzytkownika),
    kwota DECIMAL(10,2),
    typ VARCHAR(50),
    data DATETIME
);

CREATE TABLE Druzyny(
    id_druzyny INT PRIMARY KEY,
    nazwa VARCHAR(50),
    kraj VARCHAR(50),
    rok_zalozenia INT,
    stadion VARCHAR(200)
);

CREATE TABLE Zawodnicy(
    id_zawodnika INT PRIMARY KEY,
    id_druzyny INT,
    FOREIGN KEY (id_druzyny) REFERENCES Druzyny(id_druzyny),
    imie VARCHAR(50),
    nazwisko VARCHAR(50),
    pozycja VARCHAR(50),
    data_urodzenia DATETIME,
    numer_koszulka INT
);

CREATE TABLE Mecz(
    id_meczu INT PRIMARY KEY,
    id_gospodarzy INT,
    FOREIGN KEY (id_gospodarzy) REFERENCES Druzyny(id_druzyny),
    id_gosci INT,
    FOREIGN KEY (id_gosci) REFERENCES Druzyny(id_druzyny),
    gole_gospodarzy INT,
    gole_gosci INT,
    data_meczu DATETIME,
    sedzia VARCHAR(100),
    zwyciestwo_gospodarzy BOOLEAN,
    zwyciestwo_gosci BOOLEAN
);

CREATE TABLE Statystyki_Zawodnikow(
    id_statystyk INT AUTO_INCREMENT PRIMARY KEY,
    id_meczu INT,
    FOREIGN KEY (id_meczu) REFERENCES Mecz(id_meczu),
    id_zawodnika INT,
    FOREIGN KEY (id_zawodnika) REFERENCES Zawodnicy(id_zawodnika),
    gole INT,
    asysty INT,
    zolte_kartki INT,
    czerwone_kartki INT
);

CREATE TABLE Kursy(
    id_kursy INT AUTO_INCREMENT PRIMARY KEY,
    id_meczu INT,
    FOREIGN KEY (id_meczu) REFERENCES Mecz(id_meczu),
    wynik VARCHAR(50),
    wartosc_kursy DECIMAL(10,2)
);

CREATE TABLE Zaklady(
    id_zakladu INT AUTO_INCREMENT PRIMARY KEY,
    id_uzytkownika INT,
    FOREIGN KEY (id_uzytkownika) REFERENCES Uzytkownik(id_uzytkownika),
    id_meczu INT,
    FOREIGN KEY (id_meczu) REFERENCES Mecz(id_meczu),
    wynik BOOLEAN,
    kwota_postawiona DECIMAL(10,2),
    potencjalna_wygrana DECIMAL(10,2),
    status_zakladu VARCHAR(50),
    data_postawienia DATETIME
);

CREATE TABLE Historia_zakladow(
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_zakladu INT,
    FOREIGN KEY (id_zakladu) REFERENCES Zaklady(id_zakladu),
    id_uzytkownika INT,
    FOREIGN KEY (id_uzytkownika) REFERENCES Uzytkownik(id_uzytkownika)
);
