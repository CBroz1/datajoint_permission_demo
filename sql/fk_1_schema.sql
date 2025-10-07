-- FK Error Verbosity MWE - Schema Creation
-- Creates one_a.parent with two FK-referencing child tables

-- Parent table
CREATE DATABASE one_a;
CREATE TABLE one_a.parent (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- Child table 1 (will have blocking FK)
CREATE DATABASE two_a;
CREATE TABLE two_a.child (
    id INT AUTO_INCREMENT PRIMARY KEY,
    parent_id INT NOT NULL,
    data VARCHAR(100),
    CONSTRAINT fk_two_a_child_parent
        FOREIGN KEY (parent_id)
        REFERENCES one_a.parent(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Child table 2 (will NOT have blocking FK, but constraint exists)
CREATE DATABASE three_a;
CREATE TABLE three_a.child (
    id INT AUTO_INCREMENT PRIMARY KEY,
    parent_id INT NOT NULL,
    data VARCHAR(100),
    CONSTRAINT fk_three_a_child_parent
        FOREIGN KEY (parent_id)
        REFERENCES one_a.parent(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

SELECT 'Schema created: one_a.parent → two_a.child, three_a.child' AS status;
