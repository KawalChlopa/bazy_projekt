FROM mysql:latest

ENV MYSQL_ROOT_PASSWORD=bazy123
ENV MYSQL_DATABASE=Bukmacher
ENV MYSQL_USER=gabrys
ENV MYSQL_PASSWORD=bazy123

COPY konfiguracja.sql /docker-entrypoint-initdb.d/01-konfiguracja.sql

EXPOSE 3306

CMD ["mysqld"]