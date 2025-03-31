# MySQL Permission Error Demo

This repo aims to replicate an error that users with
limited privelages experience when deleting entries from tables despite having
`ALL PRIVILEGES` on the database.

run `main.sh` to see the error in action:

```text
> ./main.sh
Creating users and tables...
users: user1, user2

Normal: user1 delete shows blocked by fk ref...
ERROR 1451 (23000) at line 1: Cannot delete or update a parent row

Unexpected: user2 shows permission error...
ERROR 1142 (42000) at line 1: DELETE command denied to user 'user2'@'localhost' for table 'one'
Despite having ALL PRIVILEGES on this prefix...
GRANT ALL PRIVILEGES ON `common%`.`%` TO `user2`@`%`

Adding table-specific grant results in expected error...
ERROR 1451 (23000) at line 1: Cannot delete or update a parent row
```

This error is caused by the discrepancy in grants across basic users:

```sql
GRANT ALL PRIVILEGES ON `common%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `common`.`%` TO 'user2'@'%';
```

While the former matches all tables with this prefix wildcard, the latter calls
some form of search on table names, and may only apply to pre-existing tables.
