-- Create a new user 'basic' and set a temporary password
CREATE USER IF NOT EXISTS 'basic'@'%' IDENTIFIED BY 'tutorial';

-- Grant USAGE privilege on all databases to 'basic' user
GRANT USAGE ON `%`.* TO 'basic'@'%';

-- Grant SELECT privilege on all databases 
GRANT SELECT ON `%`.* TO 'basic'@'%';

-- Grant ALL on test database
GRANT ALL PRIVILEGES ON `test\_%`.* TO `basic`@`%`;
GRANT ALL PRIVILEGES ON `common\_%`.* TO `basic`@`%`;
GRANT ALL PRIVILEGES ON `spikesorting\_%`.* TO `basic`@`%`;
GRANT ALL PRIVILEGES ON `lfp\_%`.* TO `basic`@`%`;
GRANT ALL PRIVILEGES ON `position\_%`.* TO `basic`@`%`;
GRANT ALL PRIVILEGES ON `ripple\_%`.* TO `basic`@`%`;

