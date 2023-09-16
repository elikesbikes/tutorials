version: '3.9'

# networks
# create a network 'frontend' in mode 'bridged'
networks:
  #frontend:
  #  driver: bridge
  frontend:
    external: true

# services
services:
  # guacd
  guacd:
    hostname: guacd
    tty: true
    stdin_open: true
    container_name: guacamole_guacd
    image: guacamole/guacd
    ports:
      - 4822:4822
    networks:
      frontend:
    restart: always
    volumes:
    - ./drive:/drive:rw
    - ./record:/record:rw

  # postgres
  postgres:
    container_name: guacamole_db
    hostname: guac_db
    environment:
      PGDATA: /var/lib/postgresql/data/guacamole
      POSTGRES_DB: guacamole_db
      POSTGRES_PASSWORD: 'ChooseYourOwnPasswordHere1234'
      POSTGRES_USER: guacamole_user
    image: postgres:15.2-alpine
    networks:
      frontend:
    restart: always
    volumes:
    - ./init:/docker-entrypoint-initdb.d:z
    - ./data:/var/lib/postgresql/data:Z
    
  # guacamole
  guacamole:
    container_name: guacamole
    tty: true
    stdin_open: true
    image: guacamole/guacamole    
    depends_on:
    - guacd
    - postgres
    environment:
      GUACD_HOSTNAME: guacd
      POSTGRES_DATABASE: guacamole_db
      POSTGRES_HOSTNAME: guac_db
      POSTGRES_PASSWORD: 'ChooseYourOwnPasswordHere1234'
      POSTGRES_USER: guacamole_user
      POSTGRESQL_AUTO_CREATE_ACCOUNTS: true
    
    links:
    - guacd
    ports:
      - 8080:8080    
    networks:
      - frontend
    restart: always
    volumes:
    - ./drive:/drive:rw