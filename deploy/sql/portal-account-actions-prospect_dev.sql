MERGE INTO PROSPECT_DEV.AUDITTXTPROS t USING (SELECT 7 c,'UpdatePortalAccount' a,'Update portal account' m FROM dual) s ON (t."Action Name"=s.a) WHEN NOT MATCHED THEN INSERT ("Code","Sub Code","Action Name","Message","Detail Message") VALUES (s.c,0,s.a,s.m,'Portal account administration; no passwords recorded');
MERGE INTO PROSPECT_DEV.AUDITTXTPROS t USING (SELECT 8 c,'ResetPortalLoginCount' a,'Reset invalid login count' m FROM dual) s ON (t."Action Name"=s.a) WHEN NOT MATCHED THEN INSERT ("Code","Sub Code","Action Name","Message","Detail Message") VALUES (s.c,0,s.a,s.m,'Portal account administration; no passwords recorded');
MERGE INTO PROSPECT_DEV.AUDITTXTPROS t USING (SELECT 9 c,'SetPortalPassword' a,'Set portal password' m FROM dual) s ON (t."Action Name"=s.a) WHEN NOT MATCHED THEN INSERT ("Code","Sub Code","Action Name","Message","Detail Message") VALUES (s.c,0,s.a,s.m,'Portal account administration; no passwords recorded');

-- Applied once: remove the legacy Debug Mode restriction.
DECLARE n NUMBER; BEGIN
 SELECT COUNT(*) INTO n FROM ALL_CONSTRAINTS WHERE OWNER='PROSPECT_DEV' AND CONSTRAINT_NAME='PROSPECT_DEBUG_MODE_T_CK';
 IF n>0 THEN EXECUTE IMMEDIATE 'ALTER TABLE PROSPECT_DEV.PROSPECT DROP CONSTRAINT PROSPECT_DEBUG_MODE_T_CK'; END IF;
 SELECT COUNT(*) INTO n FROM ALL_TAB_COLUMNS WHERE OWNER='PROSPECT_DEV' AND TABLE_NAME='PROSPECT' AND COLUMN_NAME='Debug Mode' AND NULLABLE='N';
 IF n>0 THEN EXECUTE IMMEDIATE 'ALTER TABLE PROSPECT_DEV.PROSPECT MODIFY ("Debug Mode" NULL)'; END IF;
END;
/
COMMIT;
MERGE INTO PROSPECT_DEV.AUDITTXTPROS t USING (SELECT 10 c,'GetPortalCustomers' a,'List portal customers' m FROM dual) s ON (t."Action Name"=s.a) WHEN NOT MATCHED THEN INSERT ("Code","Sub Code","Action Name","Message") VALUES (s.c,0,s.a,s.m);
MERGE INTO PROSPECT_DEV.AUDITTXTPROS t USING (SELECT 11 c,'GetPortalContacts' a,'List customer contacts' m FROM dual) s ON (t."Action Name"=s.a) WHEN NOT MATCHED THEN INSERT ("Code","Sub Code","Action Name","Message") VALUES (s.c,0,s.a,s.m);
COMMIT;
