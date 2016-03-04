from django.db.backends.flumedb.base import quote_name

def get_table_list(cursor):
    "Returns a list of table names in the current database."
    cursor.execute("SPECIALCASE gettablelist")
    return [row[0] for row in cursor.fetchall()]

def get_table_description(cursor, table_name):
    "Returns a description of the table, with the DB-API cursor.description interface."
    cursor.execute("SELECT * FROM %s LIMIT 1" % quote_name(table_name))
    return cursor.description

def get_relations(cursor, table_name):
    """
    Returns a dictionary of {field_index: (field_index_other_table, other_table)}
    representing all relationships to the given table. Indexes are 0-based.
    """
    raise NotImplementedError, "Django does not use foreign key relations when using FlumeDB"

def get_indexes(cursor, table_name):
    """
    Returns a dictionary of fieldname -> infodict for the given table,
    where each infodict is in the format:
        {'primary_key': boolean representing whether it's the primary key,
         'unique': boolean representing whether it's a unique index}
    """
    raise NotImplementedError, "Django does not support this with FlumeDB yet."

    # This query retrieves each index on the given table, including the
    # first associated field name
    cursor.execute("""
        SELECT attr.attname, idx.indkey, idx.indisunique, idx.indisprimary
        FROM pg_catalog.pg_class c, pg_catalog.pg_class c2,
            pg_catalog.pg_index idx, pg_catalog.pg_attribute attr
        WHERE c.oid = idx.indrelid
            AND idx.indexrelid = c2.oid
            AND attr.attrelid = c.oid
            AND attr.attnum = idx.indkey[0]
            AND c.relname = %s""", [table_name])
    indexes = {}
    for row in cursor.fetchall():
        # row[1] (idx.indkey) is stored in the DB as an array. It comes out as
        # a string of space-separated integers. This designates the field
        # indexes (1-based) of the fields that have indexes on the table.
        # Here, we skip any indexes across multiple fields.
        if ' ' in row[1]:
            continue
        indexes[row[0]] = {'primary_key': row[3], 'unique': row[2]}
    return indexes

# Maps type codes to Django Field types.
DATA_TYPES_REVERSE = {
    16: 'BooleanField',
    21: 'SmallIntegerField',
    23: 'IntegerField',
    25: 'TextField',
    869: 'IPAddressField',
    1043: 'CharField',
    1082: 'DateField',
    1083: 'TimeField',
    1114: 'DateTimeField',
    1184: 'DateTimeField',
    1266: 'TimeField',
    1700: 'FloatField',
}
