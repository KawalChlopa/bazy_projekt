from flask import Flask, request, jsonify
from datetime import datetime
from decimal import Decimal
from flask_cors import CORS
import bcrypt
import mysql.connector

app = Flask(__name__)
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
            cursor.execute(
                "INSERT INTO Uzytkownik (nazwa, haslo, email, balans, data_utworzenia, rola, status_weryfikacji) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (self.nazwa, self.hash_password(self.haslo), self.email, self.balans, self.data_utworzenia, self.rola, self.status_weryfikacji)
            )
            conn.commit()
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
        if Uzytkownik.get_by_id(data['nazwa']):
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
        return jsonify({'message': 'Konto zostało pomyślnie utworzone', 'konto': nowe_konto.to_dict()}), 201
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

if __name__ == "__main__":
    if test_db_connection():
        print("Połączenie z bazą danych zostało ustanowione pomyślnie.")
        app.run(debug=True)
    else:
        print("Nie udało się połączyć z bazą danych.")
