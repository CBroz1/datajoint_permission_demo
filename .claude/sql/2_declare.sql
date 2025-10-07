-- ============================================================================
-- Schema Creation for FK Error Verbosity Testing
-- ============================================================================
-- Creates 3 schemas with parent/child FK relationships:
-- - one_a.parent (PK: id)
-- - two_a.child (FK → one_a.parent)
-- - three_a.child (FK → one_a.parent)
-- ============================================================================

-- ============================================================================
-- Schema one_a: Parent table
-- ============================================================================
CREATE DATABASE IF NOT EXISTS one_a;
USE one_a;

DROP TABLE IF EXISTS `parent`;

CREATE TABLE `parent` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- ============================================================================
-- Schema two_a: Child table 1
-- ============================================================================
CREATE DATABASE IF NOT EXISTS two_a;
USE two_a;

DROP TABLE IF EXISTS `child`;

CREATE TABLE `child` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    parent_id INT NOT NULL,
    data VARCHAR(100),
    CONSTRAINT fk_two_a_child_parent
        FOREIGN KEY (parent_id)
        REFERENCES one_a.parent(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ============================================================================
-- Schema three_a: Child table 2
-- ============================================================================
CREATE DATABASE IF NOT EXISTS three_a;
USE three_a;

DROP TABLE IF EXISTS `child`;

CREATE TABLE `child` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    parent_id INT NOT NULL,
    data VARCHAR(100),
    CONSTRAINT fk_three_a_child_parent
        FOREIGN KEY (parent_id)
        REFERENCES one_a.parent(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ============================================================================
-- Verification
-- ============================================================================
SELECT '=== Schema Structure ===' AS '';
SELECT
    'one_a.parent' AS 'Table',
    'id (PK, AUTO_INCREMENT)' AS 'Primary Key',
    'data VARCHAR(100)' AS 'Columns',
    '-' AS 'Foreign Keys'
UNION ALL
SELECT
    'two_a.child',
    'id (PK, AUTO_INCREMENT)',
    'parent_id INT, data VARCHAR(100)',
    'FK: parent_id → one_a.parent(id) RESTRICT'
UNION ALL
SELECT
    'three_a.child',
    'id (PK, AUTO_INCREMENT)',
    'parent_id INT, data VARCHAR(100)',
    'FK: parent_id → one_a.parent(id) RESTRICT';

SELECT 'Schemas created: one_a, two_a, three_a' AS summary;

