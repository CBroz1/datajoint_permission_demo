-- Test: Both users with ROLE-BASED grants
-- Purpose: Isolate if both users having roles changes error verbosity

-- Drop existing users and roles
DROP USER IF EXISTS 'user1'@'%';
DROP USER IF EXISTS 'user2'@'%';
DROP USER IF EXISTS 'admin'@'%';
DROP ROLE IF EXISTS 'dj_user';

-- Create admin user (for setup operations)
CREATE USER 'admin'@'%' IDENTIFIED BY 'tutorial';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;

-- Create role with SELECT, REFERENCES, USAGE globally
-- and ALL on one_% and two_% (but NOT three_%)
CREATE ROLE 'dj_user';
GRANT USAGE ON *.* TO 'dj_user';
GRANT SELECT ON `%`.* TO 'dj_user';
GRANT REFERENCES ON `%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'dj_user';
-- Intentionally omit ALL on three_% (test hypothesis)

-- Create user1 with role-based grants
CREATE USER 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT 'dj_user' TO 'user1'@'%';
SET DEFAULT ROLE ALL TO 'user1'@'%';

-- Create user2 with role-based grants (SAME as user1)
CREATE USER 'user2'@'%' IDENTIFIED BY 'tutorial';
GRANT 'dj_user' TO 'user2'@'%';
SET DEFAULT ROLE ALL TO 'user2'@'%';

FLUSH PRIVILEGES;

-- Verification
SELECT 'User grants created (both role-based)' AS status;
SHOW GRANTS FOR 'user1'@'%';
SHOW GRANTS FOR 'user2'@'%';
