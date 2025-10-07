-- ============================================================================
-- Role-Based User Setup for Error Verbosity Testing
-- ============================================================================
-- HYPOTHESIS: Users lacking privileges on FK-referencing tables (three_a)
-- receive less verbose error messages when deleting parent rows.
--
-- This script creates users with different grant mechanisms:
-- - user1: Direct grants (NO role) - Has ALL on one_%, two_% only
-- - user2: Role-based grants - Has ALL on one_%, two_% only
--
-- CRITICAL: Neither user has ALL privileges on three_% schemas.
-- This tests if missing privileges on an FK-referencing table causes
-- MySQL to return ERROR 1217 (non-verbose) instead of ERROR 1451 (verbose).
-- ============================================================================

-- Clean up existing users and roles
DROP USER IF EXISTS 'user1'@'%';
DROP USER IF EXISTS 'user2'@'%';
DROP ROLE IF EXISTS 'dj_user';

-- Create admin user (for schema creation)
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'tutorial';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';

-- ============================================================================
-- Create Role: dj_user
-- ============================================================================
CREATE ROLE 'dj_user';
GRANT SELECT ON `%`.* TO 'dj_user';
GRANT REFERENCES ON `%`.* TO 'dj_user';
GRANT USAGE ON `%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'dj_user';
-- INTENTIONALLY OMITTED: ALL on three\_%
-- Users will have SELECT, REFERENCES, USAGE on three_a (via global grants)
-- but NOT ALL privileges (no INSERT, UPDATE, DELETE, etc.)

-- ============================================================================
-- Create User1: Direct grants (NO role)
-- ============================================================================
CREATE USER 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT SELECT ON `%`.* TO 'user1'@'%';
GRANT REFERENCES ON `%`.* TO 'user1'@'%';
GRANT USAGE ON `%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user1'@'%';
-- INTENTIONALLY OMITTED: ALL on three\_%

-- ============================================================================
-- Create User2: Role-based grants
-- ============================================================================
CREATE USER 'user2'@'%' IDENTIFIED BY 'tutorial';
GRANT 'dj_user' TO 'user2'@'%';
SET DEFAULT ROLE ALL TO 'user2'@'%';

-- ============================================================================
-- Verification Queries
-- ============================================================================
SELECT '=== ROLE GRANTS ===' AS '';
SHOW GRANTS FOR 'dj_user';

SELECT '=== USER1 GRANTS (direct) ===' AS '';
SHOW GRANTS FOR 'user1'@'%';

SELECT '=== USER2 GRANTS (role-based) ===' AS '';
SHOW GRANTS FOR 'user2'@'%';

-- Display summary
SELECT CONCAT('Created users: admin, user1 (direct grants), user2 (role: dj_user)') AS summary;

FLUSH PRIVILEGES;
