from flask import Flask, request, jsonify
from datetime import date
from decimal import Decimal
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)

#MySQL
USER = "root"
PASSWORD = "bazy123"
HOST = "localhost"
DATABASE = "Bukmacher"

app.config['SQLALCHEMY_DATABASE_URI'] = f'mysql+pymysql://{USER}:{PASSWORD}@{HOST}/{DATABASE}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

class Uzytkownik(db.Model):
    __tablename__ = 'Uzytkownik'
    id_uzytkownika = db.Column(db.Integer, primary_key=True)
    nazwa = db.Column(db.String(50))
    haslo = db.Column(db.String(50))
    email = db.Column(db.String(50))
    balans = db.Column(db.Decimal(8,2))
    rola = db.Column(db.String(50))
    status_weryfikacji = db.Column(db.bool)

    def to_dict(self):
        return {
            'id_uzytkownika':self.id_uzytkownika,
            'nazwa':self.nazwa,
            'haslo':self.haslo,
            'email':self.email,
            'balans':self.balans,
            'rola':self.rola,
            'status_weryfikacji':self.status_weryfikacji

        }

#API do tworzenia konta
@app.route("/api/konto", methods=['POST'])
def utworz_konto():
    data = request.json
    try:
        if Uzytkownik.query.filter_by(nazwa=data['nazwa']).first():
            return jsonify({'error':'Użytkownik o takiej nazwie już istnieje'}), 400
        if Uzytkownik.query.filter_by(email=data['email']).first():
            return jsonify({'error':'Email jest zajęty'}), 400

        nowe_konto = Uzytkownik(
            nazwa=data['nazwa'],
            haslo=data['haslo'],
            email=data['email'],
            balans=data.get('balans', 0.0),
            rola=data.get('rola', 'Uzytkownik'),
            status_weryfikacji=data.get('status_weryfikacji', False)
        )

        db.session.add(nowe_konto)
        db.session.commit()

        return jsonify({
            'message':'Konto zostało pomyślnie utworzone',
            'konto': nowe_konto.to_dict()
        }), 201
    
    except KeyError as e:
        return jsonify({'error':f'Brak wymaganego pola: {str(e)}'}), 400
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500
    

def pobierz_konta():
    try:
        konta=Uzytkownik.query.all()
        return jsonify([Uzytkownik.to_dict() for konto in Uzytkownik])
    except Exception as e:
        return jsonify({'error': str(e)}), 500
        

with app.app_context():
    db.create_all()

if __name__ == "__main__":
    app.run(debug=True)

