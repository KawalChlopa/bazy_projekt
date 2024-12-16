import requests

# Dane do wysłania
data = {
    "nazwa": "testuser",
    "haslo": "test123",
    "email": "test@example.com",
    "data_utworzenia": "12.01.2003",
    "balans": 0.00,
    "rola": "Uzytkownik",
    "status_weryfikacji": False
}

# Wysłanie żądania
response = requests.post('http://localhost:5000/api/konto', json=data)

# Wyświetlenie wyników
print("Status kod:", response.status_code)
print("Odpowiedź:", response.json())