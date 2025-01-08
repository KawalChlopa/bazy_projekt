from flask import Flask, request, jsonify
from datetime import datetime
from decimal import Decimal
from flask_cors import CORS
import bcrypt
import mysql.connector
from difflib import SequenceMatcher
from email.mime.text import MIMEText
import smtplib
import uuid
from itsdangerous import URLSafeTimedSerializer, SignatureExpired, BadSignature

app = Flask(__name__)
app.config['SECRET_KEY'] = 'bazy1234'
CORS(app)

#Tutaj parametry do łączenia się z bazą w razie jakby był potrzebny to jest też port
USER = "root"
PASSWORD = "bazy123"
HOST = "localhost"
DATABASE = "Bukmacher"
PORT = "3306"

#łączenie z bazą
def get_db_connection():
    return mysql.connector.connect(
        host=HOST,
        user=USER,
        password=PASSWORD,
        database=DATABASE
    )

#sprawdzanie łączności
def test_db_connection():
    try:
        conn = get_db_connection()
        conn.close()
        print("Połączenie z bazą danych jest aktywne.")
        return True
    except Exception as e:
        print(f"Błąd połączenia z bazą danych: {str(e)}")
        return False

#Klasa użytkownik zrobiomy obiekrowo żeby było bardziej przejrzyście
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

    #pobiera liste wsyzsktich użytkowników
    @staticmethod
    def get_all_users():
        try:
            conn = get_db_connection()
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM Uzytkownik")
            users = cursor.fetchall()
            return [Uzytkownik(**user) for user in users]
        finally:
            cursor.close()
            conn.close()

    def save(self):
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            #jak użytkownik insnieje
            if self.id_uzytkownika:
                cursor.execute("""
                    UPDATE Uzytkownik 
                    SET nazwa = %s, haslo = %s, email = %s, balans = %s, 
                        rola = %s, status_weryfikacji = %s 
                    WHERE id_uzytkownika = %s
                """, (self.nazwa, self.hash_password(self.haslo), self.email, self.balans, 
                     self.rola, self.status_weryfikacji, self.id_uzytkownika))
            #Tworzy nowego użytkonika
            else:
                cursor.execute("""
                    INSERT INTO Uzytkownik (nazwa, haslo, email, balans, 
                                          data_utworzenia, rola, status_weryfikacji)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, (self.nazwa, self.hash_password(self.haslo), self.email, self.balans,
                     self.data_utworzenia, self.rola, self.status_weryfikacji))
                self.id_uzytkownika = cursor.lastrowid
                
            conn.commit()
            return self.id_uzytkownika
        except mysql.connector.Error as err:
            raise Exception(f"Database error: {err}")
        finally:
            cursor.close()
            conn.close()

    #pobiera użytkownika po id
    @staticmethod
    def get_by_id(user_id):
        try:
            conn = get_db_connection()
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM Uzytkownik WHERE id_uzytkownika = %s", (user_id,))
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
            cursor.execute("SELECT * FROM Uzytkownik WHERE nazwa = %s", (nazwa,))
            user = cursor.fetchone()
            return Uzytkownik(**user) if user else None
        finally:
            cursor.close()
            conn.close()

    def delete(self):
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute("DELETE FROM Uzytkownik WHERE id_uzytkownika = %s", (self.id_uzytkownika,))
            conn.commit()
        finally:
            cursor.close()
            conn.close()

    #Zamienia na słonik żeby łatwiej było operować na danych podawanych przez api
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

#Poza klasą bo flaskowe api tego wymaga żeby być dostępne globalnie
@app.route("/api/konto", methods=['POST'])
def createAccount():
    data = request.json
    try:
        if Uzytkownik.get_by_name(data['nazwa']):
            return jsonify({'error': 'Użytkownik o takiej nazwie już istnieje'}), 400

        nowe_konto = Uzytkownik(
            nazwa=data['nazwa'],
            haslo=data['haslo'],
            email=data['email'],
            balans=data.get('balans', 0.0),
            rola=data.get('rola', 'Uzytkownik'),
            status_weryfikacji=data.get('status_weryfikacji', False)
        )
        nowe_konto.save()
        send_verification_email(nowe_konto)
        return jsonify({'message': 'Konto zostało pomyślnie utworzone. Sprawdź swoją skrzynkę pocztową, aby zweryfikować konto', 'konto': nowe_konto.to_dict()}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route("/api/konto/verify/<token>", methods=['GET'])
def verify_account(token):
    try:
        email = confirm_verification_token(token)
        if not email:
            return jsonify({'error': 'Link weryfikacyjny jest nieprawdłowy lub wygasł'}), 400
        
        user = Uzytkownik.get_by_name(email)

        if not user:
            return jsonify({'error': 'Użytkownik nie istnieje'}), 404

        user.status_weryfikacji = True
        user.save()
        return jsonify({'message': 'Konto zostało pomyślnie zweryfikowane'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route("/api/konto", methods=['GET'])
def getAccount():
    try:
        users = Uzytkownik.get_all_users()
        return jsonify([user.to_dict() for user in users])
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route("/api/konto/<int:id_uzytkownika>", methods=['DELETE'])
def deleteAccount(id_uzytkownika):
    try:
        konto = Uzytkownik.get_by_id(id_uzytkownika)
        if not konto:
            return jsonify({'error': 'Konto o podanym ID nie istnieje'}), 404
        konto.delete()
        return jsonify({'message': 'Konto zostało pomyślnie usunięte'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route("/api/konto/reset_password", methods=['POST'])
def resetPassword():
    data = request.json
    try:
        user = Uzytkownik.get_by_name(data['nazwa'])
        if not user:
            return jsonify({'error': 'Użytkownik nie istnieje'}), 404
        
        new_password = data['new_password']
        hashed_password = Uzytkownik.hash_password(new_password)

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE Uzytkownik SET haslo = %s WHERE id_uzytkownika = %s",
            (hashed_password, user.id_uzytkownika)
        )
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({'message': 'Hasło zostało pomyślnie zresetowane'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

#Wsysłanie maila tutaj
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
        print(f"Nieudało się wysłać maila: {str(e)}")

#Generowanie unikalnych tokenów
def generate_verification_token(email):
    serializer = URLSafeTimedSerializer(app.config['SECRET_KEY'])
    return serializer.dumps(email, salt='email-verification')

#Zatwierdzanie tokena
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

#Wysyalnie maila weryfikacyjnego
def send_verification_email(user):
    token = generate_verification_token(user.email)
    verification_url = f"http://localhost:5000/api/konto/verify/{token}"
    subject = "Prosze zweryfikować emaila!"
    body = f"{user.nazwa}, kliknij aby zweryfikować email: {verification_url}"
    send_email(user.email, subject, body)

#Funckcja do szukania meczów po nazwie częscie nazwy itp
@app.route('/api/konto/find_match', methods=['GET'])
def find_match():

    print("Endpoint /api/konto/find_match został wywołany")
    search_query = request.args.get('search', '')
    print(f"Zapytanie wyszukiwania: {search_query}")
    
    if not search_query:
        return jsonify({'error': 'Nie wpisano żadnego zapytania'}), 400

    search_terms = search_query.strip().split()
    
    try:
        with get_db_connection() as conn:
            with conn.cursor(dictionary=True) as cursor:
                base_query = """
                SELECT DISTINCT
                    mecz.id_meczu,
                    druzyna_gospodarz.nazwa AS gospodarz,
                    druzyna_gosc.nazwa AS gosc,
                    mecz.data_meczu,
                    mecz.gole_gospodarzy,
                    mecz.gole_gosci,
                    mecz.status
                FROM Mecz mecz
                JOIN Druzyny druzyna_gospodarz ON mecz.id_gospodarzy = druzyna_gospodarz.id_druzyny
                JOIN Druzyny druzyna_gosc ON mecz.id_gosci = druzyna_gosc.id_druzyny
                WHERE """
                
                if len(search_terms) == 1:
                    query = base_query + "(druzyna_gospodarz.nazwa LIKE %s OR druzyna_gosc.nazwa LIKE %s)"
                    cursor.execute(query, (f"%{search_terms[0]}%", f"%{search_terms[0]}%"))
                else:
                    conditions = []
                    params = []
                    for term in search_terms:
                        conditions.append("(druzyna_gospodarz.nazwa LIKE %s OR druzyna_gosc.nazwa LIKE %s)")
                        params.extend([f"%{term}%", f"%{term}%"])
                    query = base_query + " AND ".join(conditions)
                    cursor.execute(query, tuple(params))

                matches = cursor.fetchall()

                def similarity(s1, s2):
                    return SequenceMatcher(None, s1.lower(), s2.lower()).ratio()

                filtered_matches = []
                for match in matches:
                    score = max(
                        max(similarity(term, match['gospodarz']) for term in search_terms),
                        max(similarity(term, match['gosc']) for term in search_terms)
                    )
                    if score > 0.6: 
                        match['similarity'] = score
                        filtered_matches.append(match)

                return jsonify(sorted(filtered_matches, key=lambda x: x['similarity'], reverse=True))
                
    except mysql.connector.Error as err:
        return jsonify({'error': 'Błąd bazy danych'}), 500
    except Exception as e:
        return jsonify({'error': 'Błąd'}), 500



#-------------------------------------------------------------
#STAWIANIE ZAKŁADÓW, NIE WIEM CZY DZIAŁA, TRZEBA POTESTOWAĆ XD

@app.route("/api/zaklad", methods=["POST","OPTIONS"])
def postawZaklad():
    if request.method == "OPTIONS":
        return '', 200
        
    print("===== POCZĄTEK PROCESU ZAKŁADU =====")
    data = request.json
    print(f"Otrzymane dane: {data}")
    conn = None
    cursor = None
    
    try:
        # Sprawdzenie czy request.json nie jest None
        if data is None:
            print("Błąd: Brak danych w request.json")
            return jsonify({"error": "Brak danych w żądaniu"}), 400

        # Walidacja pól (bez zmian)
        required_fields = ["id_uzytkownika", "id_kursu", "kwota_postawiona"]
        missing_fields = [field for field in required_fields if field not in data]
        
        print(f"Sprawdzanie wymaganych pól:")
        print(f"- Wymagane pola: {required_fields}")
        print(f"- Otrzymane pola: {list(data.keys())}")
        print(f"- Brakujące pola: {missing_fields}")

        if missing_fields:
            return jsonify({"error": f"Brak wymaganych pól w żądaniu: {', '.join(missing_fields)}"}), 400
        
        # Konwersja danych (bez zmian)
        try:
            id_uzytkownika = int(data["id_uzytkownika"])
            id_kursu = int(data["id_kursu"])
            kwota_postawiona = Decimal(str(data["kwota_postawiona"]))
            
            print(f"Przekonwertowane dane:")
            print(f"- id_uzytkownika: {id_uzytkownika}")
            print(f"- id_kursu: {id_kursu}")
            print(f"- kwota_postawiona: {kwota_postawiona}")
            
            if kwota_postawiona <= 0:
                return jsonify({"error": "Kwota zakładu musi być większa od 0"}), 400
                
        except (ValueError, TypeError, Decimal.InvalidOperation) as e:
            return jsonify({"error": f"Nieprawidłowy format danych: {str(e)}"}), 400

        # Sprawdzenie użytkownika (bez zmian)
        uzytkownik = Uzytkownik.get_by_id(id_uzytkownika)
        if not uzytkownik:
            return jsonify({"error": "Nie znaleziono użytkownika o podanym ID"}), 404

        if uzytkownik.balans < kwota_postawiona:
            return jsonify({
                "error": "Niewystarczające środki na koncie",
                "dostepne_srodki": str(uzytkownik.balans),
                "wymagane": str(kwota_postawiona)
            }), 400

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Pobierz informacje o kursie i meczu
        cursor.execute("""
            SELECT 
                km.*,
                m.status as status_meczu,
                m.id_meczu,
                m.data_meczu,
                CONCAT(d1.nazwa, ' vs ', d2.nazwa) as nazwa_meczu
            FROM Kursy_Meczu km
            JOIN Mecz m ON km.id_meczu = m.id_meczu
            JOIN Druzyny d1 ON m.id_gospodarzy = d1.id_druzyny
            JOIN Druzyny d2 ON m.id_gosci = d2.id_druzyny
            WHERE km.id = %s
        """, (id_kursu,))
        
        kurs_info = cursor.fetchone()
        print(f"Informacje o kursie: {kurs_info}")
        
        if not kurs_info:
            return jsonify({"error": "Nie znaleziono wybranego kursu"}), 404
            
        if not kurs_info['status']:
            return jsonify({"error": "Ten kurs nie jest już aktywny"}), 400

        # Sprawdzenie czasu meczu
        current_time = datetime.now()
        match_time = kurs_info['data_meczu']
        
        if current_time >= match_time:
            return jsonify({
                "error": f"Nie można postawić zakładu - mecz {kurs_info['nazwa_meczu']} już się rozpoczął lub zakończył"
            }), 400

        # Sprawdzenie statusu - niewrażliwe na wielkość liter
        allowed_statuses = ['oczekujący', 'nowy', 'zaplanowany']
        if kurs_info['status_meczu'].lower() not in allowed_statuses:
            return jsonify({
                "error": f"Nie można postawić zakładu - mecz {kurs_info['nazwa_meczu']} ma niedozwolony status: {kurs_info['status_meczu']}"
            }), 400

        # Obliczenie potencjalnej wygranej
        potencjalna_wygrana = kwota_postawiona * Decimal(str(kurs_info['kurs']))

        # Zapis zakładu
        cursor.execute(
            """INSERT INTO Zaklad 
               (id_meczu, id_uzytkownika, wynik, kwota_postawiona, 
                potencjalna_wygrana, status_zakladu, data_postawienia, kurs_meczu) 
               VALUES (%s, %s, %s, %s, %s, %s, NOW(), %s)""",
            (kurs_info['id_meczu'], id_uzytkownika, False, kwota_postawiona, 
             potencjalna_wygrana, "Oczekujący", id_kursu)  # Zmiana z kurs_info['kurs'] na id_kursu
        )
        id_zakladu = cursor.lastrowid

        # Aktualizacja salda użytkownika
        nowy_balans = uzytkownik.balans - kwota_postawiona
        cursor.execute(
            "UPDATE Uzytkownik SET balans = %s WHERE id_uzytkownika = %s",
            (nowy_balans, id_uzytkownika)
        )

        conn.commit()
        print("Zakład został pomyślnie zapisany")

        return jsonify({
            "message": "Zakład został pomyślnie postawiony",
            "szczegoly": {
                "id_zakladu": id_zakladu,
                "nowy_balans": str(nowy_balans),
                "potencjalna_wygrana": str(potencjalna_wygrana),
                "mecz": kurs_info['nazwa_meczu'],
                "typ_zakladu": kurs_info['nazwa_typu'],
                "kurs": str(kurs_info['kurs'])
            }
        }), 201

    except Exception as e:
        print(f"Wystąpił nieoczekiwany błąd: {str(e)}")
        if conn:
            conn.rollback()
        return jsonify({"error": f"Wystąpił błąd podczas przetwarzania zakładu: {str(e)}"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        print("===== KONIEC PROCESU ZAKŁADU =====")
#rozliczanie

@app.route("/api/rozlicz_mecz", methods=["POST"])
def rozliczMecz():
    data = request.json
    conn = None
    cursor = None
    
    try:
        if not data or "id_meczu" not in data:
            return jsonify({"error": "Brak wymaganego pola id_meczu"}), 400
            
        id_meczu = int(data["id_meczu"])
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Sprawdź czy mecz istnieje i pobierz jego wynik
        cursor.execute("""
            SELECT m.id_meczu, m.gole_gospodarzy, m.gole_gosci, m.status,
                   d1.nazwa as gospodarz, d2.nazwa as gosc
            FROM Mecz m
            JOIN Druzyny d1 ON m.id_gospodarzy = d1.id_druzyny
            JOIN Druzyny d2 ON m.id_gosci = d2.id_druzyny
            WHERE m.id_meczu = %s
        """, (id_meczu,))
        
        mecz = cursor.fetchone()
        
        if not mecz:
            return jsonify({"error": "Mecz nie istnieje"}), 404

        if mecz['status'] == 'Zakończony':
            return jsonify({"error": "Mecz został już rozliczony"}), 400

        # Pobierz wszystkie zakłady dla tego meczu
        cursor.execute("""
            SELECT z.*, km.nazwa_typu, km.kurs 
            FROM Zaklad z
            JOIN Kursy_Meczu km ON z.kurs_meczu = km.id
            WHERE z.id_meczu = %s AND z.status_zakladu = 'Oczekujący'
        """, (id_meczu,))
        
        zaklady = cursor.fetchall()

        for zaklad in zaklady:
            wygrany = False
            
            # Określenie wyniku zakładu
            if (zaklad['nazwa_typu'].lower() == 'zwycięstwo gospodarzy' and 
                mecz['gole_gospodarzy'] > mecz['gole_gosci']):
                wygrany = True
            elif (zaklad['nazwa_typu'].lower() == 'remis' and 
                  mecz['gole_gospodarzy'] == mecz['gole_gosci']):
                wygrany = True
            elif (zaklad['nazwa_typu'].lower() == 'zwycięstwo gości' and 
                  mecz['gole_gospodarzy'] < mecz['gole_gosci']):
                wygrany = True

            status_zakladu = "Wygrany" if wygrany else "Przegrany"
            
            # Aktualizuj status zakładu
            cursor.execute("""
                UPDATE Zaklad 
                SET status_zakladu = %s,
                    wynik = %s
                WHERE id_zakladu = %s
            """, (status_zakladu, wygrany, zaklad['id_zakladu']))

            # Wypłata wygranej
            if wygrany:
                cursor.execute("""
                    UPDATE Uzytkownik 
                    SET balans = balans + %s 
                    WHERE id_uzytkownika = %s
                """, (zaklad['potencjalna_wygrana'], zaklad['id_uzytkownika']))

            # Dodaj wpis do historii (upewnij się, że nazwa tabeli jest prawidłowa)
            # cursor.execute("""
            #     INSERT INTO Historia_Zakladow 
            #         (id_zakladu, id_uzytkownika, status) 
            #     VALUES (%s, %s, %s)
            # """, (zaklad['id_zakladu'], zaklad['id_uzytkownika'], status_zakladu))

        # Zaktualizuj status meczu
        cursor.execute("""
            UPDATE Mecz 
            SET status = 'Zakończony',
                zwyciestwo_gospodarzy = %s,
                zwyciestwo_gosci = %s
            WHERE id_meczu = %s
        """, (
            mecz['gole_gospodarzy'] > mecz['gole_gosci'],
            mecz['gole_gospodarzy'] < mecz['gole_gosci'],
            id_meczu
        ))

        conn.commit()
        
        return jsonify({
            "message": "Mecz został rozliczony pomyślnie",
            "szczegoly": {
                "mecz": f"{mecz['gospodarz']} vs {mecz['gosc']}",
                "wynik": f"{mecz['gole_gospodarzy']}:{mecz['gole_gosci']}",
                "liczba_rozliczonych_zakladow": len(zaklady)
            }
        }), 200

    except Exception as e:
        print(f"Błąd podczas rozliczania meczu: {str(e)}")  # Dodanie logowania błędu
        if conn:
            conn.rollback()
        return jsonify({"error": f"Wystąpił błąd podczas rozliczania meczu: {str(e)}"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


#Tworzenie kursów i edycja danych
@app.route("/api/mecz/<int:mecz_id>/kursy", methods=['POST'])
def create_match_odds(mecz_id):
    data = request.json
    try:
        if 'nazwa_typu' not in data or 'kurs' not in data:
            return jsonify({'error': 'Brakujące dane: nazwa_typu lub kurs'}), 400
        
        nazwa_typu = data['nazwa_typu']
        kurs = Decimal(str(data['kurs']))
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Sprawdź czy mecz istnieje
        cursor.execute("SELECT id_meczu FROM Mecz WHERE id_meczu = %s", (mecz_id,))
        if not cursor.fetchone():
            return jsonify({'error': 'Mecz nie istnieje'}), 404
            
        # Sprawdź czy taki typ kursu już istnieje dla tego meczu
        cursor.execute("""
            SELECT id FROM Kursy_Meczu 
            WHERE id_meczu = %s AND nazwa_typu = %s AND status = TRUE
        """, (mecz_id, nazwa_typu))
        if cursor.fetchone():
            return jsonify({'error': 'Ten typ kursu już istnieje dla tego meczu'}), 400
            
        # Dodaj kurs
        cursor.execute(
            """INSERT INTO Kursy_Meczu 
               (id_meczu, nazwa_typu, kurs, status, data_utworzenia) 
               VALUES (%s, %s, %s, TRUE, NOW())""",
            (mecz_id, nazwa_typu, kurs)
        )
        conn.commit()
        
        return jsonify({
            'message': 'Kurs został dodany',
            'id': cursor.lastrowid
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
        
        cursor.execute("""
            SELECT id, nazwa_typu, kurs, status, data_utworzenia
            FROM Kursy_Meczu
            WHERE id_meczu = %s AND status = TRUE
        """, (mecz_id,))
        
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
    data = request.json
    try:
        if 'kurs' not in data:
            return jsonify({'error': 'Brakujące dane: kurs'}), 400
            
        kurs = Decimal(str(data['kurs']))
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            """UPDATE Kursy_Meczu 
               SET kurs = %s 
               WHERE id = %s AND id_meczu = %s AND status = TRUE""",
            (kurs, kurs_id, mecz_id)
        )
        conn.commit()
        
        if cursor.rowcount == 0:
            return jsonify({'error': 'Nie znaleziono aktywnego kursu'}), 404
            
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
        
        cursor.execute(
            "UPDATE Kursy_Meczu SET status = FALSE WHERE id = %s AND id_meczu = %s",
            (kurs_id, mecz_id)
        )
        conn.commit()
        
        if cursor.rowcount == 0:
            return jsonify({'error': 'Nie znaleziono kursu'}), 404
            
        return jsonify({'message': 'Kurs został dezaktywowany'}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
if __name__ == "__main__":
    if test_db_connection():
        print("Połączenie z bazą danych zostało ustanowione pomyślnie.")
    else:
        print("Nie udało się połączyć z bazą danych.")
    
    app.run(debug=True)