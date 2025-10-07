-- Role Grant Bug MWE - Fix with Direct Grants
-- Removes role and adds direct grant to user1

REVOKE 'dj_user' FROM 'user1'@'%';
GRANT ALL PRIVILEGES ON `one_a`.* TO 'user1'@'%';
FLUSH PRIVILEGES;

SELECT 'Removed role, added direct grant to user1' AS status;
