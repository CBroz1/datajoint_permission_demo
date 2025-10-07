-- FK Error Verbosity MWE - Test Data
-- Inserts parent with child in two_a only (not three_a)

INSERT INTO one_a.parent (data) VALUES ('Parent with child in two_a only');
INSERT INTO two_a.child (parent_id, data) VALUES (1, 'Child in two_a - BLOCKS delete');
-- Note: No rows in three_a.child (table exists but empty)

SELECT 'Test data inserted' AS status;
SELECT
    (SELECT COUNT(*) FROM two_a.child WHERE parent_id = 1) AS two_a_children,
    (SELECT COUNT(*) FROM three_a.child WHERE parent_id = 1) AS three_a_children;
