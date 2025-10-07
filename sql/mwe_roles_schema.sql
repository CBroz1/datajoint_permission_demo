-- Role Grant Bug MWE - Schema Creation
-- Creates simple one_a.parent table

CREATE DATABASE one_a;
CREATE TABLE one_a.parent (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

SELECT 'Schema created: one_a.parent' AS status;
