SET identity_insert Family ON;
:r Static/0_Family.sql
SET identity_insert Family OFF;
SET identity_insert Given ON;
:r Static/0_Given.sql
SET identity_insert Given OFF;
-- :r Static/0_TimeZone.sql
:r Static/0_Culture.sql
SET identity_insert Word ON;
:r Static/0_Word.sql
SET identity_insert Word OFF;
-- Timezone
--SET identity_insert Area ON;
--:r Static/1_Area.sql
SET identity_insert Country ON;
:r Static/1_Country.sql
SET identity_insert Country OFF;
SET identity_insert Entity ON;
:r Static/1_Entity.sql
SET identity_insert Entity OFF;
SET identity_insert Name ON;
:r Static/1_Name.sql
SET identity_insert Name OFF;
SET identity_insert Sentence ON;
:r Static/1_Sentence.sql
SET identity_insert Sentence OFF;
SET identity_insert Word ON;
:r Static/1_Word_agent.sql
SET identity_insert Word OFF;
-- GetSentence
--SET identity_insert Event ON;
--:r Static/2_Event.sql
-- GetAddress
--SET identity_insert Address ON;
--:r Static/3_Address.sql
SET identity_insert Email ON;
:r Static/3_Email.sql
SET identity_insert Email OFF;
SET identity_insert Individual ON;
:r Static/3_Individual.sql
SET identity_insert Individual OFF;
SET identity_insert Path ON;
:r Static/3_Path.sql
SET identity_insert Path OFF;
:r Static/4_IndividualEmail.sql
:r Static/4_IndividualPath.sql
:r Static/4_ListIndividual.sql
SET identity_insert ListIndividualName ON;
:r Static/4_ListIndividualName.sql
SET identity_insert ListIndividualName OFF;
SET identity_insert Phone ON;
:r Static/4_Phone.sql
SET identity_insert Phone OFF;
-- [false]
--SET identity_insert GeneralLedger ON;
--:r Static/5_GeneralLedger.sql
