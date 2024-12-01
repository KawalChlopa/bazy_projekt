FROM mysql:latest

ENV MYSQL_ROOT_PASSWORD=bazy123
ENV MYSQL_DATABASE=Bukmacher
ENV MYSQL_USER=gabrys
ENV MYSQL_PASSWORD=bazy123


RUN microdnf update && microdnf install -y \
    python3 \
    python3-pip \
    && microdnf clean all


COPY init.sql /docker-entrypoint-initdb.d/
COPY bazy.py /app/bazy.py

WORKDIR /app

RUN pip3 install mysql-connector-python

COPY start.sh /docker-entrypoint-initdb.d/start.sh


RUN chmod +x /docker-entrypoint-initdb.d/start.sh

EXPOSE 3306

CMD ["mysqld"]