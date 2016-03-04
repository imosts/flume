
--
-- A SQL definition file for the tables used by traz's IDD
-- 
--  mysqladmin create database idd
--  mysql idd < <thisfile>  
--

--
-- Debug sequential IDs
--
CREATE TABLE IF NOT EXISTS debug_seq (
	id INTEGER UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY
) ENGINE = MyISAM;

--
-- Can descriminate if a handle is a group or a regular handle based
-- on the high-order bits, as we can in C.
--
-- Recall, of course, that handles must be randomly generated, and hence
-- we cannot rely on MySQL's auto increment scheme.  With low probability,
-- a handle creation will fail, and IDD will be forced to try again.
--
-- For debugging purproses, handle descriptions can be specified, 
-- but they are neither mandatory nor guaranteed to be unique.
-- 
CREATE TABLE IF NOT EXISTS handles (
	handle BIGINT UNSIGNED NOT NULL PRIMARY KEY,
	type   TINYINT UNSIGNED NOT NULL,
	descr  VARCHAR(128)
) ENGINE = MyISAM;

--
-- Frozen label representations.
--
CREATE TABLE IF NOT EXISTS freezer (
	frozen BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	thawed VARCHAR(255) NOT NULL,
	UNIQUE INDEX thawed_index (thawed)
);

--
-- User can supply a token and a handle to get ownership over that
-- handle (as enforced by the RM).
-- 
-- The fixed parameter is for a "fixed" lifetime.  If not, then
-- the expiration is relative to last touch (as in Web sessions).
--
CREATE TABLE IF NOT EXISTS auth_tokens (
	id INTEGER UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	token  VARCHAR(40) NOT NULL,
	handle BIGINT UNSIGNED NOT NULL,
	created datetime NOT NULL,
	lasttouch datetime NOT NULL,
	duration INTEGER UNSIGNED NOT NULL,
	expired BOOLEAN NOT NULL,
	fixed BOOLEAN NOT NULL,
	INDEX (token, handle)
);

--
-- Describe which labels are used for a given group
--
CREATE TABLE IF NOT EXISTS group_labels (
       handle BIGINT UNSIGNED NOT NULL PRIMARY KEY,
       S BIGINT UNSIGNED NOT NULL,
       I BIGINT UNSIGNED NOT NULL,
       W BIGINT UNSIGNED NOT NULL 
);

--
-- Associate each non-group group member (such as plain handles)
-- with a group.  Here, there's no reason to index so that we can,
-- for instance, retrieve all members of a group.
--
CREATE TABLE IF NOT EXISTS group_members (
	handle BIGINT UNSIGNED NOT NULL,
	member BIGINT UNSIGNED NOT NULL,
	PRIMARY KEY (handle, member)
);

--
-- Might need to look at all subgroups in a group, so provide a separate
-- indexing system for subgroups.  Thus, a group's membership is split
-- up over two separate tables.
--
CREATE TABLE IF NOT EXISTS subgroups (
	handle BIGINT UNSIGNED NOT NULL,
	subgroup BIGINT UNSIGNED NOT NULL,
	PRIMARY KEY (handle, subgroup),
	INDEX handle_index (handle)
);


--
-- Nicknames are convenient human-recognizable names for handles
-- that humans might need and use.
--
CREATE TABLE IF NOT EXISTS nicknames (
	nickname VARCHAR(64) NOT NULL,
	handle BIGINT UNSIGNED NOT NULL,
	PRIMARY KEY (nickname)
);

--
-- Maps of 60-bit hashes to frozen labelsets
-- 
CREATE TABLE IF NOT EXISTS ghetto_ea_map (
	hash BIGINT UNSIGNED NOT NULL,
	extattr VARBINARY(80) NOT NULL,
	PRIMARY KEY (hash)
);



