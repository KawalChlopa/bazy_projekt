FROM mysql:latest

ENV MYSQL_ROOT_PASSWORD=bazy123
ENV MYSQL_DATABASE=Bukmacher
ENV MYSQL_USER=gabrys
ENV MYSQL_PASSWORD=bazy123

COPY init.sql /docker-entrypoint-initdb.d/01-init.sql
COPY procedury.sql /docker-entrypoint-initdb.d/02-procedury.sql
COPY dane.sql /docker-entrypoint-initdb.d/03-dane.sql

EXPOSE 3306

CMD ["mysqld"]