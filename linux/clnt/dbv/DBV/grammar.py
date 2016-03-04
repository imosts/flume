""" SQL grammar, partial, based on ODBC 2.0 programmer's ref

:Author: Aaron Watters
:Maintainers: http://gadfly.sf.net/
:Copyright: Aaron Robert Watters, 1994
:Id: $Id: grammar.py,v 1.4 2002/05/11 02:59:04 richard Exp $:
"""

# TODO: someday add subquery precedence to allow more general selects.

def DeclareTerminals(Grammar):
    import string

    # user_defined_name
    alphanum = string.letters+string.digits + "_"
    userdefre = "[%s][%s]*"%(string.letters +"_", alphanum)
    def userdeffn(str):
        from string import upper
        return upper(str)
    Grammar.Addterm("user_defined_name", userdefre, userdeffn)

    # character_string_literal
    charstre = r"'(?:[^']|'')*'"
    #charstre = "'[^']*'"
    def charstfn(str):
        return '\'' + str[1:-1] + '\''
    Grammar.Addterm("character_string_literal", charstre, charstfn)

    # numeric_literal
    digits = string.digits
    intre = "[%s][%s.jJ]*"%(digits,digits)
    numlitre = "%s([Ee][+-]?%s)?"%(intre, intre)
    def numlitfn(str):
        """Note: this is "safe" because regex filters out dangerous things.
        """
        return eval(str)
    Grammar.Addterm("numeric_literal", numlitre, numlitfn)

sqlrules = """

statement_list ::

@R stat1 :: statement_list >> statement optsemicolon
@R statn :: statement_list >> statement ; statement_list

@R semicolon0 :: optsemicolon >>
@R semicolon1 :: optsemicolon >> ;

## Disabled for now
##@R dropindexstat :: statement >> drop_index_statement
@R createindexstat :: statement >> create_index_statement

@R selstat :: statement >> select_statement

@R insstat :: statement >> insert_statement

@R createtablestat :: statement >> create_table_statement

@R droptablestat :: statement >> drop_table_statement

@R delstat :: statement >> delete_statement_searched

@R updatestat :: statement >> update_statement_searched

@R setstat :: statement >> set_statement

@R showstat :: statement >> show_statement

@R beginstat :: statement >> begin_statement
@R commitstat :: statement >> commit_statement
@R abortstat :: statement >> abort_statement
@R myolabelstat :: statement >> MYOLABEL character_string_literal
@R deslsstat :: statement >> DESLS character_string_literal
@R specialcasestat :: statement >> specialcase_statement
@R filterstat :: statement >> filter_statement


## Disabled for now
##@R createviewstat :: statement >> create_view_statement
##@R dropviewstat :: statement >> drop_view_statement

## drop view statement
@R dropview :: drop_view_statement >> DROP VIEW user_defined_name

## create view statement
@R createview :: create_view_statement >>
    CREATE VIEW user_defined_name optnamelist AS select_statement
@R optnamelist0 :: optnamelist >>
@R optnamelistn :: optnamelist >> ( simplenamelist )

## drop index statement
@R dropindex :: drop_index_statement >> DROP INDEX user_defined_name

## create index statement
@R createindex :: create_index_statement >>
     CREATE INDEX user_defined_name
     ON user_defined_name
     ( simplenamelist )

@R createuniqueindex :: create_index_statement >>
     CREATE UNIQUE INDEX user_defined_name
     ON user_defined_name
     ( simplenamelist )

## namelist differs from colnamelist because namelist does not have the
## TableName.ColumnID syntax
@R names1 :: simplenamelist >> simplecolname
@R namesn :: simplenamelist >> simplenamelist , simplecolname
@R simplecolname1 :: simplecolname >> user_defined_name

## update statement
@R update :: update_statement_searched >>
     UPDATE user_defined_name
     SET assns
     optwhere

@R assn1 :: assns >> assn
@R assnn :: assns >> assns , assn
@R assn :: assn >> column_identifier = expression

#####

## delete statement
@R deletefrom :: delete_statement_searched >> DELETE FROM user_defined_name optwhere

## drop table
@R droptable :: drop_table_statement >> DROP TABLE user_defined_name

## create table statement ( restricted )
@R createtable :: create_table_statement >>
    CREATE TABLE user_defined_name ( colelts )
@R colelts1 :: colelts >> colelt
@R coleltsn :: colelts >> colelts , colelt

@R coleltid :: colelt >> column_definition
@R coleltconstraint :: colelt >> column_constraint_definition

## column definitions
@R coldef :: column_definition >>
    column_identifier data_type optdefault optcolconstraints

## optcolconstraints
@R optcolconstr1 :: optcolconstraints >> optcolconstraint
@R optcolconstr2 :: optcolconstraints >> optcolconstraint optcolconstraint

@R optcolconstr_empty :: optcolconstraint >>
@R optcolconstr_notnull :: optcolconstraint >> NOT NULL
@R optcolconstr_prikey :: optcolconstraint >> PRIMARY KEY
@R optcolconstr_unique :: optcolconstraint >> UNIQUE

## optdefault deferred
@R optdef0 :: optdefault >>

## column_constraint_definition
@R colconstraint_unique :: column_constraint_definition >>
    UNIQUE ( colids )
@R colconstraint_prikey :: column_constraint_definition >>
    PRIMARY KEY ( colids )
@R colconstraint_foreignkey :: column_constraint_definition >>
    FOREIGN KEY ( colids ) REFERENCES user_defined_name ( colids )

@R stringtype :: data_type >> character_string_type
@R exnumtype :: data_type >> exact_numeric_type
@R appnumtype :: data_type >> approximate_numeric_type
@R timetype :: data_type >> exact_time_type 
@R integer :: exact_numeric_type >> INTEGER
@R smallint :: exact_numeric_type >> SMALLINT
@R bigint :: exact_numeric_type >> BIGINT
@R boolean :: exact_numeric_type >> BOOLEAN
@R float :: approximate_numeric_type >> FLOAT
@R varchar :: character_string_type >> VARCHAR
@R varcharn :: character_string_type >> VARCHAR ( numeric_literal )
@R timestamp :: exact_time_type >> TIMESTAMPTZ
@R date :: exact_time_type >> DATE

## insert statement

@R insert1 :: insert_statement >>
    INSERT INTO table_name optcolids insert_spec
@R optcolids0 :: optcolids >>
@R optcolids1 :: optcolids >> ( colids )
@R colids1 :: colids >> column_identifier
@R colidsn :: colids >> colids , column_identifier
@R insert_values :: insert_spec >> VALUES ( litlist )

## Don't allow subquery inserts for now (security reasons)
@R insert_query :: insert_spec >> sub_query
@R litlist1 :: litlist >> sliteral
@R litlistn :: litlist >> litlist , sliteral
@R sliteral0 :: sliteral >> literal
@R sliteralp :: sliteral >> + literal

## hack to permit complexes

@R sliterals :: sliteral >> sliteral + literal
@R sliterald :: sliteral >> sliteral - literal
@R sliterala :: sliteral >> sliteral & literal
@R sliteralo :: sliteral >> sliteral | literal
@R sliteralm :: sliteral >> - literal

## select statement

@R subselect :: sub_query >>
     SELECT alldistinct select_list
     from_clause
     optwhere optgroup opthaving optunion

## only support simple, two table LEFT JOINs for now.
@R fromclause1 :: from_clause >> FROM table_reference_list
@R fromclause2 :: from_clause >>
     FROM table_reference LEFT JOIN table_reference
     ON column_name = column_name
@R fromclause3 :: from_clause >>
     FROM table_reference LEFT OUTER JOIN table_reference
     ON column_name = column_name
@R fromclause4 :: from_clause >>
     FROM table_reference INNER JOIN table_reference
     ON column_name = column_name

## @R psubselect :: sub_query >> ( sub_query )

@R selectx :: select_statement >>
     sub_query
     optorder_by
     optlimit
@R ad0 :: alldistinct >>
@R adall :: alldistinct >> ALL
@R addistinct :: alldistinct >> DISTINCT
@R where0 :: optwhere >>
@R where1 :: optwhere >> WHERE search_condition
@R group0 :: optgroup >>
@R group1 :: optgroup >> GROUP BY colnamelist
@R colnames1 :: colnamelist >> column_name
@R colnamesn :: colnamelist >> colnamelist , column_name
@R having0 :: opthaving >>
@R having1 :: opthaving >> HAVING search_condition
@R union0 :: optunion >>
@R union1 :: optunion >> UNION alldistinct sub_query
@R except1 :: optunion >> EXCEPT sub_query
@R intersect1 :: optunion >> INTERSECT sub_query
@R order0 :: optorder_by >>
@R order1 :: optorder_by >> ORDER BY sortspeclist
##@R orderby :: order_by_clause >> ORDER BY sortspeclist
@R sortspec1 :: sortspeclist >> sort_specification
@R sortspecn :: sortspeclist >> sortspeclist , sort_specification
## really, should be unsigned int
@R sortint :: sort_specification >> numeric_literal opt_ord
@R sortcol :: sort_specification >> column_name opt_ord
@R optord0 :: opt_ord >>
@R optordasc :: opt_ord >> ASC
@R optorddesc :: opt_ord >> DESC
@R limit0 :: optlimit >>
@R limit1 :: optlimit >> LIMIT numeric_literal

## table reference list (nasty hack alert)
##@R trl1 :: table_reference_list >> user_defined_name
##@R trln :: table_reference_list >> user_defined_name , table_reference_list

##@R trl1a :: table_reference_list >> user_defined_name user_defined_name
##@R trlna :: table_reference_list >> user_defined_name user_defined_name , table_reference_list

@R tr1 :: table_reference >> user_defined_name
@R tr2 :: table_reference >> user_defined_name user_defined_name
@R tr3 :: table_reference >> user_defined_name AS user_defined_name
@R trl1 :: table_reference_list >> table_reference
@R trln :: table_reference_list >> table_reference , table_reference_list

## select list
@R selectstar :: select_list >> *
@R selectsome :: select_list >> selectsubs
@R select1 :: selectsubs >> select_sublist
@R selectn :: selectsubs >> selectsubs , select_sublist
@R selectit :: select_sublist >> expression
@R selectname :: select_sublist >> expression AS column_alias
@R colalias :: column_alias >> user_defined_name

## search condition
@R search1 :: search_condition >> boolean_term
@R searchn :: search_condition >> boolean_term OR search_condition
@R bool1 :: boolean_term >> boolean_factor
@R booln :: boolean_term >> boolean_factor AND boolean_term
@R bf1 :: boolean_factor >> boolean_primary
@R notbf :: boolean_factor >> NOT boolean_primary
@R bp1 :: boolean_primary >> predicate
@R bps :: boolean_primary >> ( search_condition )

## predicate (simple for now!!!)
@R predicate1 :: predicate >> comparison_predicate

## comparison predicate (simple for now!!!)
##@R predicatene :: comparison_predicate >> expression < > expression
@R predicatene2 :: comparison_predicate >> expression ! = expression
@R predicateeq :: comparison_predicate >> expression = expression
@R predicatelt :: comparison_predicate >> expression < expression
@R predicategt :: comparison_predicate >> expression > expression
@R predicatele :: comparison_predicate >> expression < = expression
@R predicatege :: comparison_predicate >> expression > = expression
@R predbetween :: comparison_predicate >> expression BETWEEN expression AND expression
@R prednotbetween :: comparison_predicate >>
     expression NOT BETWEEN expression AND expression
@R predlike :: comparison_predicate >> expression LIKE character_string_literal
@R predilike :: comparison_predicate >> expression ILIKE character_string_literal

## exists predicate
@R predexists :: predicate >> exists_predicate
@R exists :: exists_predicate >> EXISTS ( sub_query )

## quantified predicate
@R predqeq :: predicate >> expression = allany ( sub_query )
##@R predqne :: predicate >> expression < > allany ( sub_query )
@R predqne2 :: predicate >> expression ! = allany ( sub_query )
@R predqlt :: predicate >> expression < allany ( sub_query )
@R predqgt :: predicate >> expression > allany ( sub_query )
@R predqle :: predicate >> expression < = allany ( sub_query )
@R predqge :: predicate >> expression > = allany ( sub_query )
@R nnall :: allany >> ALL
@R nnany :: allany >> ANY

## in predicate
@R predin :: predicate >> expression IN ( sub_query )
@R prednotin :: predicate >> expression NOT IN ( sub_query )
@R predinlits :: predicate >> expression IN ( litlist )
@R prednotinlits :: predicate >> expression NOT IN ( litlist )

@R pred_itageq :: predicate >> user_defined_name ITAGEQ expression

## subquery expression
@R subqexpr :: expression >> ( sub_query )

## expression (simple for now!!!)
@R exp1 :: expression >> term
@R expplus :: expression >> expression + term
@R expminus :: expression >> expression - term
@R expand :: expression >> expression & term
@R expor :: expression >> expression | term
@R expshiftl :: expression >> expression < < term
@R expshirtr :: expression >> expression > > term
@R expextract :: expression >> EXTRACT ( character_string_literal FROM expression )
@R term1 :: term >> factor
@R termtimes :: term >> term * factor
@R termdiv :: term >> term / factor
@R termshiftl :: term >> term < < factor
@R termshiftr :: term >> term > > factor
@R factor1 :: factor >> primary
@R plusfactor :: factor >> + factor
@R minusfactor :: factor >> - factor
@R primary1 :: primary >> column_name
@R primarylit :: primary >> literal
@R primaryexp :: primary >> ( expression )
@R primaryset :: primary >> set_function_reference
@R stringlit :: literal >> character_string_literal

## @R stringstring :: literal >> literal character_string_literal
@R numlit :: literal >> numeric_literal
@R numlitnull :: literal >> NULL
@R boollittrue :: literal >> TRUE
@R boollitfalse :: literal >> FALSE

## set functions (nasty hack!)
@R countstar :: set_function_reference >> COUNT ( * )
@R distinctcount :: set_function_reference >> COUNT ( DISTINCT expression )
@R allcount :: set_function_reference >> COUNT ( expression )
@R distinctset :: set_function_reference >> aggregate ( DISTINCT expression )
@R allset :: set_function_reference >> aggregate ( expression )
@R average :: aggregate >> AVG
@R count :: aggregate >> COUNT
@R maximum :: aggregate >> MAX
@R minimum :: aggregate >> MIN
@R summation :: aggregate >> SUM
@R median :: aggregate >> MEDIAN

## dynamic parameter (varies quite a bit from ODBC spec)
@R dynamic :: literal >> ?

## column name
@R columnname1 :: column_name >> column_identifier
@R columnname2 :: column_name >> table_name . column_identifier
@R tablename1 :: table_name >> user_defined_name
@R columnid1 :: column_identifier >> user_defined_name

## Set
@R set1 :: set_statement >> SET user_defined_name TO character_string_literal
@R set2 :: set_statement >> SET user_defined_name = character_string_literal
@R set3 :: set_statement >> SET TIME ZONE character_string_literal
@R set4 :: set_statement >> SET TRANSACTION ISOLATION LEVEL READ COMMITTED
@R set5 :: set_statement >> SET TRANSACTION ISOLATION LEVEL SERIALIZABLE

## Show
@R show :: show_statement >> SHOW user_defined_name

## Transactions
@R begin :: begin_statement >> BEGIN
@R commit :: commit_statement >> COMMIT
@R end :: commit_statement >> END
@R abort :: abort_statement >> ABORT
@R rollback :: abort_statement >> ROLLBACK

@R specialcase :: specialcase_statement >> SPECIALCASE user_defined_name
@R filter :: filter_statement >> FILTER character_string_literal

"""

nonterms = """
sliteral
exists_predicate set_function_reference aggregate
sortspeclist sort_specification opt_ord
drop_table_statement delete_statement_searched update_statement_searched
assns assn
insert_statement litlist colelt optcolconstraints optcolconstraint optdefault
optcolids insert_spec create_table_statement
colids colelts column_constraint_definition
column_definition data_type character_string_type
exact_numeric_type approximate_numeric_type exact_time_type
expression term factor primary literal
comparison_predicate column_alias column_identifier table_name
boolean_term boolean_factor boolean_primary predicate
selectsubs expression alias sub_query
statement_list statement select_statement alldistinct subselect
select_list table_reference_list optwhere optgroup opthaving
order_by_clause select_sublist
optunion optorder_by search_condition colnamelist column_name
optlimit
table_reference table_name create_index_statement simplenamelist
simplecolname
drop_index_statement allany create_view_statement drop_view_statement
optnamelist optsemicolon
set_statement show_statement begin_statement commit_statement
abort_statement from_clause specialcase_statement filter_statement
"""

keywords = """
INDEX ON ANY IN VIEW AS
EXCEPT INTERSECT
EXISTS AVG COUNT MAX MIN SUM MEDIAN
UPDATE DROP DELETE FROM SET
INSERT INTO VALUES CREATE TABLE
INTEGER SMALLINT BIGINT FLOAT VARCHAR BOOLEAN TIMESTAMPTZ DATE
AND OR NOT
SELECT FROM WHERE HAVING GROUP BY UNION ALL DISTINCT AS ORDER
ASC DESC BETWEEN UNIQUE LIMIT LIKE ILIKE
TO SHOW BEGIN COMMIT END ABORT ROLLBACK TIME ZONE LEFT OUTER JOIN INNER
NULL PRIMARY KEY FOREIGN REFERENCES
TRANSACTION ISOLATION LEVEL READ COMMITTED SERIALIZABLE
TRUE FALSE
SPECIALCASE MYOLABEL DESLS FILTER
EXTRACT ITAGEQ
"""

puncts = """.,*;=<>{}()?+-/&|!"""

# terminals user_defined_name, character_string_literal, numeric_literal

#
# $Log: grammar.py,v $
# Revision 1.4  2002/05/11 02:59:04  richard
# Added info into module docstrings.
# Fixed docco of kwParsing to reflect new grammar "marshalling".
# Fixed bug in gadfly.open - most likely introduced during sql loading
# re-work (though looking back at the diff from back then, I can't see how it
# wasn't different before, but it musta been ;)
# A buncha new unit test stuff.
#
# Revision 1.3  2002/05/08 00:49:00  anthonybaxter
# El Grande Grande reindente! Ran reindent.py over the whole thing.
# Gosh, what a lot of checkins. Tests still pass with 2.1 and 2.2.
#
# Revision 1.2  2002/05/07 07:06:11  richard
# Cleaned up sql grammar compilation some more.
# Split up the BigList into its components too.
#
# Revision 1.1.1.1  2002/05/06 07:31:09  richard
#
#
#
