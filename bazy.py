import http.client
import mysql.connector
import json 

http_conn = http.client.HTTPSConnection("v3.football.api-sports.io")

db_conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="bazy123",
    database="Bukmacher"
)
cursor = db_conn.cursor()

headers = {
    'x-rapidapi-host': "v3.football.api-sports.io",
    'x-rapidapi-key': "886e8268d1a364e650062b1b0cd0f4fe"
    }

http_conn.request("GET", "/teams?league=39&season=2022", headers=headers)

res = http_conn.getresponse()
team_data = json.loads(res.read().decode('utf-8'))

for entry in team_data['response']:
    team = entry['team']
    venue = entry['venue']

    team_id = team['id']
    nazwa = team['name']
    kraj = team['country']
    data_zalozenia = team['founded']
    stadion = venue['name']

    cursor.execute("""
                   INSERT INTO Druzyny (id_druzyny, nazwa, kraj, rok_zalozenia, stadion)
                   VALUES (%s,%s,%s,%s,%s) 
                   ON DUPLICATE KEY UPDATE
                   nazwa=VALUES(nazwa),
                   kraj=VALUES(kraj),
                   rok_zalozenia=VALUES(rok_zalozenia),
                   stadion=VALUES(stadion)""", (team_id,nazwa, kraj, data_zalozenia, stadion))

http_conn.request("GET", "/players?league=39&season=2022", headers=headers)

res = http_conn.getresponse()
player_data = json.loads(res.read().decode('utf-8'))

for entry in player_data['response']:
    player = entry['player']
    statistics = entry['statistics']

    id_zawodnika = player['id']
    imie = player['firstname']
    nazwisko = player['lastname']
    data_urodzenia = player['birth']['date']
    for stats in statistics:
        team = stats['team']
        games = stats['games']

        id_druzyny = team['id']

        pozycja = games['position']
        numer_koszulka = games['number']
        cursor.execute("""
                        INSERT INTO Zawodnicy (id_zawodnika, id_druzyny, imie, nazwisko, pozycja, data_urodzenia, numer_koszulka)
                        VALUES (%s,%s,%s,%s,%s,%s,%s) 
                        ON DUPLICATE KEY UPDATE
                        id_zawodnika=VALUES(id_zawodnika),
                        id_druzyny=VALUES(id_druzyny),
                        imie=VALUES(imie),
                        nazwisko=VALUES(nazwisko),
                        pozycja=VALUES(pozycja),
                        data_urodzenia=VALUES(data_urodzenia),
                        numer_koszulka=VALUES(numer_koszulka)""", (id_zawodnika, id_druzyny, imie, nazwisko, pozycja, data_urodzenia, numer_koszulka))
        

http_conn.request("GET", "/fixtures?league=39&season=2022", headers=headers)

res = http_conn.getresponse()
match_data = json.loads(res.read().decode('utf-8'))

for entry in match_data['response']:
    fixture = entry['fixture']
    teams = entry['teams']
    goals = entry['goals']

    id_meczu = fixture['id']
    sedzia = fixture['referee']
    id_gospodarzy = teams['home']['id']
    id_gosci = teams['away']['id']
    gole_gospodarzy = goals['home']
    gole_gosci = goals['away']
    data_meczu = fixture['date']
    zwyciestwo_gospodarzy = teams['home']['winner']
    zwyciestwo_gosci = teams['away']['winner']
    try:
        cursor.execute(""" 
        INSERT INTO Mecz(id_meczu, id_gospodarzy, id_gosci, gole_gospodarzy, gole_gosci, sedzia, data_meczu, zwyciestwo_gospodarzy, zwyciestwo_gosci)
        VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON DUPLICATE KEY UPDATE
        id_meczu=VALUES(id_meczu),
        id_gospodarzy=VALUES(id_gospodarzy),
        id_gosci=VALUES(id_gosci),
        gole_gospodarzy=VALUES(gole_gospodarzy),
        gole_gosci=VALUES(gole_gosci),
        sedzia=VALUES(sedzia),
        zwyciestwo_gospodarzy=VALUES(zwyciestwo_gospodarzy),
        zwyciestwo_gosci=VALUES(zwyciestwo_gosci),
        data_meczu=VALUES(data_meczu)
        """, (id_meczu, id_gospodarzy, id_gosci, gole_gospodarzy, gole_gosci, sedzia, data_meczu, zwyciestwo_gospodarzy, zwyciestwo_gosci))
    except Exception as e:
        print(f"Error:{e}")



#w API zapamiętać w zakładzce fixtures/events po wpisanu id meczu w pole fixtures pojawią się statystki dokładne meczu. Przemyśleć czy ta opcja nie byłaby dobra aby api pobierało w trakcie wejścia w szczegóły meczu albo w dany mecz bo brakuje zapytań
#cursor.execute("""SELECT id_meczu FROM mecze""")
#IDmeczu = cursor.fetchall()


    

db_conn.commit()
cursor.close()
db_conn.close()
http_conn.close()

