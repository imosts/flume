
# Changes postgres "serial" to "integer"

DATA_TYPES = {
    'AutoField':         'integer',
    'BooleanField':      'boolean',
    'CharField':         'varchar(%(maxlength)s)',
    'CommaSeparatedIntegerField': 'varchar(%(maxlength)s)',
    'DateField':         'date',
    'DateTimeField':     'timestamptz',
    'FileField':         'varchar(100)',
    'FilePathField':     'varchar(100)',
    'FloatField':        'numeric(%(max_digits)s, %(decimal_places)s)',
    'ImageField':        'varchar(100)',
    'IntegerField':      'integer',
    'IPAddressField':    'inet',
    'ManyToManyField':   None,
    'NullBooleanField':  'boolean',
    'OneToOneField':     'integer',
    'PhoneNumberField':  'varchar(20)',
    'PositiveIntegerField': 'integer',
    'PositiveSmallIntegerField': 'smallint',
    'SlugField':         'varchar(%(maxlength)s)',
    'SmallIntegerField': 'smallint',
    'BigIntegerField':   'bigint',
    'TextField':         'varchar',
    'TimeField':         'time',
    'USStateField':      'varchar(2)',
}
