import sys, socket, os, wikicode
import flume.flmos as flmo
from wikicode import to_rpc_proxy

class Declassifier (object):
    def config (self):
        """
        This is a CGI program used to configure the declassifier
        """
        import wikicode
        class Config (wikicode.extension):
            def run (self):
                self.send_page ("Generic DC Setup")
        wikicode.run_extension (Config)

    def declassify_ok (self, *args):
        """
        This is a method that returns True or False depending on whether
        the user with uid <owner_uid> is willing to declassify to user <recipient_uid>
        """
        raise NotImplementedError, 'subclass must implement this method'

    def run (self):

        if len (sys.argv) > 1:
            tagval = int (sys.argv[1])
            instance_tagval = int (sys.argv[2])
            owner_name = sys.argv[3]
            owner_uid = int (sys.argv[4])
            devel_homedir = sys.argv[5]
            recipient_uid = int (sys.argv[6])
            rpc_fd, rpc_proxy = to_rpc_proxy (os.environ[wikicode.RPC_TAG_ENV])

            if self.declassify_ok (tagval, instance_tagval,
                                   owner_name, owner_uid,
                                   devel_homedir,
                                   recipient_uid, rpc_fd, rpc_proxy):
                rpc_proxy.set_dc_ok (True)
                sys.exit (0)
            else:
                sys.exit (-1)
        else:
            self.config ()

if __name__ == '__main__':
    obj = Declassifier ()
    obj.run ()
