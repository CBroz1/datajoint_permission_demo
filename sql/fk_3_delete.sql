-- FK Error Verbosity MWE - Delete Test
-- Attempts to delete parent (should show ERROR 1217)

DELETE FROM one_a.parent WHERE id = 1;
