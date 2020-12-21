SET identity_insert Family ON;
:r Static\0_Family.sql
SET identity_insert Given ON;
:r Static\0_Given.sql
-- :r Static\0_TimeZone.sql
SET identity_insert Word ON;
:r Static\0_Word.sql
-- Timezone
--SET identity_insert Area ON;
--:r Static\1_Area.sql
:r Static\1_Country.sql
SET identity_insert Entity ON;
:r Static\1_Entity.sql
SET identity_insert Name ON;
:r Static\1_Name.sql
SET identity_insert Sentence ON;
:r Static\1_Sentence.sql
SET identity_insert Word ON;
:r Static\1_Word_agent.sql
-- GetSentence
--SET identity_insert Event ON;
--:r Static\2_Event.sql
-- GetAddress
--SET identity_insert Address ON;
--:r Static\3_Address.sql
SET identity_insert Email ON;
:r Static\3_Email.sql
SET identity_insert Individual ON;
:r Static\3_Individual.sql
SET identity_insert Path ON;
:r Static\3_Path.sql
SET identity_insert IndividualEmail ON;
:r Static\4_IndividualEmail.sql
SET identity_insert IndividualPath ON;
:r Static\4_IndividualPath.sql
SET identity_insert ListIndividual ON;
:r Static\4_ListIndividual.sql
SET identity_insert ListIndividualName ON;
:r Static\4_ListIndividualName.sql
SET identity_insert Phone ON;
:r Static\4_Phone.sql
-- [false]
--SET identity_insert GeneralLedger ON;
--:r Static\5_GeneralLedger.sql
