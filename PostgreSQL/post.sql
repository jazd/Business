-- Do not allow duplicate words based on case
-- upper(value) is not allowed in an in-table constraint
CREATE UNIQUE INDEX word_value ON word(culture,upper(value));
