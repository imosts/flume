import util
from dbvbindings import *

def gen_insert_table_ls (tablename, ls):
    # Return a query that inserts <tablename> into table2labelids
    # where S,I,O are equal to the packed labelset <ls>

    q  = ('INSERT INTO table2labelids (tablename, s, i, o)\n')
    q += ('  SELECT \'%s\', s.labelid, i.labelid, o.labelid\n' % tablename)
    q += ('    FROM labelid2label s, labelid2label i, labelid2label o\n')
    q += ('    WHERE s.label=E\'%s\' and i.label=E\'%s\' and o.label=E\'%s\';'
          % (util.escape_lab (ls.get_S ()),
             util.escape_lab (ls.get_I ()),
             util.escape_lab (ls.get_O ())))
    return q

def insert_labelset (db_conn, ls):
    # Make sure the labels already exist in the database returns
    # labelids for (s, i, o) in <ls>.  (Later, we should be smarter
    # about trying to inserting each label every time.  Cache them or
    # something)

    # XXX labelids should be random.
    labelids = []
    for l in (ls.get_S (), ls.get_I (), ls.get_O ()) :
        res = db_conn.query ('SELECT labelid FROM labelid2label WHERE label=E\'%s\'' %
                             util.escape_lab (l))
        if res.ntuples () == 0:
            try:
                db_conn.query ('BEGIN;')
                db_conn.query ('INSERT INTO labelid2label (label) VALUES (E\'%s\');' %
                               util.escape_lab (l))
                for h in l.toList ():
                    db_conn.query ('INSERT INTO labelid2tag (labelid, tag)'
                                   '  SELECT labelid, \'%d\' FROM labelid2label WHERE label=E\'%s\';' %
                                   (h.val (), util.escape_lab (l)))
                db_conn.query ('COMMIT;')
                res = db_conn.query ('SELECT lastval ();')
                labelids.append (res.getresult ()[0][0])

            except:
                db_conn.query ('ABORT;')
                raise
        else:
            labelids.append (res.getresult ()[0][0])
    return labelids

def client_label_contains_row_label (client_lab, tables, row_lab):
    r = 'NOT EXISTS (SELECT tag FROM labelid2tag WHERE (('
    r += ' OR '.join (['labelid2tag.labelid=%s.%s' % (t, row_lab)
                       for t in tables])
    r += ')'
    if len (client_lab.toListV ()) > 0:
        r += ' AND '
        r += ' AND '.join ( ['tag<>%d' % tag
                             for tag in client_lab.toListV ()] )
    r += '))'
    return r

def row_label_contains_client_label (table, row_lab, client_lab, filters=[]):
    all_restrictions = []
    for tag in client_lab:
        tag_res = []
        
        # Either the tag is in the row's label <row_lab>
        tag_res.append ('%d IN (SELECT tag FROM labelid2tag '
                        '  WHERE labelid2tag.labelid=%s.%s)'
                        % (tag.val (), table, row_lab))
        
        # Or the tag is added by filter <f> and the filter's find clause is in the row's label <row_lab>.
        for f in filters:
            if tag in f.adding ():
                # Scary recursive query generation.
                sublist = list (filters)
                sublist.remove (f)
                tag_res.append (row_label_contains_client_label (table, row_lab, f.find (), sublist))
                                
        all_restrictions.append (' OR '.join (tag_res))
        
    return ' AND '.join ('(%s)' % (r,) for r in all_restrictions)

def client_label_contains_one_tag (client_lab, table, row_lab):
    """
    Either the row's O set is empty, or there exists one tag in the
     row's O set that is in client_lab.  exists:
    
     (NOT EXISTS (SELECT TRUE FROM labelid2tag, tab WHERE labelid2tag.labelid=table.olabelid)
      OR EXISTS (SELECT TRUE FROM labelid2tag, tag WHERE labelid2tag.labelid=table.olabelid
                                                         AND (labelid2tag.tag=123
                                                              OR labelid2tag.tag=456
                                                              OR labelid2tag.tag=678)))
    """
    r =  '(NOT EXISTS (SELECT TRUE FROM labelid2tag, %s WHERE labelid2tag.labelid=%s.%s)' % (table, table, row_lab)

    if len(client_lab) > 0:
        r += ' OR EXISTS (SELECT TRUE FROM labelid2tag, %s WHERE labelid2tag.labelid=%s.%s AND (' % (table, table, row_lab)
        r += ' OR '.join ([ 'labelid2tag.tag=%d' % cap for cap in client_lab.toListV() ])
        r += ' )))'
    else:
        r += ')'
        
    return r

def handle_create (createnode, parsedata, db_conn, forw, resp,
                   client_ls, desired_ls, filters):
    extra_columns = ", slabelid INTEGER, ilabelid INTEGER, olabelid INTEGER"

    # Deal with the optional UNIQUE column constraint
    union_constraints = ''
    unique_coldefs = DBV.util.get_unique_coldefs (createnode)
    for coldef in unique_coldefs:
        # Clear the UNIQUE bit from the column definition since
        # we add separate constraint as unions with Slabel and Ilabel
        for c in coldef.constraints ():
            if isinstance (c, OptColumnConstraintNode):
                c.set_type (c.get_ctype() & ~CONSTRAINT_UNIQUE)
        union_constraints += (', UNIQUE (%s, slabelid, ilabelid)' %
                              coldef.colname ())

    # Deal with column constraints
    for x in DBV.util.get_unique_colconstraints (createnode):
        x.add_column ('slabelid')
        x.add_column ('ilabelid')

    # Deal with Foreign Key constraints
    for x in parsedata.get_nodes (ColumnFKeyNode):
        x.add_local_col ("slabelid")
        x.add_local_col ("ilabelid")
        x.add_remote_col ("slabelid")
        x.add_remote_col ("ilabelid")
        
    insert_labelset (db_conn, desired_ls)
    try:
        db_conn.query ('BEGIN;')
        q = gen_insert_table_ls (createnode._tablename, desired_ls)
        db_conn.query (q)

        # (Gadfly grammer does not allow a table with no columns, so
        # the comma can always be there)
        q = ('CREATE TABLE %s (%s %s %s) WITHOUT OIDS;\n' %
             (createnode.table_name(),
              str (createnode._children[0]),
              extra_columns,
              union_constraints))

        util.flume_debug (20, 'Translated query is: %s' % (q,))
        db_conn.query (q)
        db_conn.query ('COMMIT;')
        resp (util.gen_psql_msg ('C', 'CREATE TABLE' + '\0'))
        resp (util.gen_psql_readymsg ())
    except:
        db_conn.query ('ABORT;')
        raise
    return None

def handle_insert (insertnode, parsedata, db_conn, forw, resp,
                   client_ls, desired_ls, filters):
    if not isinstance (insertnode, InsertNode):
        raise AssertionError, ('expected an InsertNode, got %s' %
                               type(insertnode))

    # Insert the labels into the label tables
    (s, i, o) = insert_labelset (db_conn, desired_ls)
    insertnode.set_labelids (s, i, o)

    # Forward the insert query
    return str(insertnode)

def translate_subselects (client_ls, desired_ls, parsedata, filters):
    res = []
    for node in parsedata.get_nodes (SubSelectNode):
        if len (node.table_aliases ()) <= 0:
            raise AssertionError, 'a SELECT should have at least one table involved!'

        # Special case queries on pg_type.
        # Allow a restricted select from the pg_type type
        # XXX This is hack because each time you create a table, Postgres
        # adds a new row to pg_type.  Untrusted clients should not be able
        # to see the new entries, so we limit their visibility to newer
        # OIDs, but since we dont know how OIDs get allocated, we should
        # have a better restriction for pg_type.
        if [x.upper() for x in ['pg_type']] == [x.upper()
                                                for x in node.table_names ()]:
            alias = node.get_alias ('pg_type')
            res.append ('%s.OID <= 10803' % (alias,))

        else:
            # If the client specified a desired_ls, restrict output
            # according according to the client's desires.  The client
            # should use the desired label to restrict DB output to high
            # integrity data, even if the client does not have the
            # capability to set its endpoint's I label.

            # Only select if (client's S label + desired S) label contains
            # all tags in row's S label
            res.append (client_label_contains_row_label (client_ls.get_S () + desired_ls.get_S (),
                                                         node.table_aliases (),
                                                         'slabelid'))

            # Only select if all rows' I labels contains all tags in
            # (client's I label + desired I label)
            combined = client_ls.get_I () + desired_ls.get_I ()
            for table in node.table_aliases ():
                if len (combined) > 0:
                    res.append (row_label_contains_client_label (table, 'ilabelid',
                                                                 combined, filters))

        # Look for ITagEQ command in this particular subselect
        if len (util.get_nodes (node._optwhere, ITagEqNode, SubSelectNode)) > 0:
            node._fromclause.add_tables (['labelid2tag'])

        node.set_restrictions (' AND '.join (res))


def handle_select (selectnode, parsedata, db_conn, forw, resp, client_ls, desired_ls, filters):
    return str (selectnode)

def handle_update (updatenode, parsedata, db_conn, forw, resp, client_ls, desired_ls, filters):
    res = []

    # Only update if row S label contains all tags in client S label
    if len (client_ls.get_S ().toListV ()) > 0:
        res.append (row_label_contains_client_label (updatenode.table_name (),
                                                     'slabelid',
                                                     client_ls.get_S ()))

    # Only update if the client's S label contains all tags in the
    # row's S label
    res.append (client_label_contains_row_label (client_ls.get_S (),
                                                 [updatenode.table_name ()],
                                                 'slabelid'))

    # Only update if client's I label contains all tags in row's I
    # label
    res.append (client_label_contains_row_label (client_ls.get_I (),
                                                 [updatenode.table_name ()],
                                                 'ilabelid'))

    # Only update if the client's O label contains at least one of the
    # capabilities in the row's O label
    res.append (client_label_contains_one_tag (client_ls.get_O (),
                                               updatenode.table_name (),
                                               'olabelid'))

    updatenode.set_restrictions (' AND '.join (res))
    return str (updatenode)

def handle_delete (node, parsedata, db_conn, forw, resp, client_ls, desired_ls, filters):
    res = []

    # Only delete if row S label contains all tags in client S label
    if len (client_ls.get_S ().toListV ()) > 0:
        res.append (row_label_contains_client_label (node.table_name (), 'slabelid', client_ls.get_S ()))

    # Only delete if the client's S label contains all tags in the row's S label
    res.append (client_label_contains_row_label (client_ls.get_S (), [node.table_name ()], 'slabelid'))

    # Only delete if client's I label contains all tags in row's I label
    res.append (client_label_contains_row_label (client_ls.get_I (), [node.table_name ()], 'ilabelid'))

    # XXX Check that the client has enough capabilities to satisfy the
    # O labels on the table and the row.

    node.set_restrictions (' AND '.join (res))
    return str (node)

def handle_drop (node, parsedata, db_conn, forw, resp, client_ls, desired_ls, filters):
    # XXX There is a bug here: if the table drop ultimately fails, the
    # table2labelids will no longer have an entry for the table, but
    # the table will still exist.  This can be fixed if we switch to
    # proxy at the application level because we'll be able to see the
    # DB response to the DROP.  
    db_conn.query ("DELETE FROM table2labelids WHERE tablename='%s';" % node.table_name())
    return str (node)

def handle_copy (node, parsedata, db_conn, forw, resp, client_ls, desired_ls, filters):
    return str (node)

def handle_null (*args):
    return None

def handle_query (parsedata, db_conn, forw, resp, client_ls, desired_ls, filters=[]):
    # Depending on the query type, this will either forward a modified
    # query to the DB on the client's connection, or it will issues
    # its own query on DBV's connection.  Using the client's
    # connection gains concurrency, although, we could probably just
    # give every proxy connection its own pg.connection (Not now, since we'd have to
    # implement the login protocol.

    # Modify insert sub queries
    translate_subselects (client_ls, desired_ls, parsedata, filters)

    a = []
    for node in parsedata.get_statements ():
        args = (node, parsedata, db_conn, forw, resp, client_ls, desired_ls, filters)

        if isinstance (node, CreateTableNode):
            s = handle_create (*args)
        elif isinstance (node, InsertNode):
            s = handle_insert (*args)
        elif isinstance (node, SelectNode):
            s = handle_select (*args)
        elif isinstance (node, UpdateNode):
            s = handle_update (*args)
        elif isinstance (node, DeleteNode):
            s = handle_delete (*args)
        elif isinstance (node, DropNode):
            s = handle_drop (*args)

        elif isinstance (node, (SetNode, ShowNode, BeginNode, CommitNode, AbortNode,
                                     SpecialCaseNode, CreateIndexNode)):
            s = handle_copy (*args)
        elif isinstance (node, (MyOLabelNode, DesLSNode, FilterNode)):
            s = handle_null (*args)
        else:
            raise DBV.TranslationError, "Unsupported query type"

        a.append (s)

    a = [x for x in a if x is not None]
    if len (a) > 0:
        s = '; '.join (a)
        util.flume_debug (20, 'Translated query is: %s' % str (s))
        forw (s)

    return str(s)
