-- ============================================================================
-- User Setup: USAGE ONLY on three_% (No SELECT, No REFERENCES)
-- ============================================================================
-- Tests minimal privilege scenario.
-- Users have: USAGE only on three_% (NO SELECT, NO REFERENCES)
--
-- This tests if lacking even SELECT affects FK error reporting.
-- Expected: User may not even be able to see that three_a exists.
-- ============================================================================

-- Clean up existing users and roles
DROP USER IF EXISTS 'user1'@'%';
DROP USER IF EXISTS 'user2'@'%';
DROP ROLE IF EXISTS 'dj_user';

-- Create admin user
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'tutorial';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';

-- ============================================================================
-- Create Role: dj_user (USAGE only, NO SELECT, NO REFERENCES)
-- ============================================================================
CREATE ROLE 'dj_user';
GRANT USAGE ON `%`.* TO 'dj_user';
-- OMITTED: SELECT, REFERENCES on global
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'dj_user';
-- OMITTED: ALL on three_%

-- ============================================================================
-- Create User1: Direct grants (USAGE only)
-- ============================================================================
CREATE USER 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT USAGE ON `%`.* TO 'user1'@'%';
-- OMITTED: SELECT, REFERENCES on global
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
SELECT '=== ROLE GRANTS (USAGE only) ===' AS '';
SHOW GRANTS FOR 'dj_user';

SELECT '=== USER1 GRANTS (USAGE only) ===' AS '';
SHOW GRANTS FOR 'user1'@'%';

SELECT '=== USER2 GRANTS (role-based) ===' AS '';
SHOW GRANTS FOR 'user2'@'%';

SELECT CONCAT('Test variant: USAGE ONLY on three_% (NO SELECT, NO REFERENCES)') AS summary;

FLUSH PRIVILEGES;
