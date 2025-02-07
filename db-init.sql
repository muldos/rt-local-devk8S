CREATE USER jfrog WITH PASSWORD 'jfrog';

DROP DATABASE artifactory;
CREATE DATABASE artifactory WITH OWNER=jfrog ENCODING='UTF8';
GRANT ALL PRIVILEGES ON DATABASE artifactory TO jfrog;
DROP DATABASE xray;
CREATE DATABASE xray WITH OWNER=jfrog ENCODING='UTF8';
GRANT ALL PRIVILEGES ON DATABASE xray TO jfrog;
DROP DATABASE catalog;
CREATE DATABASE catalog WITH OWNER=jfrog ENCODING='UTF8';
GRANT ALL PRIVILEGES ON DATABASE catalog TO jfrog;