-- Drop the user if it exists
DROP USER IF EXISTS 'user1';
DROP USER IF EXISTS 'user2';

-- Create a user
CREATE USER IF NOT EXISTS 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT USAGE, SELECT ON `%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `common%`.* TO 'user1'@'%';

-- Create another user, with the same privileges
CREATE USER IF NOT EXISTS 'user2'@'%' IDENTIFIED BY 'tutorial';
GRANT USAGE, SELECT ON `%`.* TO 'user2'@'%';
GRANT ALL PRIVILEGES ON `common%`.`%` TO 'user2'@'%';

SELECT CONCAT('users: ', GROUP_CONCAT(user SEPARATOR ', ')) as msg
  FROM mysql.user
  WHERE USER LIKE 'user%';

FLUSH PRIVILEGES;
