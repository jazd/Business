-- Business Schema is based on a schema I created back in 2002
--
-- Created Jan 20th - Aug 8th 2002 for Highschool class reunion
-- People Schema
--  people.name and people.address only for quick and easy display only.
--  also hs and hsyear.

CREATE SEQUENCE people_uid INCREMENT 1 START 319;
// gender CHAR(1), (MF)
// marital CHAR(1), (MSWD)
CREATE TABLE people (
uid INT8 DEFAULT nextval('people_uid'),
gender CHAR,
paternal INT8,
maternal INT8,
hs INT8,
hsyear INT2,
marital CHAR,
name INT8,
address INT8,
phone INT8,
email INT8,
url INT8,
photo INT8,
unusedint INT8,
unusedchar CHAR,
birth TIMESTAMP,
death TIMESTAMP,
stamp TIMESTAMP DEFAULT timeofday(),
PRIMARY KEY (uid),
FOREIGN KEY (paternal) REFERENCES people ON DELETE SET NULL,
FOREIGN KEY (maternal) REFERENCES people ON DELETE SET NULL
);

CREATE TABLE types (
type INT,
cat INT,
expand VARCHAR(12),
PRIMARY KEY (type)
);

CREATE SEQUENCE names_uid INCREMENT 1 START 385;
CREATE TABLE names (
uid INT8 DEFAULT nextval('names_uid'),
person INT8,
type INT,
last VARCHAR(20) NOT NULL,
first VARCHAR(20),
middle VARCHAR(20),
start TIMESTAMP,
stop TIMESTAMP,
stamp TIMESTAMP DEFAULT timeofday(),
PRIMARY KEY (uid),
FOREIGN KEY (person) REFERENCES people ON DELETE CASCADE,
FOREIGN KEY (type) REFERENCES types ON DELETE CASCADE
);

CREATE TABLE countries (
uid INT,
country VARCHAR(20),
PRIMARY KEY (uid)
);

CREATE TABLE zipcodes (
zip CHAR(5),
state CHAR(2),
city VARCHAR(40),
long REAL,
lat REAL,
country INT DEFAULT 1,
PRIMARY KEY (zip),
FOREIGN KEY (country) REFERENCES countries ON DELETE SET DEFAULT
);

CREATE SEQUENCE addresses_uid INCREMENT 1 START 218;
// type  smallINT, (birth,work,mailing,residence)
// ttype CHAR (D daily, W work days, Y yearly, M monthly, A any)
CREATE TABLE addresses (
uid INT8 DEFAULT nextval('addresses_uid'),
person INT8,
type INT REFERENCES types,
Marquee VARCHAR(40),
street1 VARCHAR(40),
street2 VARCHAR(40),
zip CHAR(5),
zipp4 CHAR(4),
country INT DEFAULT 1,
long REAL,
lat REAL,
ttype INT REFERENCES types,
private CHAR,
start TIMESTAMP,
stop TIMESTAMP,
tfrom TIMESTAMP,
tto TIMESTAMP,
stamp TIMESTAMP DEFAULT timeofday(),
PRIMARY KEY (uid),
FOREIGN KEY (person) REFERENCES people ON DELETE NO ACTION,
FOREIGN KEY (zip) REFERENCES zipcodes ON DELETE NO ACTION
);

CREATE SEQUENCE phones_uid INCREMENT 1 START 110;
// type CHAR, (W work, H home, C cell, M message, F fax, P pager, Contact)
CREATE TABLE phones (
uid INT8 DEFAULT nextval('phones_uid'),
person INT8 not null REFERENCES people(uid),
type INT REFERENCES types,
number VARCHAR(12),
extension VARCHAR(5),
ttype INT REFERENCES types,
private CHAR,
start TIMESTAMP,
stop TIMESTAMP,
tfrom TIMESTAMP,
tto TIMESTAMP,
stamp TIMESTAMP DEFAULT timeofday(),
PRIMARY KEY (uid),
FOREIGN KEY (person) REFERENCES people ON DELETE NO ACTION
);

// type INT, (W work,P people)
CREATE TABLE emails (
uid INT8 DEFAULT nextval('emails_uid'),
person INT8,
type INT REFERENCES types,
email VARCHAR(40),
private CHAR,
start TIMESTAMP,
stop TIMESTAMP,
stamp TIMESTAMP DEFAULT timeofday(),
PRIMARY KEY (uid),
FOREIGN KEY (person) REFERENCES people ON DELETE CASCADE
);

CREATE SEQUENCE urls_uid INCREMENT 1 START 1;
// type CHAR, (W work, P people, F favorite, L links)
CREATE TABLE urls (
uid INT8 unique primary key DEFAULT nextval('urls_uid'),
person INT8 not null REFERENCES people(uid),
type CHAR,
title VARCHAR(50),
url VARCHAR(100),
private CHAR,
start TIMESTAMP,
stop TIMESTAMP,
stamp TIMESTAMP DEFAULT timeofday()
);

CREATE SEQUENCE photos_uid INCREMENT 1 START 739;
// size CHAR, (M mini,T thumb,D display,F full)
// type INT, (1 portrate,2 group,3 favorite,4 family,5 places,6 friends)
CREATE TABLE photos (
uid INT8 DEFAULT nextval('photos_uid'),
person INT8 not null REFERENCES people(uid),
size CHAR,
type INT REFERENCES types,
url VARCHAR(100),
private CHAR,
start TIMESTAMP,
stop TIMESTAMP,
stamp TIMESTAMP DEFAULT timeofday(),
PRIMARY KEY (uid),
FOREIGN KEY (person) REFERENCES people ON DELETE NO ACTION
);

CREATE SEQUENCE spouses_uid INCREMENT 1 START 1;
CREATE TABLE spouses (
uid INT8 unique primary key DEFAULT nextval('spouses_uid'),
person1 INT8 not null REFERENCES people(uid),
person2 INT8 not null REFERENCES people(uid),
start TIMESTAMP,
stop TIMESTAMP,
stamp TIMESTAMP DEFAULT timeofday()
);

CREATE SEQUENCE texts_uid INCREMENT 1 START 1;
// type CHAR, (B bio, S short)
CREATE TABLE texts (
uid INT8 unique primary key DEFAULT nextval('texts_uid'),
type INT REFERENCES types,
person INT8 not null REFERENCES people(uid),
data TEXT,
private CHAR,
stamp TIMESTAMP DEFAULT timeofday()
);

CREATE SEQUENCE schools_uid INCREMENT 1 START 1;
// type CHAR, (H high, G grade, C colledge)
CREATE TABLE schools (
uid INT8 unique primary key DEFAULT nextval('schools_uid'),
type INT REFERENCES types,
name VARCHAR(40),
address INT8 REFERENCES addresses(uid),
private CHAR,
start TIMESTAMP,
stop TIMESTAMP,
stamp TIMESTAMP DEFAULT timeofday()
);

CREATE SEQUENCE educations_uid INCREMENT 1 START 1;
CREATE TABLE educations (
uid INT8 unique primary key DEFAULT nextval('educations_uid'),
school INT8 REFERENCES schools(uid),
major VARCHAR(30),
degree VARCHAR(30),
private CHAR,
start TIMESTAMP,
stop TIMESTAMP,
stamp TIMESTAMP DEFAULT timeofday()
);

CREATE SEQUENCE careers_uid INCREMENT 1 START 1;
CREATE TABLE careers (
uid INT8 unique primary key DEFAULT nextval('careers_uid'),
person INT8 not null REFERENCES people(uid),
title VARCHAR(20),
address INT8 REFERENCES addresses(uid),
private CHAR,
start TIMESTAMP,
stop TIMESTAMP,
stamp TIMESTAMP DEFAULT timeofday()
);


CREATE SEQUENCE mailings_uid INCREMENT 1 START 1;
CREATE TABLE mailings (
uid INT8 DEFAULT nextval('mailings_uid'),
mailing INT8,
person INT8,
type INT REFERENCES types,
start TIMESTAMP,
stop TIMESTAMP,
stamp TIMESTAMP DEFAULT timeofday(),
PRIMARY KEY (uid),
FOREIGN KEY (person) REFERENCES people ON DELETE NO ACTION,
FOREIGN KEY (zip) REFERENCES zipcodes ON DELETE NO ACTION
);

CREATE SEQUENCE biographies_uid INCREMENT 1 START 1;
CREATE TABLE biographies (
uid INT8 DEFAULT nextval('biographies_uid'),
person INT8 not null REFERENCES people(uid),
title CHARACTER(40),
content TEXT,
stamp TIMESTAMP DEFAULT timeofday(),
PRIMARY KEY (uid),
FOREIGN KEY (person) REFERENCES people ON DELETE CASCADE
);
