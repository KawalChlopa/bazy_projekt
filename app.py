from flask import Flask, request, jsonify
from datetime import datetime
from decimal import Decimal, DecimalException
from flask_cors import CORS
import bcrypt
import mysql.connector
from difflib import SequenceMatcher
from email.mime.text import MIMEText
import smtplib
from itsdangerous import URLSafeTimedSerializer, SignatureExpired, BadSignature

app = Flask(__name__)
app.config['SECRET_KEY'] = 'bazy1234'
CORS(app)

# Parametry do łączenia się z bazą
UZYTKOWNIK = "root"
HASLO = "bazy123"
HOST = "localhost"
BAZA_DANYCH = "Bukmacher"
PORT = "3306"

# Łączenie z bazą
def get_db_connection():
    return mysql.connector.connect(
        host=HOST,
        user=UZYTKOWNIK,
        password=HASLO,
        database=BAZA_DANYCH
    )

# Sprawdzanie łączności
def test_db_connection():
    try:
        conn = get_db_connection()
        conn.close()
        print("Połączenie z bazą danych jest aktywne.")
        return True
    except Exception as e:
        print(f"Błąd połączenia z bazą danych: {str(e)}")
        return False

# Klasa użytkownik
class Uzytkownik:
    def __init__(self, id_uzytkownika=None, nazwa=None, haslo=None, email=None, balans=0.0, data_utworzenia=None, rola='Uzytkownik', status_weryfikacji=False):
        self.id_uzytkownika = id_uzytkownika
        self.nazwa = nazwa
        self.haslo = haslo
        self.email = email
        self.balans = Decimal(str(balans))
        self.data_utworzenia = data_utworzenia or datetime.now()
        self.rola = rola
        self.status_weryfikacji = status_weryfikacji

    @staticmethod
    def hash_password(haslo):
        salt = bcrypt.gensalt()
        hashed_password = bcrypt.hashpw(haslo.encode('utf-8'), salt)
        return hashed_password.decode('utf-8')

    @staticmethod
    def verify_password(haslo, hashed_password):
        return bcrypt.checkpw(haslo.encode('utf-8'), hashed_password.encode('utf-8'))

    # Pobiera listę wszystkich użytkowników
    @staticmethod
    def get_all_users():
        try:
            conn = get_db_connection()
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM uzytkownik_szczegoly")
            users = cursor.fetchall()
            return [Uzytkownik(**user) for user in users]
        finally:
            cursor.close()
            conn.close()

    def save(self):
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Aktualizacja istniejącego użytkownika
            if self.id_uzytkownika:
                cursor.execute("""
                    UPDATE Uzytkownik 
                    SET nazwa = %s, haslo = %s, email = %s, balans = %s, 
                        rola = %s, status_weryfikacji = %s 
                    WHERE id_uzytkownika = %s
                """, (self.nazwa, self.hash_password(self.haslo), self.email, self.balans, 
                     self.rola, self.status_weryfikacji, self.id_uzytkownika))
            # Tworzenie nowego użytkownika
            else:
                args = (self.nazwa, self.hash_password(self.haslo), self.email, self.balans, self.rola, self.status_weryfikacji)
                result_args = cursor.callproc('tworzenie_uzytkownika', args)

                for result in cursor.stored_results():
                    row = result.fetchone()
                    if row:
                        self.id_uzytkownika = row[0]
                
            conn.commit()
            return self.id_uzytkownika

        except mysql.connector.Error as err:
            raise Exception(f"Database error: {err}")
        finally:
            cursor.close()
            conn.close()

    # Pobiera użytkownika po ID
    @staticmethod
    def get_by_id(id_uzytkownika):
        try:
            conn = get_db_connection()
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM uzytkownik_szczegoly WHERE id_uzytkownika = %s", (id_uzytkownika,))
            user = cursor.fetchone()
            return Uzytkownik(**user) if user else None
        finally:
            cursor.close()
            conn.close()
    
    @staticmethod
    def get_by_name(nazwa):
        try:
            conn = get_db_connection()
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM uzytkownik_szczegoly WHERE nazwa = %s", (nazwa,))
            user = cursor.fetchone()
            return Uzytkownik(**user) if user else None
        finally:
            cursor.close()
            conn.close()

    def delete(self):
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.callproc('usun_uzytkownika', (self.id_uzytkownika,))
            conn.commit()
        finally:
            cursor.close()
            conn.close()

    # Zamienia na słownik
    def to_dict(self):
        return {
            'id_uzytkownika': self.id_uzytkownika,
            'nazwa': self.nazwa,
            'haslo': self.haslo,
            'email': self.email,
            'balans': str(self.balans),
            'data_utworzenia': self.data_utworzenia.isoformat() if self.data_utworzenia else None,
            'rola': self.rola,
            'status_weryfikacji': self.status_weryfikacji
        }

# Tworzenie konta
@app.route("/api/konto", methods=['POST'])
def create_account():
    dane = request.json
    try:
        if Uzytkownik.get_by_name(dane['nazwa']):
            return jsonify({'error': 'Użytkownik o takiej nazwie już istnieje'}), 400

        nowe_konto = Uzytkownik(
            nazwa=dane['nazwa'],
            haslo=dane['haslo'],
            email=dane['email'],
            balans=dane.get('balans', 100.0),
            rola=dane.get('rola', 'Uzytkownik'),
            status_weryfikacji=dane.get('status_weryfikacji', False)
        )
        nowe_konto.save()
        send_verification_email(nowe_konto)
        return jsonify({'message': 'Konto zostało pomyślnie utworzone. Sprawdź swoją skrzynkę pocztową, aby zweryfikować konto', 'konto': nowe_konto.to_dict()}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Weryfikacja konta
@app.route("/api/konto/verify/<token>", methods=['GET'])
def verify_account(token):
    try:
        email = confirm_verification_token(token)
        if not email:
            return jsonify({'error': 'Link weryfikacyjny jest nieprawidłowy lub wygasł'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Zaktualizuj zapytanie, aby szukało po emailu
        cursor.execute("UPDATE Uzytkownik SET status_weryfikacji = TRUE WHERE email = %s", (email,))
        
        if cursor.rowcount == 0:
            return jsonify({'error': 'Nie znaleziono użytkownika'}), 404
            
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({'message': 'Konto zostalo pomyslnie zweryfikowane'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Pobieranie konta
@app.route("/api/konto", methods=['GET'])
def get_account():
    try:
        users = Uzytkownik.get_all_users()
        return jsonify([user.to_dict() for user in users])
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Usuwanie konta
@app.route("/api/konto/<int:id_uzytkownika>", methods=['DELETE'])
def delete_account(id_uzytkownika):
    try:
        konto = Uzytkownik.get_by_id(id_uzytkownika)
        if not konto:
            return jsonify({'error': 'Konto o podanym ID nie istnieje'}), 404
        konto.delete()
        return jsonify({'message': 'Konto zostało pomyślnie usunięte'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Resetowanie hasła
@app.route("/api/konto/reset_password", methods=['POST'])
def reset_password():
    dane = request.json
    try:
        user = Uzytkownik.get_by_name(dane['nazwa'])
        if not user:
            return jsonify({'error': 'Użytkownik nie istnieje'}), 404
        
        nowe_haslo = dane['new_password']
        hashed_password = Uzytkownik.hash_password(nowe_haslo)

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.callproc('reset_hasla', (dane['nazwa'], hashed_password))
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({'message': 'Hasło zostało pomyślnie zresetowane'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Wysyłanie maila
def send_email(to_email, subject, body):
    from_email = "bukmacherteststudia@gmail.com"
    from_password = "rhug meuu artk weof"

    msg = MIMEText(body)
    msg['Subject'] = subject
    msg['From'] = from_email
    msg['To'] = to_email

    try:
        server = smtplib.SMTP_SSL('smtp.gmail.com', 465)
        server.login(from_email, from_password)
        server.sendmail(from_email, to_email, msg.as_string())
        server.quit()
        print("Mail wysłany pomyślnie")
    except Exception as e:
        print(f"Nie udało się wysłać maila: {str(e)}")

# Generowanie unikalnych tokenów
def generate_verification_token(email):
    serializer = URLSafeTimedSerializer(app.config['SECRET_KEY'])
    return serializer.dumps(email, salt='email-verification')

# Zatwierdzanie tokena
def confirm_verification_token(token, expiration=3600):
    serializer = URLSafeTimedSerializer(app.config['SECRET_KEY'])
    try:
        email = serializer.loads(
            token,
            salt='email-verification',
            max_age=expiration
        )
    except (SignatureExpired, BadSignature):
        return None
    return email

# Wysyłanie maila weryfikacyjnego
def send_verification_email(user):
    token = generate_verification_token(user.email)
    verification_url = f"http://localhost:5000/api/konto/verify/{token}"
    subject = "Proszę zweryfikować emaila!"
    body = f"{user.nazwa}, kliknij aby zweryfikować email: {verification_url}"
    send_email(user.email, subject, body)

# Szukanie meczów po nazwie
@app.route('/api/konto/find_match', methods=['GET'])
def find_match():
    print("Endpoint /api/konto/find_match został wywołany")
    zapytanie_wyszukiwania = request.args.get('search', '')
    print(f"Zapytanie wyszukiwania: {zapytanie_wyszukiwania}")
    
    if not zapytanie_wyszukiwania:
        return jsonify({'error': 'Nie wpisano żadnego zapytania'}), 400

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.callproc('znajdz_mecz', [zapytanie_wyszukiwania])

        for result in cursor.stored_results():
            matches = result.fetchall()
            
        cursor.close()
        conn.close()

        return jsonify(matches), 200
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Stawianie zakładów
@app.route("/api/zaklad", methods=["POST", "OPTIONS"])
def postaw_zaklad():
    if request.method == "OPTIONS":
        return '', 200

    print("===== POCZĄTEK PROCESU ZAKŁADU =====")
    dane = request.json
    print(f"Otrzymane dane: {dane}")
    conn = None
    cursor = None
    
    try:
        if dane is None:
            print("Błąd: Brak danych w request.json")
            return jsonify({"error": "Brak danych w żądaniu"}), 400

        wymagane_pola = ["id_uzytkownika", "id_kursu", "kwota_postawiona"]
        brakujace_pola = [pole for pole in wymagane_pola if pole not in dane]
        
        print(f"Sprawdzanie wymaganych pól:")
        print(f"- Wymagane pola: {wymagane_pola}")
        print(f"- Otrzymane pola: {list(dane.keys())}")
        print(f"- Brakujące pola: {brakujace_pola}")

        if brakujace_pola:
            return jsonify({"error": f"Brak wymaganych pól w żądaniu: {', '.join(brakujace_pola)}"}), 400

        try:
            kwota = Decimal(str(dane["kwota_postawiona"]))
            if kwota <= 0:
                return jsonify({"error": "Kwota zakładu musi być większa od 0"}), 400
        except (ValueError, DecimalException):
            return jsonify({"error": "Nieprawidłowy format kwoty"}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("""
            SELECT km.*, m.status as status_meczu 
            FROM Kursy_Meczu km
            JOIN Mecz m ON km.id_meczu = m.id_meczu
            WHERE km.id = %s AND km.status = TRUE
        """, (dane["id_kursu"],))
        
        kurs = cursor.fetchone()
        if not kurs:
            return jsonify({"error": "Wybrany kurs nie istnieje lub jest nieaktywny"}), 400
        
        if kurs['status_meczu'].lower() != 'oczekujący':
            return jsonify({"error": "Nie można postawić zakładu na ten mecz"}), 400

        cursor.execute("SELECT balans FROM Uzytkownik WHERE id_uzytkownika = %s", 
                      (dane["id_uzytkownika"],))
        user = cursor.fetchone()
        if not user:
            return jsonify({"error": "Użytkownik nie istnieje"}), 404
        
        args = (dane["id_uzytkownika"], dane["id_kursu"], kwota, 0)

        print('Rozpoczynanie procedury')
        print(f'Argumenty procedury: {args}')
        result_args = cursor.callproc('postaw_zaklad', args)
        print(f'Wynik procedury: {result_args}')
        
        try:
            id_zakladu = result_args['postaw_zaklad_arg4']
            print(f'ID zakładu: {id_zakladu}')
            
            if id_zakladu is None or id_zakladu == 0:
                raise ValueError("Nie udało się uzyskać ID zakładu")
                
            conn.commit()
            
            return jsonify({
                "message": "Zakład został pomyślnie postawiony",
                "id_zakladu": id_zakladu
            }), 201

        except IndexError as e:
            raise ValueError("Nieprawidłowy format wyniku procedury") from e

    except mysql.connector.Error as e:
        if conn:
            conn.rollback()
        print(f"Błąd MySQL: {str(e)}")
        return jsonify({"error": "Wystąpił błąd bazy danych"}), 500
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Nieoczekiwany błąd: {str(e)}")
        return jsonify({"error": f"Wystąpił nieoczekiwany błąd: {str(e)}"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# Tworzenie kursów i edycja danych
@app.route("/api/mecz/<int:mecz_id>/kursy", methods=['POST'])
def create_match_odds(mecz_id):
    dane = request.json
    try:
        if 'nazwa_typu' not in dane or 'kurs' not in dane:
            return jsonify({'error': 'Brakujące dane: nazwa_typu lub kurs'}), 400
        
        nazwa_typu = dane['nazwa_typu']
        kurs = Decimal(str(dane['kurs']))
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        args = (mecz_id, nazwa_typu, kurs, 0)
        result_args = cursor.callproc('dodaj_kurs', args)
        id_kursu = result_args[3]
        conn.commit()
        
        return jsonify({
            'message': 'Kurs został dodany',
            'id': id_kursu
        }), 201
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

@app.route("/api/mecz/<int:mecz_id>/kursy", methods=['GET'])
def get_match_odds(mecz_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute("SELECT * FROM aktywne_kursy WHERE id_meczu = %s", (mecz_id,))
        
        kursy = cursor.fetchall()
        return jsonify(kursy), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

@app.route("/api/mecz/<int:mecz_id>/kursy/<int:kurs_id>", methods=['PUT'])
def update_match_odd(mecz_id, kurs_id):
    dane = request.json
    try:
        if 'kurs' not in dane:
            return jsonify({'error': 'Brakujące dane: kurs'}), 400
            
        kurs = Decimal(str(dane['kurs']))
        
        # Dodatkowa walidacja
        if kurs <= 1:
            return jsonify({'error': 'Kurs musi być większy niż 1'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT status FROM Kursy_Meczu 
            WHERE id = %s AND id_meczu = %s
        """, (kurs_id, mecz_id))
        
        result = cursor.fetchone()
        if not result:
            return jsonify({'error': 'Kurs nie istnieje'}), 404
        if not result[0]:
            return jsonify({'error': 'Kurs jest nieaktywny'}), 400
            
        cursor.callproc('aktualizuj_kurs', [mecz_id, kurs_id, kurs])
        conn.commit()
            
        return jsonify({'message': 'Kurs został zaktualizowany'}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

@app.route("/api/mecz/<int:mecz_id>/kursy/<int:kurs_id>", methods=['DELETE'])
def deactivate_match_odd(mecz_id, kurs_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Wywołanie procedury dezaktywującej kurs
        cursor.callproc('dezaktywuj_kurs', [mecz_id, kurs_id])
        conn.commit()
        
        return jsonify({'message': 'Kurs został dezaktywowany'}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


# Księgowość

@app.route("/api/konto/<int:id_uzytkownika>/bilans", methods=['GET'])
def balans_status(id_uzytkownika):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT balans FROM Uzytkownik WHERE id_uzytkownika = %s
        """, (id_uzytkownika,))
        uzytkownik = cursor.fetchone()
        
        cursor.execute("""
            SELECT * FROM statystyki_uzytkownika 
            WHERE id_uzytkownika = %s
        """, (id_uzytkownika,))
        statystyki = cursor.fetchone()
        
        if not statystyki:
            statystyki = {
                'wygrane_zaklady': 0,
                'przegrane_zaklady': 0,
                'suma_wygranych': 0,
                'suma_przegranych': 0,
                'suma_postawionych': 0,
                'procent_wygranych': 0,
                'balans': uzytkownik['balans'] if uzytkownik else 0
            }
        
        cursor.execute("""
            SELECT * FROM uzytkownik_historia_balansu
            WHERE id_uzytkownika = %s
            ORDER BY data DESC
            LIMIT 50
        """, (id_uzytkownika,))
        historia = cursor.fetchall()
        
        return jsonify({
            'statystyki': statystyki,
            'ostatnie_operacje': [{
                'data': h['data'].isoformat() if h['data'] else None,
                'typ_operacji': h['typ_operacji'],
                'kwota': str(h['kwota']),
                'zmiana_balansu': str(h['zmiana_balansu']),
                'saldo_po_operacji': str(h['saldo_po_operacji'])
            } for h in historia]
        }), 200
    
    except Exception as e:
        print(f"Błąd podczas pobierania bilansu: {str(e)}")
        return jsonify({'error': str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

@app.route("/api/login", methods=['POST'])
def login():
    dane = request.json
    try:
        user = Uzytkownik.get_by_name(dane['nazwa'])
        if not user:
            return jsonify({'error': 'Nieprawidłowa nazwa użytkownika lub hasło'}), 401
        
        if not Uzytkownik.verify_password(dane['haslo'], user.haslo):
            return jsonify({'error': 'Nieprawidłowa nazwa użytkownika lub hasło'}), 401
            
        if not user.status_weryfikacji:
            return jsonify({'error': 'Konto nie zostało zweryfikowane. Sprawdź swoją skrzynkę email.'}), 401
            
        return jsonify({
            'message': 'Zalogowano pomyślnie',
            'user': {
                'id': user.id_uzytkownika,
                'nazwa': user.nazwa,
                'email': user.email,
                'balans': str(user.balans),
                'rola': user.rola,
                'data_utworzenia': user.data_utworzenia.strftime('%Y-%m-%d %H:%M:%S') if user.data_utworzenia else None
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route("/api/zaklady/<int:id_uzytkownika>", methods=['GET'])
def get_user_bets(id_uzytkownika):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT z.*, m.status as status_meczu,
                   CONCAT(dg.nazwa, ' vs ', dgos.nazwa) as nazwa_meczu,
                   km.nazwa_typu, km.kurs
            FROM Zaklad z
            JOIN Mecz m ON z.id_meczu = m.id_meczu
            JOIN Druzyny dg ON m.id_gospodarzy = dg.id_druzyny
            JOIN Druzyny dgos ON m.id_gosci = dgos.id_druzyny
            JOIN Kursy_Meczu km ON z.kurs_meczu = km.id
            WHERE z.id_uzytkownika = %s
        """, (id_uzytkownika,))
        
        bets = cursor.fetchall()
        return jsonify(bets)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()
@app.route("/api/mecze", methods=["GET"])
def getMecze():
    conn = None
    cursor = None
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT m.id_meczu, m.data_meczu, m.status, 
                   dg.nazwa as gospodarz, dgos.nazwa as gosc,
                   m.id_gospodarzy, m.id_gosci
            FROM Mecz m
            JOIN Druzyny dg ON m.id_gospodarzy = dg.id_druzyny
            JOIN Druzyny dgos ON m.id_gosci = dgos.id_druzyny
        """)
        
        mecze = cursor.fetchall()
        
        return jsonify(mecze), 200

    except mysql.connector.Error as e:
        if conn:
            conn.rollback()
        print(f"Błąd MySQL: {str(e)}")
        return jsonify({"error": "Wystąpił błąd bazy danych"}), 500
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Nieoczekiwany błąd: {str(e)}")
        return jsonify({"error": f"Wystąpił nieoczekiwany błąd: {str(e)}"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

@app.route("/api/mecz/<int:mecz_id>/zaklady", methods=['GET'])
def zdarzenia_w_meczu(mecz_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        cursor.callproc('pobierz_zdarzenia_meczu', [mecz_id])
        for result in cursor.stored_results():
            zdarzenia = result.fetchall()
        
        return jsonify(zdarzenia), 200
    except Exception as e:
        print(f"Błąd podczas pobierania zdarzeń meczu: {str(e)}")
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route("/api/druzyna/<int:druzyna_id>", methods=['GET'])
def druzyna(druzyna_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        cursor.callproc('pobierz_sklad_druzyny', [druzyna_id])
        
        # Pobieranie wyników w prawidłowy sposób
        results = list(cursor.stored_results())
        
        # Pierwszy wynik to trener
        trener = results[0].fetchone() if results[0].rowcount > 0 else None
        
        # Drugi wynik to zawodnicy
        zawodnicy = results[1].fetchall() if len(results) > 1 else []

        response_data = {
            'trener': trener,
            'zawodnicy': zawodnicy
        }

        return jsonify(response_data), 200
        
    except Exception as e:
        print(f"Błąd podczas pobierania składu drużyny: {str(e)}")
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()
    
@app.route("/api/konto/<int:id_uzytkownika>", methods=['PUT'])
def update_user_role(id_uzytkownika):
    try:
        dane = request.json
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE Uzytkownik 
            SET rola = %s 
            WHERE id_uzytkownika = %s
        """, (dane['rola'], id_uzytkownika))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'message': 'Rola użytkownika została zaktualizowana'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == "__main__":
    if test_db_connection():
        print("Połączenie z bazą danych zostało ustanowione pomyślnie.")
    else:
        print("Nie udało się połączyć z bazą danych.")
    
    app.run(debug=True)
