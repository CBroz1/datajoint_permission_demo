-- ============================================================================
-- Test Data for FK Error Verbosity Testing
-- ============================================================================
-- CRITICAL: This tests different FK reference scenarios to isolate the
-- hypothesis that missing privileges on FK-referencing tables (three_a)
-- causes less verbose error messages.
--
-- Creates test scenario with multiple parent rows:
-- - Parent 1: Referenced by BOTH child tables (tests if three_a lack of privilege matters)
-- - Parent 2: Referenced by ONLY two_a.child (user HAS privileges, should be verbose)
-- - Parent 3: Referenced by ONLY three_a.child (user LACKS privileges, may be non-verbose)
-- - Parent 4: No references (can be deleted, no FK error)
-- - Parent 5: Referenced by two_a only (duplicate of parent 2, for additional testing)
-- ============================================================================

-- ============================================================================
-- Insert Parent Rows
-- ============================================================================
INSERT INTO one_a.parent (data) VALUES
    ('Parent 1 - has children in both tables'),
    ('Parent 2 - has child in two_a only (user HAS ALL privileges)'),
    ('Parent 3 - has child in three_a only (user LACKS ALL privileges)'),
    ('Parent 4 - no children (can be deleted)'),
    ('Parent 5 - has child in two_a only (duplicate test case)');

-- ============================================================================
-- Insert Child Rows in two_a.child
-- ============================================================================
INSERT INTO two_a.child (parent_id, data) VALUES
    (1, 'Child of Parent 1 in two_a'),
    (2, 'Child of Parent 2 in two_a'),
    (5, 'Child of Parent 5 in two_a');

-- ============================================================================
-- Insert Child Rows in three_a.child
-- ============================================================================
INSERT INTO three_a.child (parent_id, data) VALUES
    (1, 'Child of Parent 1 in three_a'),
    (3, 'Child of Parent 3 in three_a');

-- ============================================================================
-- Verification
-- ============================================================================
SELECT '=== Parent Rows ===' AS '';
SELECT id, data FROM one_a.parent ORDER BY id;

SELECT '=== Child Rows in two_a ===' AS '';
SELECT id, parent_id, data FROM two_a.child ORDER BY id;

SELECT '=== Child Rows in three_a ===' AS '';
SELECT id, parent_id, data FROM three_a.child ORDER BY id;

SELECT '=== FK Relationship Summary ===' AS '';
SELECT
    p.id AS parent_id,
    p.data AS parent_data,
    COUNT(DISTINCT t.id) AS two_a_children,
    COUNT(DISTINCT th.id) AS three_a_children
FROM one_a.parent p
LEFT JOIN two_a.child t ON p.id = t.parent_id
LEFT JOIN three_a.child th ON p.id = th.parent_id
GROUP BY p.id, p.data
ORDER BY p.id;
