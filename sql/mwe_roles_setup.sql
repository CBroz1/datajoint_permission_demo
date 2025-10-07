-- Role Grant Bug MWE - User Setup with Role
-- Creates user1 with role-based grants (explicit database name)

DROP USER IF EXISTS 'admin'@'%';
DROP USER IF EXISTS 'user1'@'%';
DROP ROLE IF EXISTS 'dj_user';

-- Create admin
CREATE USER 'admin'@'%' IDENTIFIED BY 'tutorial';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';

-- Create role with explicit database name (not wildcard)
CREATE ROLE 'dj_user';
GRANT ALL PRIVILEGES ON `one_a`.* TO 'dj_user';

-- Create user1 with role
CREATE USER 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT 'dj_user' TO 'user1'@'%';
SET DEFAULT ROLE ALL TO 'user1'@'%';

FLUSH PRIVILEGES;
SELECT 'Setup: user1 with role (explicit db name)' AS status;
