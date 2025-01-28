-- Wstawianie danych do tabeli Uzytkownik
INSERT INTO Uzytkownik (nazwa, haslo, email, balans, data_utworzenia, rola, status_weryfikacji) VALUES
('jan_kowalski', '$2y$10$abc123', 'jan.kowalski@email.pl', 1000.00, '2024-01-01', 'Użytkownik', true),
('anna_nowak', '$2y$10$def456', 'anna.nowak@email.pl', 500.50, '2024-01-02', 'Użytkownik', true),
('admin_main', '$2y$10$ghi789', 'admin@bukmacher.pl', 0.00, '2023-12-01', 'Admin', true),
('marek_wisniewski', '$2y$10$jkl012', 'marek.wisniewski@email.pl', 2500.75, '2024-01-05', 'Użytkownik', true),
('zofia_lewandowska', '$2y$10$mno345', 'zofia.lewandowska@email.pl', 750.25, '2024-01-10', 'Użytkownik', false);
('admin', '$2b$12$WfKJiOBDuF9D4Vlm/nHWwOsUcIf7WLEW8Qd6dYi1klGbkoDtogF7G', 'admin@email.pl', 750.25, '2024-01-10', 'Admin', true);

-- Wstawianie danych do tabeli Druzyny
INSERT INTO Druzyny (nazwa, kraj, rok_zalozenia, stadion, sezon) VALUES
('Legia Warszawa', 'Polska', '1916-01-01 00:00:00', 'Stadion Wojska Polskiego', 2024),
('Lech Poznań', 'Polska', '1922-01-01 00:00:00', 'Stadion Miejski w Poznaniu', 2024),
('Widzew Łódź', 'Polska', '1910-01-01 00:00:00', 'Stadion Widzewa', 2024),
('Wisła Kraków', 'Polska', '1906-01-01 00:00:00', 'Stadion Miejski im. Henryka Reymana', 2024),
('Raków Częstochowa', 'Polska', '1921-01-01 00:00:00', 'Stadion Miejski w Częstochowie', 2024);

-- Wstawianie danych do tabeli Zawodnicy (włącznie z trenerami)
INSERT INTO Zawodnicy (id_druzyny, imie, nazwisko, pozycja, data_urodzenia, numer_koszulki) VALUES
-- Legia Warszawa
(1, 'Kacper', 'Tobiasz', 'bramkarz', '1999-11-04 00:00:00', 1),
(1, 'Artur', 'Jędrzejczyk', 'obrońca', '1987-11-04 00:00:00', 55),
(1, 'Yuri', 'Ribeiro', 'obrońca', '1997-01-24 00:00:00', 5),
(1, 'Steve', 'Kapuadi', 'obrońca', '1998-03-14 00:00:00', 15),
(1, 'Paweł', 'Wszołek', 'pomocnik', '1992-04-30 00:00:00', 13),
(1, 'Bartosz', 'Slisz', 'pomocnik', '1999-03-29 00:00:00', 99),
(1, 'Josue', 'Pesqueira', 'pomocnik', '1990-10-17 00:00:00', 27),
(1, 'Gil', 'Dias', 'pomocnik', '1996-09-28 00:00:00', 21),
(1, 'Tomas', 'Pekhart', 'napastnik', '1989-05-26 00:00:00', 9),
(1, 'Marc', 'Gual', 'napastnik', '1996-03-13 00:00:00', 11),
(1, 'Ernest', 'Muci', 'napastnik', '2001-03-19 00:00:00', 10),
(1, 'Kosta', 'Runjaić', 'trener', '1971-06-04 00:00:00', 0),

-- Lech Poznań
(2, 'Filip', 'Bednarek', 'bramkarz', '1992-09-26 00:00:00', 1),
(2, 'Joel', 'Pereira', 'obrońca', '1996-06-28 00:00:00', 2),
(2, 'Antonio', 'Milić', 'obrońca', '1994-03-10 00:00:00', 4),
(2, 'Barry', 'Douglas', 'obrońca', '1989-09-04 00:00:00', 3),
(2, 'Jesper', 'Karlström', 'pomocnik', '1995-06-21 00:00:00', 6),
(2, 'Radosław', 'Murawski', 'pomocnik', '1994-04-22 00:00:00', 8),
(2, 'Dino', 'Hotić', 'pomocnik', '1995-07-26 00:00:00', 10),
(2, 'Kristoffer', 'Velde', 'pomocnik', '1998-10-27 00:00:00', 7),
(2, 'Filip', 'Marchwiński', 'pomocnik', '2002-01-10 00:00:00', 24),
(2, 'Mikael', 'Ishak', 'napastnik', '1993-03-31 00:00:00', 9),
(2, 'Artur', 'Sobiech', 'napastnik', '1990-06-12 00:00:00', 19),
(2, 'Mariusz', 'Rumak', 'trener', '1977-06-11 00:00:00', 0),

-- Widzew Łódź
(3, 'Henrich', 'Ravas', 'bramkarz', '1997-08-12 00:00:00', 1),
(3, 'Mateusz', 'Żyro', 'obrońca', '1993-09-20 00:00:00', 2),
(3, 'Juan', 'Ibiza', 'obrońca', '1994-01-15 00:00:00', 4),
(3, 'Luis', 'Silva', 'obrońca', '1993-03-24 00:00:00', 3),
(3, 'Marek', 'Hanousek', 'pomocnik', '1991-08-06 00:00:00', 6),
(3, 'Dawid', 'Tkacz', 'pomocnik', '1999-07-23 00:00:00', 8),
(3, 'Jakub', 'Sypek', 'pomocnik', '2003-01-15 00:00:00', 10),
(3, 'Fran', 'Álvarez', 'pomocnik', '1995-05-16 00:00:00', 7),
(3, 'Ernest', 'Terpiłowski', 'pomocnik', '2001-04-25 00:00:00', 11),
(3, 'Jordi', 'Sánchez', 'napastnik', '1995-09-30 00:00:00', 9),
(3, 'Imad', 'Rondić', 'napastnik', '1999-02-28 00:00:00', 19),
(3, 'Daniel', 'Myśliwiec', 'trener', '1987-03-15 00:00:00', 0),

-- Wisła Kraków
(4, 'Kamil', 'Broda', 'bramkarz', '1995-05-17 00:00:00', 1),
(4, 'David', 'Junca', 'obrońca', '1993-11-20 00:00:00', 3),
(4, 'Joseph', 'Colley', 'obrońca', '1999-09-08 00:00:00', 4),
(4, 'Igor', 'Łasicki', 'obrońca', '1995-06-27 00:00:00', 2),
(4, 'Kacper', 'Duda', 'pomocnik', '2000-03-15 00:00:00', 6),
(4, 'Michał', 'Żyro', 'pomocnik', '1992-09-20 00:00:00', 8),
(4, 'Angel', 'Rodado', 'pomocnik', '1997-01-12 00:00:00', 10),
(4, 'Mateusz', 'Młyński', 'pomocnik', '2001-01-02 00:00:00', 7),
(4, 'Szymon', 'Sobczak', 'napastnik', '1999-04-09 00:00:00', 9),
(4, 'Goku', 'Machida', 'napastnik', '1997-08-23 00:00:00', 11),
(4, 'Patryk', 'Plewka', 'pomocnik', '2000-07-14 00:00:00', 14),
(4, 'Albert', 'Rude', 'trener', '1988-04-22 00:00:00', 0),

-- Raków Częstochowa
(5, 'Vladan', 'Kovačević', 'bramkarz', '1998-04-11 00:00:00', 1),
(5, 'Stratos', 'Svarnas', 'obrońca', '1997-11-11 00:00:00', 2),
(5, 'Zoran', 'Arsenić', 'obrońca', '1994-06-02 00:00:00', 4),
(5, 'Milan', 'Rundić', 'obrońca', '1992-02-28 00:00:00', 3),
(5, 'Gustav', 'Berggren', 'pomocnik', '1997-09-07 00:00:00', 6),
(5, 'Ben', 'Lederman', 'pomocnik', '2000-05-08 00:00:00', 8),
(5, 'Władysław', 'Koczerhin', 'pomocnik', '1998-01-30 00:00:00', 10),
(5, 'John', 'Yeboah', 'pomocnik', '2000-06-23 00:00:00', 7),
(5, 'Bartosz', 'Nowak', 'pomocnik', '1993-08-25 00:00:00', 11),
(5, 'Łukasz', 'Zwoliński', 'napastnik', '1993-02-24 00:00:00', 9),
(5, 'Ante', 'Crnac', 'napastnik', '1996-10-03 00:00:00', 19),
(5, 'Dawid', 'Szwarga', 'trener', '1990-03-12 00:00:00', 0);

-- Wstawianie danych do tabeli Mecz
INSERT INTO Mecz (id_gospodarzy, id_gosci, gole_gospodarzy, gole_gosci, data_meczu, sedzia, zwyciestwo_gospodarzy, zwyciestwo_gosci, status) VALUES
-- Mecze historyczne
(1, 2, 2, 1, '2024-02-01 20:00:00', 'Szymon Marciniak', true, false, 'zakończony'),
(3, 4, 0, 0, '2024-02-08 18:00:00', 'Tomasz Musiał', false, false, 'zakończony'),
(5, 1, 1, 3, '2024-02-15 20:30:00', 'Paweł Raczkowski', false, true, 'zakończony'),
(2, 3, 2, 0, '2024-03-01 17:30:00', 'Daniel Stefański', true, false, 'zaplanowany'),
(4, 5, 0, 0, '2024-03-08 20:00:00', 'Piotr Lasyk', false, false, 'zaplanowany'),

-- Mecze w 2024
(1, 3, 0, 0, '2024-04-05 20:00:00', 'Szymon Marciniak', false, false, 'zaplanowany'),
(2, 4, 0, 0, '2024-04-12 17:30:00', 'Tomasz Musiał', false, false, 'zaplanowany'),
(5, 2, 0, 0, '2024-04-19 20:30:00', 'Paweł Raczkowski', false, false, 'zaplanowany'),
(3, 1, 0, 0, '2024-04-26 18:00:00', 'Daniel Stefański', false, false, 'zaplanowany'),
(4, 3, 0, 0, '2024-05-03 20:00:00', 'Piotr Lasyk', false, false, 'zaplanowany'),
(2, 5, 0, 0, '2024-05-10 17:30:00', 'Szymon Marciniak', false, false, 'zaplanowany'),
(1, 4, 0, 0, '2024-05-17 20:30:00', 'Tomasz Kwiatkowski', false, false, 'zaplanowany'),
(3, 5, 0, 0, '2024-05-24 18:00:00', 'Damian Sylwestrzak', false, false, 'zaplanowany'),
(2, 1, 0, 0, '2024-05-31 20:00:00', 'Bartosz Frankowski', false, false, 'zaplanowany'),
(5, 4, 0, 0, '2024-06-07 17:30:00', 'Jarosław Przybył', false, false, 'zaplanowany'),

-- Nowe mecze w 2025
(1, 2, 0, 0, '2025-02-07 20:00:00', 'Szymon Marciniak', false, false, 'Oczekujący'),
(3, 4, 0, 0, '2025-02-14 18:00:00', 'Tomasz Musiał', false, false, 'Oczekujący'),
(5, 1, 0, 0, '2025-02-21 20:30:00', 'Paweł Raczkowski', false, false, 'Oczekujący'),
(2, 3, 0, 0, '2025-02-28 17:30:00', 'Daniel Stefański', false, false, 'Oczekujący'),
(4, 5, 0, 0, '2025-03-07 20:00:00', 'Piotr Lasyk', false, false, 'Oczekujący'),
(1, 3, 0, 0, '2025-03-14 20:00:00', 'Tomasz Kwiatkowski', false, false, 'Oczekujący'),
(2, 4, 0, 0, '2025-03-21 17:30:00', 'Damian Sylwestrzak', false, false, 'Oczekujący'),
(5, 2, 0, 0, '2025-03-28 20:30:00', 'Bartosz Frankowski', false, false, 'Oczekujący'),
(3, 1, 0, 0, '2025-04-04 18:00:00', 'Jarosław Przybył', false, false, 'Oczekujący'),
(4, 3, 0, 0, '2025-04-11 20:00:00', 'Szymon Marciniak', false, false, 'Oczekujący'),
(2, 5, 0, 0, '2025-04-18 17:30:00', 'Tomasz Musiał', false, false, 'Oczekujący'),
(1, 4, 0, 0, '2025-04-25 20:30:00', 'Paweł Raczkowski', false, false, 'Oczekujący'),
(3, 5, 0, 0, '2025-05-02 18:00:00', 'Daniel Stefański', false, false, 'Oczekujący'),
(2, 1, 0, 0, '2025-05-09 20:00:00', 'Piotr Lasyk', false, false, 'Oczekujący'),
(5, 4, 0, 0, '2025-05-16 17:30:00', 'Tomasz Kwiatkowski', false, false, 'Oczekujący');

-- Wstawianie danych do tabeli Statystyki_Zawodnikow
INSERT INTO Statystyki_Zawodnikow (id_meczu, id_zawodnika, gole, zolte_kartki, czerwone_kartki) VALUES
(1, 2, 1, 1, 0),
(1, 4, 1, 0, 0),
(2, 5, 0, 1, 0),
(3, 2, 2, 0, 0),
(3, 1, 0, 0, 0);

-- Wstawianie danych do tabeli Kursy_Meczu
INSERT INTO Kursy_Meczu (id_meczu, nazwa_typu, kurs, status, data_utworzenia) VALUES
(1, 'wygrana_gospodarzy', 2.10, true, '2024-01-31 12:00:00'),
(1, 'wygrana_gosci', 3.50, true, '2024-01-31 12:00:00'),
(1, 'remis', 3.20, true, '2024-01-31 12:00:00'),
(2, 'wygrana_gospodarzy', 2.50, true, '2024-02-07 12:00:00'),
(2, 'wygrana_gosci', 2.80, true, '2024-02-07 12:00:00');

-- Wstawianie danych do tabeli Transakcje
INSERT INTO Transakcje (kwota, typ_operacji, data) VALUES
(100.00, 'wpłata', '2024-01-15 10:00:00'),
(50.00, 'zakład', '2024-01-16 15:30:00'),
(200.00, 'wygrana', '2024-02-02 22:00:00'),
(75.00, 'wpłata', '2024-02-05 14:20:00'),
(25.00, 'zakład', '2024-02-10 18:45:00');

-- Wstawianie danych do tabeli Ksiegowosc
INSERT INTO Ksiegowosc (id_uzytkownika, id_transakcji) VALUES
(1, 1),
(1, 2),
(2, 3),
(3, 4),
(4, 5);

-- Wstawianie danych do tabeli Historia_Salda
INSERT INTO Historia_Salda (id_uzytkownika, saldo_po_operacji, zmiana_balansu, id_transakcji) VALUES
(1, 1100.00, 100.00, 1),
(1, 1050.00, -50.00, 2),
(2, 700.50, 200.00, 3),
(3, 75.00, 75.00, 4),
(4, 2475.75, -25.00, 5);

-- Wstawianie danych do tabeli Zaklad
INSERT INTO Zaklad (id_meczu, id_uzytkownika, wynik, kwota_postawiona, potencjalna_wygrana, status_zakladu, data_postawienia, kurs_meczu) VALUES
(1, 1, true, 50.00, 105.00, 'wygrany', '2024-01-31 15:30:00', 1),
(1, 2, false, 25.00, 87.50, 'przegrany', '2024-01-31 16:45:00', 2),
(2, 3, false, 100.00, 250.00, 'przegrany', '2024-02-07 12:30:00', 4),
(3, 4, true, 75.00, 187.50, 'wygrany', '2024-02-14 20:15:00', 3),
(4, 5, false, 50.00, 140.00, 'aktywny', '2024-02-28 18:00:00', 5);