-- Insert test data for single child table schema
USE one_a;

-- Insert parent rows
INSERT INTO parent (data) VALUES
    ('Parent 1 - has child in two_a'),
    ('Parent 2 - has child in two_a'),
    ('Parent 3 - no children (can be deleted)');

-- Insert children in two_a
USE two_a;
INSERT INTO child (parent_id, data) VALUES
    (1, 'Child of parent 1 in two_a'),
    (2, 'Child of parent 2 in two_a');

-- Verification
SELECT 'Data inserted' AS status;
SELECT
    p.id,
    p.data AS parent_data,
    COUNT(c.id) AS child_count_two_a
FROM one_a.parent p
LEFT JOIN two_a.child c ON p.id = c.parent_id
GROUP BY p.id, p.data
ORDER BY p.id;
