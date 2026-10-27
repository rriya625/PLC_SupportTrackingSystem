-- Run as the schema owner (PROSPECT_DEV or PROSPECT).
-- Nullable by design: no NOT NULL or CHECK constraints.
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM USER_TAB_COLUMNS
    WHERE TABLE_NAME = 'PROSPECT' AND COLUMN_NAME = 'Do Not Load Tickets On Load';
  IF n = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE PROSPECT ADD ("Do Not Load Tickets On Load" VARCHAR2(1) DEFAULT ''F'')';
  END IF;
END;
/
-- Enable for a selected account only when requested:
-- UPDATE PROSPECT SET "Do Not Load Tickets On Load" = 'T' WHERE "Key" = :ProspectKey;
-- COMMIT;
