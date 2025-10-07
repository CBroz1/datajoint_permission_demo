-- ============================================================================
-- User Setup: SELECT ONLY on three_% (No REFERENCES)
-- ============================================================================
-- Tests if REFERENCES privilege affects FK error verbosity.
-- Users have: SELECT + USAGE on three_% (NO REFERENCES)
--
-- Compare with:
-- - 0_setup_roles.sql (has SELECT + REFERENCES + USAGE)
-- - 0_setup_roles_with_three.sql (has ALL)
-- ============================================================================

-- Clean up existing users and roles
DROP USER IF EXISTS 'user1'@'%';
DROP USER IF EXISTS 'user2'@'%';
DROP ROLE IF EXISTS 'dj_user';

-- Create admin user
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'tutorial';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';

-- ============================================================================
-- Create Role: dj_user (SELECT + USAGE only, NO REFERENCES)
-- ============================================================================
CREATE ROLE 'dj_user';
GRANT SELECT ON `%`.* TO 'dj_user';
GRANT USAGE ON `%`.* TO 'dj_user';
-- OMITTED: REFERENCES (testing if this affects verbosity)
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'dj_user';
-- OMITTED: ALL on three_%

-- ============================================================================
-- Create User1: Direct grants (SELECT + USAGE, NO REFERENCES)
-- ============================================================================
CREATE USER 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT SELECT ON `%`.* TO 'user1'@'%';
GRANT USAGE ON `%`.* TO 'user1'@'%';
-- OMITTED: REFERENCES
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user1'@'%';
-- OMITTED: ALL on three_%

-- ============================================================================
-- Create User2: Role-based grants
-- ============================================================================
CREATE USER 'user2'@'%' IDENTIFIED BY 'tutorial';
GRANT 'dj_user' TO 'user2'@'%';
SET DEFAULT ROLE ALL TO 'user2'@'%';

-- ============================================================================
-- Verification
-- ============================================================================
SELECT '=== ROLE GRANTS (SELECT + USAGE, NO REFERENCES) ===' AS '';
SHOW GRANTS FOR 'dj_user';

SELECT '=== USER1 GRANTS (SELECT + USAGE, NO REFERENCES) ===' AS '';
SHOW GRANTS FOR 'user1'@'%';

SELECT '=== USER2 GRANTS (role-based) ===' AS '';
SHOW GRANTS FOR 'user2'@'%';

SELECT CONCAT('Test variant: SELECT + USAGE on three_% (NO REFERENCES)') AS summary;

FLUSH PRIVILEGES;
