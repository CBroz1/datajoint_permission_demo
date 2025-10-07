-- Test: Both users with DIRECT grants (no roles)
-- Purpose: Isolate if role-based grants cause error verbosity difference

-- Drop existing users and roles
DROP USER IF EXISTS 'user1'@'%';
DROP USER IF EXISTS 'user2'@'%';
DROP USER IF EXISTS 'admin'@'%';
DROP ROLE IF EXISTS 'dj_user';

-- Create admin user (for setup operations)
CREATE USER 'admin'@'%' IDENTIFIED BY 'tutorial';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;

-- Create user1 with DIRECT grants (no role)
CREATE USER 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT USAGE ON *.* TO 'user1'@'%';
GRANT SELECT ON `%`.* TO 'user1'@'%';
GRANT REFERENCES ON `%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user1'@'%';
-- Intentionally omit ALL on three_% (test hypothesis)

-- Create user2 with DIRECT grants (no role) - SAME as user1
CREATE USER 'user2'@'%' IDENTIFIED BY 'tutorial';
GRANT USAGE ON *.* TO 'user2'@'%';
GRANT SELECT ON `%`.* TO 'user2'@'%';
GRANT REFERENCES ON `%`.* TO 'user2'@'%';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user2'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user2'@'%';
-- Intentionally omit ALL on three_% (test hypothesis)

FLUSH PRIVILEGES;

-- Verification
SELECT 'User grants created (both direct, no roles)' AS status;
SHOW GRANTS FOR 'user1'@'%';
SHOW GRANTS FOR 'user2'@'%';
