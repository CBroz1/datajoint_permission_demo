-- Create `common_one.one` table
CREATE DATABASE IF NOT EXISTS common_one;

USE common_one;

CREATE TABLE IF NOT EXISTS `one` (
  a INT NOT NULL,
  PRIMARY KEY (a)
);

CREATE TABLE IF NOT EXISTS `two` (
  b INT NOT NULL,
  a INT,
  PRIMARY KEY (b),
  FOREIGN KEY (a) REFERENCES common_one.one(a)
);

