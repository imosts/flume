import os, sys
import kjParseBuild
import kjParser
import grammar
import dbvbindings
from grammar import *
from semantics import Parse_Context

class SQLParser:
    def __init__ (self):
        self._sql = None

    def basedir (self):
        return os.path.dirname (__file__)

    def compileSQL (self):
        marfile = os.path.join (self.basedir (), 'sql_mar.py')
        build = 1
        if os.path.exists(marfile):
            mtime = os.stat(marfile)[-2]
            if mtime > os.stat(os.path.join(self.basedir (), 'grammar.py'))[-2]:
                build = 0
        if build:
            # nuke any existing pyc/o
            for filename in ('sql_mar.pyc', 'sql_mar.pyo'):
                filename = os.path.join(self.basedir (), filename)
                if os.path.exists(filename):
                    os.remove(filename)
            SQLG = kjParseBuild.NullCGrammar()
            SQLG.SetCaseSensitivity(0)
            DeclareTerminals(SQLG)
            SQLG.Keywords(keywords)
            SQLG.punct(puncts)
            SQLG.Nonterms(nonterms)
            SQLG.comments(["--.*"])
            # TODO: should add comments
            SQLG.Declarerules(sqlrules)
            SQLG.Compile()
            SQLG.MarshalDump(open(marfile, "w"))

    def loadSQL(self):
        infile = 'DBV.sql_mar'
        try:
            SQLG = kjParser.UnMarshalGram(infile)
        except ImportError:
            raise ImportError, "Couldn't find sql_mar.py - has setup.py been run?"
        DeclareTerminals(SQLG)
        return SQLG

    def printrules (self, sql):
        for name in sql.RuleNameToIndex.keys():
            print "binding", name
        
    def parse (self, query):
        if self._sql is None:
            self.compileSQL ()
            self._sql = self.loadSQL ()
            #self.printrules (self._sql)
            self._sql = dbvbindings.BindRules (self._sql)
        context = Parse_Context ()
        commands = self._sql.DoParse1 (query, context)
        return commands

if __name__ == '__main__':
    try:
        parser = SQLParser ()
        commands = parser.parse ("SELECT x FROM bla")
    except:
        import traceback
        traceback.print_exc ()
        sys.exit (1)
    sys.exit (0)
