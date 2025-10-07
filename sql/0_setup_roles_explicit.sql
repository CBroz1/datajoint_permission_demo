-- Test: Role-based grants with EXPLICIT database names (not wildcards)
-- Purpose: Test if roles work when using explicit db names instead of wildcard patterns

-- Drop existing users and roles
DROP USER IF EXISTS 'user1'@'%';
DROP USER IF EXISTS 'user2'@'%';
DROP USER IF EXISTS 'admin'@'%';
DROP ROLE IF EXISTS 'dj_user';

-- Create admin user (for setup operations)
CREATE USER 'admin'@'%' IDENTIFIED BY 'tutorial';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;

-- Create role with EXPLICIT database names (NOT wildcard patterns)
CREATE ROLE 'dj_user';
GRANT USAGE ON *.* TO 'dj_user';
GRANT SELECT ON `%`.* TO 'dj_user';
GRANT REFERENCES ON `%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `one_a`.* TO 'dj_user';  -- EXPLICIT
GRANT ALL PRIVILEGES ON `two_a`.* TO 'dj_user';  -- EXPLICIT
-- INTENTIONALLY OMITTED: three_a

-- Create user1 with role-based grants
CREATE USER 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT 'dj_user' TO 'user1'@'%';
SET DEFAULT ROLE ALL TO 'user1'@'%';

-- Create user2 with role-based grants (same as user1)
CREATE USER 'user2'@'%' IDENTIFIED BY 'tutorial';
GRANT 'dj_user' TO 'user2'@'%';
SET DEFAULT ROLE ALL TO 'user2'@'%';

FLUSH PRIVILEGES;

-- Verification
SELECT 'User grants created (roles with EXPLICIT database names)' AS status;
SHOW GRANTS FOR 'dj_user';
SHOW GRANTS FOR 'user1'@'%';
SHOW GRANTS FOR 'user2'@'%';
