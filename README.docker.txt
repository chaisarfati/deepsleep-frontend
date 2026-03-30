Frontend dockerisé avec Nginx.

Accès public attendu:
  http://deepsleep.sarfatech.com:8080

Le frontend parle au backend via:
  /api

Nginx reverse-proxye /api vers:
  http://deepsleep-api:8000/
