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

    #pobiera użytkownika po id
    @staticmethod
    def get_by_id(user_id):
        try:
            conn = get_db_connection()
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT * FROM uzytkownik_szczegoly WHERE id_uzytkownika = %s", (user_id,))
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
            cursor.callproc('usun_uzytkownika', (self.id_uzytkownika))
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

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.callproc('aktualizacja_statusu-weryfikacji', (user.id_uzytkownika,))
        conn.commit()
        cursor.close()
        conn.close()

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
        cursor.callproc('reset_hasla', (data['nazwa'], hashed_password))
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

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.callproc('znajdz_mecz', [search_query])

        for result in cursor.stored_results():
            matches = result.fetchall()
            
        cursor.close()
        conn.close()

        return jsonify(matches), 200
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500



#-------------------------------------------------------------
#STAWIANIE ZAKŁADÓW, NIE WIEM CZY DZIAŁA, TRZEBA POTESTOWAĆ XD

@app.route("/api/zaklad", methods=["POST", "OPTIONS"])
def postawZaklad():
    if request.method == "OPTIONS":
        return '', 200

    print("===== POCZĄTEK PROCESU ZAKŁADU =====")
    data = request.json
    print(f"Otrzymane dane: {data}")
    conn = None
    cursor = None
    
    try:
        if data is None:
            print("Błąd: Brak danych w request.json")
            return jsonify({"error": "Brak danych w żądaniu"}), 400

        required_fields = ["id_uzytkownika", "id_kursu", "kwota_postawiona"]
        missing_fields = [field for field in required_fields if field not in data]
        
        print(f"Sprawdzanie wymaganych pól:")
        print(f"- Wymagane pola: {required_fields}")
        print(f"- Otrzymane pola: {list(data.keys())}")
        print(f"- Brakujące pola: {missing_fields}")

        if missing_fields:
            return jsonify({"error": f"Brak wymaganych pól w żądaniu: {', '.join(missing_fields)}"}), 400

        #Sprawdzamy kwotę postawioną
        try:
            kwota = Decimal(str(data["kwota_postawiona"]))
            if kwota <= 0:
                return jsonify({"error": "Kwota zakładu musi być większa od 0"}), 400
        except (ValueError, DecimalException):
            return jsonify({"error": "Nieprawidłowy format kwoty"}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        #Sprawdzamy czy kurs istnieje i czy jest aktywny
        cursor.execute("""
            SELECT km.*, m.status as status_meczu 
            FROM Kursy_Meczu km
            JOIN Mecz m ON km.id_meczu = m.id_meczu
            WHERE km.id = %s AND km.status = TRUE
        """, (data["id_kursu"],))
        
        kurs = cursor.fetchone()
        if not kurs:
            return jsonify({"error": "Wybrany kurs nie istnieje lub jest nieaktywny"}), 400
        
        if kurs['status_meczu'].lower() != 'oczekujący':
            return jsonify({"error": "Nie można postawić zakładu na ten mecz"}), 400

        #Sprawdzenie czy użytkownik istnieje
        cursor.execute("SELECT balans FROM Uzytkownik WHERE id_uzytkownika = %s", 
                      (data["id_uzytkownika"],))
        user = cursor.fetchone()
        if not user:
            return jsonify({"error": "Użytkownik nie istnieje"}), 404

        args = (data["id_uzytkownika"], data["id_kursu"], kwota, 0)

        result_args = cursor.callproc('postaw_zaklad', args)
        conn.commit()

        id_zakladu = result_args[3]

        #Pobieranie informacji o zakładzie
        cursor.execute("""
            SELECT 
                z.*,
                m.status as status_meczu,
                CONCAT(dg.nazwa, ' vs ', dgos.nazwa) as nazwa_meczu,
                km.nazwa_typu,
                km.kurs,
                DATE_FORMAT(z.data_postawienia, '%%Y-%%m-%%d %%H:%%i:%%s') as data_postawienia_format
            FROM Zaklad z
            JOIN Mecz m ON z.id_meczu = m.id_meczu
            JOIN Druzyny dg ON m.id_gospodarzy = dg.id_druzyny
            JOIN Druzyny dgos ON m.id_gosci = dgos.id_druzyny
            JOIN Kursy_Meczu km ON z.kurs_meczu = km.id
            WHERE z.id_zakladu = %s
        """, (id_zakladu,))

        zaklad = cursor.fetchone()
        
        if not zaklad:
            raise Exception("Nie udało się pobrać informacji o postawionym zakładzie")

        #Konwersja decimal na string dla JSON
        zaklad['kwota_postawiona'] = str(zaklad['kwota_postawiona'])
        zaklad['potencjalna_wygrana'] = str(zaklad['potencjalna_wygrana'])
        zaklad['kurs'] = str(zaklad['kurs'])

        return jsonify({
            "message": "Zakład został pomyślnie postawiony",
            "zaklad": zaklad
        }), 201

    except mysql.connector.Error as e:
        if conn:
            conn.rollback()
        print(f"Błąd MySQL: {str(e)}")
        return jsonify({"error": "Wystąpił błąd bazy danych"}), 500
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Błąd: {str(e)}")
        return jsonify({"error": str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

#rozliczanie

@app.route("/api/rozlicz_mecz", methods=["POST"])
def rozliczMecz():
    data = request.json
    conn = None
    cursor = None
    
    try:
        if not data or "id_meczu" not in data:
            return jsonify({"error": "Brak wymaganego pola id_meczu"}), 400
            
        args = [data["id_meczu"]]
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.callproc('rozlicz_mecz', args)
        conn.commit()

        # Pobierz informacji o meczu
        cursor.execute("""
            SELECT m.*, 
                   dg.nazwa as gospodarz, 
                   dgos.nazwa as gosc,
                   (SELECT COUNT(*) FROM Zaklad WHERE id_meczu = m.id_meczu) as liczba_zakladow
            FROM Mecz m
            JOIN Druzyny dg ON m.id_gospodarzy = dg.id_druzyny
            JOIN Druzyny dgos ON m.id_gosci = dgos.id_druzyny
            WHERE m.id_meczu = %s
        """, (data["id_meczu"],))
        
        mecz = cursor.fetchone()
        
        return jsonify({
            "message": "Mecz został rozliczony pomyślnie",
            "szczegoly": {
                "mecz": f"{mecz['gospodarz']} vs {mecz['gosc']}",
                "wynik": f"{mecz['gole_gospodarzy']}:{mecz['gole_gosci']}",
                "liczba_rozliczonych_zakladow": mecz['liczba_zakladow']
            }
        }), 200
        
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({"error": str(e)}), 500
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
    data = request.json
    try:
        if 'kurs' not in data:
            return jsonify({'error': 'Brakujące dane: kurs'}), 400
            
        kurs = Decimal(str(data['kurs']))
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.callproc('aktualizuj_kurs', 
                       [mecz_id, kurs_id, Decimal(str(data['kurs']))])
            
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


#Księgowość------------------------

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
    data = request.json
    try:
        user = Uzytkownik.get_by_name(data['nazwa'])
        if not user:
            return jsonify({'error': 'Nieprawidłowa nazwa użytkownika lub hasło'}), 401
        
        if not Uzytkownik.verify_password(data['haslo'], user.haslo):
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
                'rola': user.rola
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

if __name__ == "__main__":
    if test_db_connection():
        print("Połączenie z bazą danych zostało ustanowione pomyślnie.")
    else:
        print("Nie udało się połączyć z bazą danych.")
    
    app.run(debug=True)

