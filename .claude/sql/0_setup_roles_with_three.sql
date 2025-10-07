-- ============================================================================
-- Role-Based User Setup WITH three_% Privileges (Comparison Test)
-- ============================================================================
-- CONTROL TEST: This variant grants ALL privileges on three_% to both users.
-- This tests whether having full privileges on all FK-referencing tables
-- results in consistent verbose error messages.
--
-- Compare results with 0_setup_roles.sql (which omits three_% grants).
--
-- This script creates users with different grant mechanisms:
-- - user1: Direct grants (NO role) - Has ALL on one_%, two_%, three_%
-- - user2: Role-based grants - Has ALL on one_%, two_%, three_%
--
-- Expected: Both users should receive ERROR 1451 (verbose) with FK details.
-- ============================================================================

-- Clean up existing users and roles
DROP USER IF EXISTS 'user1'@'%';
DROP USER IF EXISTS 'user2'@'%';
DROP ROLE IF EXISTS 'dj_user';

-- Create admin user (for schema creation)
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'tutorial';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';

-- ============================================================================
-- Create Role: dj_user (WITH three_% grants)
-- ============================================================================
CREATE ROLE 'dj_user';
GRANT SELECT ON `%`.* TO 'dj_user';
GRANT REFERENCES ON `%`.* TO 'dj_user';
GRANT USAGE ON `%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `three\_%`.* TO 'dj_user';  -- INCLUDED in this variant

-- ============================================================================
-- Create User1: Direct grants (NO role, WITH three_% grants)
-- ============================================================================
CREATE USER 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT SELECT ON `%`.* TO 'user1'@'%';
GRANT REFERENCES ON `%`.* TO 'user1'@'%';
GRANT USAGE ON `%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `three\_%`.* TO 'user1'@'%';  -- INCLUDED in this variant

-- ============================================================================
-- Create User2: Role-based grants (WITH three_% via role)
-- ============================================================================
CREATE USER 'user2'@'%' IDENTIFIED BY 'tutorial';
GRANT 'dj_user' TO 'user2'@'%';
SET DEFAULT ROLE ALL TO 'user2'@'%';

-- ============================================================================
-- Verification Queries
-- ============================================================================
SELECT '=== ROLE GRANTS (WITH three_%) ===' AS '';
SHOW GRANTS FOR 'dj_user';

SELECT '=== USER1 GRANTS (direct, WITH three_%) ===' AS '';
SHOW GRANTS FOR 'user1'@'%';

SELECT '=== USER2 GRANTS (role-based, WITH three_%) ===' AS '';
SHOW GRANTS FOR 'user2'@'%';

-- Display summary
SELECT CONCAT('Created users WITH three_% grants: admin, user1 (direct), user2 (role: dj_user)') AS summary;

FLUSH PRIVILEGES;
