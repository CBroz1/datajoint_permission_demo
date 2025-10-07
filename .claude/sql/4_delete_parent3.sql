-- ============================================================================
-- Delete Test: Parent 3 (Referenced by three_a ONLY)
-- ============================================================================
-- Target: Parent 3, which has FK reference in three_a.child only
-- User privileges: SELECT ONLY on three_a (user LACKS ALL on blocking table)
--
-- HYPOTHESIS TEST: This is the critical test case.
-- Expected behavior:
-- - Users may see non-verbose ERROR 1217 (no FK constraint details)
-- - This would confirm that lacking privileges on the FK-referencing table
--   causes MySQL to suppress detailed FK error information
-- ============================================================================

DELETE FROM one_a.parent WHERE id = 3;
