INSERT INTO Uzytkownik (
    nazwa,
    haslo,
    email,
    balans,
    data_utworzenia,
    rola,
    status_weryfikacji
) VALUES (
    'admin',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewqkfQdzE/qbop.O', -- zahaszowane 'admin123'
    'admin@bukmacher.com',
    100.00,
    NOW(),
    'Admin',
    TRUE
);

INSERT INTO Mecz (id_gospodarzy, id_gosci, gole_gospodarzy, gole_gosci, data_meczu, sedzia, zwyciestwo_gospodarzy, zwyciestwo_gosci, status) VALUES
(1, 3, 0, 0, '2025-01-25 20:45:00', 'Szymon Marciniak', false, false, 'Oczekujący'),  -- Barcelona vs Bayern
(2, 5, 0, 0, '2025-01-28 21:00:00', 'Danny Makkelie', false, false, 'Oczekujący'),    -- Real vs PSG
(4, 1, 0, 0, '2025-02-05 20:45:00', 'Clement Turpin', false, false, 'Oczekujący'),    -- ManU vs Barcelona
(5, 3, 0, 0, '2025-02-12 21:00:00', 'Felix Zwayer', false, false, 'Oczekujący'),      -- PSG vs Bayern
(2, 4, 0, 0, '2025-02-19 20:45:00', 'Gianluca Rocchi', false, false, 'Oczekujący'),   -- Real vs ManU
(3, 1, 0, 0, '2025-02-26 21:00:00', 'Slavko Vincic', false, false, 'Oczekujący'),     -- Bayern vs Barcelona
(5, 2, 0, 0, '2025-03-02 20:45:00', 'Antonio Mateu Lahoz', false, false, 'Oczekujący'), -- PSG vs Real
(1, 4, 0, 0, '2025-03-15 20:45:00', 'Michael Oliver', false, false, 'Oczekujący'),     -- Barcelona vs ManU
(3, 5, 0, 0, '2025-03-22 21:00:00', 'Felix Brych', false, false, 'Oczekujący'),        -- Bayern vs PSG
(2, 1, 0, 0, '2025-04-05 20:45:00', 'Daniele Orsato', false, false, 'Oczekujący');     -- Real vs Barcelona


-- Wstawianie kursów dla nowych meczów
INSERT INTO Kursy_Meczu (id_meczu, nazwa_typu, kurs, status, data_utworzenia) VALUES
-- Barcelona vs Bayern
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 1 AND id_gosci = 3 AND data_meczu = '2025-01-25 20:45:00'), 'zwycięstwo gospodarzy', 2.25, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 1 AND id_gosci = 3 AND data_meczu = '2025-01-25 20:45:00'), 'remis', 3.40, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 1 AND id_gosci = 3 AND data_meczu = '2025-01-25 20:45:00'), 'zwycięstwo gości', 2.90, true, NOW()),

-- Real vs PSG
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 2 AND id_gosci = 5 AND data_meczu = '2025-01-28 21:00:00'), 'zwycięstwo gospodarzy', 1.95, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 2 AND id_gosci = 5 AND data_meczu = '2025-01-28 21:00:00'), 'remis', 3.60, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 2 AND id_gosci = 5 AND data_meczu = '2025-01-28 21:00:00'), 'zwycięstwo gości', 3.40, true, NOW()),

-- ManU vs Barcelona
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 4 AND id_gosci = 1 AND data_meczu = '2025-02-05 20:45:00'), 'zwycięstwo gospodarzy', 2.40, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 4 AND id_gosci = 1 AND data_meczu = '2025-02-05 20:45:00'), 'remis', 3.30, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 4 AND id_gosci = 1 AND data_meczu = '2025-02-05 20:45:00'), 'zwycięstwo gości', 2.70, true, NOW()),

-- PSG vs Bayern
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 5 AND id_gosci = 3 AND data_meczu = '2025-02-12 21:00:00'), 'zwycięstwo gospodarzy', 2.15, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 5 AND id_gosci = 3 AND data_meczu = '2025-02-12 21:00:00'), 'remis', 3.50, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 5 AND id_gosci = 3 AND data_meczu = '2025-02-12 21:00:00'), 'zwycięstwo gości', 3.00, true, NOW()),

-- Real vs ManU
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 2 AND id_gosci = 4 AND data_meczu = '2025-02-19 20:45:00'), 'zwycięstwo gospodarzy', 1.85, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 2 AND id_gosci = 4 AND data_meczu = '2025-02-19 20:45:00'), 'remis', 3.70, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 2 AND id_gosci = 4 AND data_meczu = '2025-02-19 20:45:00'), 'zwycięstwo gości', 3.80, true, NOW()),

-- Bayern vs Barcelona
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 3 AND id_gosci = 1 AND data_meczu = '2025-02-26 21:00:00'), 'zwycięstwo gospodarzy', 2.05, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 3 AND id_gosci = 1 AND data_meczu = '2025-02-26 21:00:00'), 'remis', 3.45, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 3 AND id_gosci = 1 AND data_meczu = '2025-02-26 21:00:00'), 'zwycięstwo gości', 3.20, true, NOW()),

-- PSG vs Real
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 5 AND id_gosci = 2 AND data_meczu = '2025-03-02 20:45:00'), 'zwycięstwo gospodarzy', 2.30, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 5 AND id_gosci = 2 AND data_meczu = '2025-03-02 20:45:00'), 'remis', 3.40, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 5 AND id_gosci = 2 AND data_meczu = '2025-03-02 20:45:00'), 'zwycięstwo gości', 2.80, true, NOW()),

-- Barcelona vs ManU
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 1 AND id_gosci = 4 AND data_meczu = '2025-03-15 20:45:00'), 'zwycięstwo gospodarzy', 1.95, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 1 AND id_gosci = 4 AND data_meczu = '2025-03-15 20:45:00'), 'remis', 3.50, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 1 AND id_gosci = 4 AND data_meczu = '2025-03-15 20:45:00'), 'zwycięstwo gości', 3.60, true, NOW()),

-- Bayern vs PSG
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 3 AND id_gosci = 5 AND data_meczu = '2025-03-22 21:00:00'), 'zwycięstwo gospodarzy', 2.10, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 3 AND id_gosci = 5 AND data_meczu = '2025-03-22 21:00:00'), 'remis', 3.45, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 3 AND id_gosci = 5 AND data_meczu = '2025-03-22 21:00:00'), 'zwycięstwo gości', 3.20, true, NOW()),

-- Real vs Barcelona (El Clasico)
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 2 AND id_gosci = 1 AND data_meczu = '2025-04-05 20:45:00'), 'zwycięstwo gospodarzy', 2.00, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 2 AND id_gosci = 1 AND data_meczu = '2025-04-05 20:45:00'), 'remis', 3.30, true, NOW()),
((SELECT id_meczu FROM Mecz WHERE id_gospodarzy = 2 AND id_gosci = 1 AND data_meczu = '2025-04-05 20:45:00'), 'zwycięstwo gości', 3.40, true, NOW());
