-- ============================================================================
-- Delete Test for FK Error Verbosity
-- ============================================================================
-- Attempts to delete parent row that has FK constraints blocking it.
-- Expected behavior:
-- - user1 (direct grants): Should see verbose ERROR 1451 with FK details
-- - user2 (role-based grants): May see non-verbose ERROR 1217
-- ============================================================================

-- Test 1: Delete parent with children in BOTH tables (most complex case)
DELETE FROM one_a.parent WHERE id = 1;
