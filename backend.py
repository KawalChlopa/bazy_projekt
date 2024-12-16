from flask import Flask, request, jsonify
from datetime import datetime
from decimal import Decimal
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

#MySQL
USER = "root"
PASSWORD = "bazy123"
HOST = "localhost"
DATABASE = "Bukmacher"
PORT = "3306"

app.config['SQLALCHEMY_DATABASE_URI'] = f'mysql+pymysql://{USER}:{PASSWORD}@{HOST}:{PORT}/{DATABASE}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

def test_db_connection():
    with app.app_context():  # Tworzymy kontekst aplikacji
        try:
            with db.engine.connect() as connection:
                print("Połączenie z bazą danych jest aktywne.")
                return True
        except Exception as e:
            print(f"Błąd połączenia z bazą danych: {str(e)}")
            return False

class Uzytkownik(db.Model):
    __tablename__ = 'Uzytkownik'
    id_uzytkownika = db.Column(db.Integer, primary_key=True)
    nazwa = db.Column(db.String(50))
    haslo = db.Column(db.String(50))
    email = db.Column(db.String(50))
    balans = db.Column(db.Numeric(8,2))
    data_utworzenia = db.Column(db.DateTime)
    rola = db.Column(db.String(50))
    status_weryfikacji = db.Column(db.Boolean)
    
    #przekształcamy obiekty na słownik bo łatiej potem rządania robić w formacie json
    def to_dict(self):
        return {
            'id_uzytkownika':self.id_uzytkownika,
            'nazwa':self.nazwa,
            'haslo':self.haslo,
            'email':self.email,
            'balans':self.balans,
            'data_utworzenia': self.data_utworzenia.isoformat() if self.data_utworzenia else None,
            'rola':self.rola,
            'status_weryfikacji':self.status_weryfikacji

        }

#API do tworzenia konta
@app.route("/api/konto", methods=['POST'])
def utworz_konto():
    data = request.json
    print("Otrzymane dane:", data)
    try:
        existing_user = Uzytkownik.query.filter_by(nazwa=data['nazwa']).first()
        if existing_user:
            print(f"Znaleziono istniejącego użytkownika: {existing_user.to_dict()}")
            return jsonify({'error':'Użytkownik o takiej nazwie już istnieje'}), 400
        
        nowe_konto = Uzytkownik(
            nazwa=data['nazwa'],
            haslo=data['haslo'],
            email=data['email'],
            balans=Decimal(str(data.get('balans', 0.0))), 
            rola=data.get('rola', 'Uzytkownik'),
            data_utworzenia=datetime.now(),
            status_weryfikacji=data.get('status_weryfikacji', False)
        )
        
        print("Próba dodania konta:", nowe_konto.to_dict())
        db.session.add(nowe_konto)
        db.session.commit()
        print("Konto zostało zapisane")
        
        return jsonify({
            'message':'Konto zostało pomyślnie utworzone',
            'konto': nowe_konto.to_dict()
        }), 201
    
    except Exception as e:
        print(f"Błąd podczas tworzenia konta: {str(e)}")
        print(f"Typ błędu: {type(e)}")
        db.session.rollback()
        return jsonify({'error': str(e)}), 500
    
@app.route("/api/konto", methods=['GET'])
def pobierz_konta():
    try:
        konta=Uzytkownik.query.all()
        return jsonify([konto.to_dict() for konto in konta])
    except Exception as e:
        return jsonify({'error': str(e)}), 500
        
#API do usuwania konta
@app.route("/api/konto/<int:id_uzytkownika>", methods=['DELETE'])
def usun_konto(id_uzytkownika):
    try:
        konto = Uzytkownik.query.get(id_uzytkownika)
        if not konto:
            return jsonify({'error': 'Konto o podanym ID nie istnieje'}), 404

        potwierdzenie = request.args.get('potwierdzenie', 'nie').lower()
        if potwierdzenie != 'tak':
            return jsonify({'error': 'Operacja wymaga potwierdzenia. Użyj parametru potwierdzenie=tak w żądaniu.'}), 400

        db.session.delete(konto)
        db.session.commit()

        return jsonify({'message': 'Konto zostało pomyślnie usunięte'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500 


if __name__ == "__main__":
    #Sprawdzenie połączenia z bazą danych
    with app.app_context():  
        if test_db_connection():
            print("Połączenie z bazą danych zostało ustanowione pomyślnie.")
            app.run(debug=True)
        else:
            print("Nie udało się połączyć z bazą danych.")