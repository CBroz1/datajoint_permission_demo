-- Role Grant Bug MWE - INSERT Test
-- Tests if user can INSERT with role-based grants (will fail)

INSERT INTO one_a.parent (data) VALUES ('test with role');
