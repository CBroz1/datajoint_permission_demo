-- FK Error Verbosity MWE - User Setup
-- Creates admin and user1 with direct grants (no role)
-- User1 has ALL on one_%, two_% but NOT three_%

DROP USER IF EXISTS 'admin'@'%';
DROP USER IF EXISTS 'user1'@'%';

-- Create admin
CREATE USER 'admin'@'%' IDENTIFIED BY 'tutorial';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';

-- Create user1 with direct grants (no role)
CREATE USER 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT USAGE ON *.* TO 'user1'@'%';
GRANT SELECT ON `%`.* TO 'user1'@'%';
GRANT REFERENCES ON `%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user1'@'%';
-- CRITICAL: Intentionally omit ALL on three_%
-- User has only SELECT, REFERENCES, USAGE on three_%

FLUSH PRIVILEGES;
SELECT 'Users created: admin, user1 (direct grants)' AS status;
