FROM mysql:latest

ENV MYSQL_ROOT_PASSWORD=bazy123
ENV MYSQL_DATABASE=Bukmacher
ENV MYSQL_USER=gabrys
ENV MYSQL_PASSWORD=bazy123

COPY init.sql /docker-entrypoint-initdb.d/

EXPOSE 3306

CMD ["mysqld"]