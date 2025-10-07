-- Schema with SINGLE child table (no three_a)
-- Purpose: Test if having multiple FK-referencing tables matters

-- Drop existing schemas
DROP DATABASE IF EXISTS one_a;
DROP DATABASE IF EXISTS two_a;
DROP DATABASE IF EXISTS three_a;

-- Schema one_a: Parent table
CREATE DATABASE one_a;
USE one_a;

CREATE TABLE `parent` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- Schema two_a: Child table (ONLY child table)
CREATE DATABASE two_a;
USE two_a;

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

-- Verification
SELECT 'Schema created: one_a.parent, two_a.child ONLY' AS status;
SHOW TABLES FROM one_a;
SHOW TABLES FROM two_a;
