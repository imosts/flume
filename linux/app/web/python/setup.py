
from distutils.core import setup

pkgs = ['flmw',
        'wikicode',
        'wikicode.db',
        'wikicode.dc',
        'wikicode.flup',
        'flmxmlrpc',
        'flmkvs',
        'fastimporter',
        ]


setup(name='flume',
      version='0.0',
      packages=pkgs,
      )

setup(name='flume',
      version='0.0',
      packages=['wikicode.db']
      )

setup(name='flume', version='0.0', packages=['wikicode.dc'])

setup(name='flume',
      version='0.0',
      packages=['flmxmlrpc']
      )

setup(name='flume',
      version='0.0',
      packages=['flmkvs']
      )
