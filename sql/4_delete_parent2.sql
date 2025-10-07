-- ============================================================================
-- Delete Test: Parent 2 (Referenced by two_a ONLY)
-- ============================================================================
-- Target: Parent 2, which has FK reference in two_a.child only
-- User privileges: ALL on two_a (user HAS full privileges on blocking table)
--
-- Expected behavior:
-- - Both users should see verbose ERROR 1451 with FK constraint details
-- - This confirms privilege is present on the FK-referencing table
-- ============================================================================

DELETE FROM one_a.parent WHERE id = 2;
