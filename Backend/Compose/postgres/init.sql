CREATE DATABASE guestdb;
CREATE DATABASE userdb;

-- Ensure the default postgres user has access
GRANT ALL PRIVILEGES ON DATABASE guestdb TO postgres;
GRANT ALL PRIVILEGES ON DATABASE userdb TO postgres;
