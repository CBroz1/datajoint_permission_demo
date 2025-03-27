-- Create `common_one.one` table
CREATE DATABASE IF NOT EXISTS common_one;

USE common_one;

CREATE TABLE IF NOT EXISTS `one` (
  a INT NOT NULL,
  b INT NOT NULL,
  PRIMARY KEY (a, b)
);

-- Create `common_two.two` table with a foreign key referencing `common_one.one`
CREATE DATABASE IF NOT EXISTS common_two;

USE common_two;

CREATE TABLE IF NOT EXISTS `two` (
  c INT NOT NULL,
  d INT NOT NULL,
  a INT,
  b INT,
  PRIMARY KEY (c, d),
  FOREIGN KEY (a, b) REFERENCES common_one.one(a, b)
);

