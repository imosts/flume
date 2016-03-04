import flmkvs, flmxmlrpc.client, flume
import flume.flmos as flmo

default_query_size = 10

class KVSException (Exception):
    pass

class kvsconnection:
    """
    This class wraps up the client RPC functionality into convenience
    functions that decode responses and throws exceptions etc.
    """

    def __init__ (self, sockfile=None):
        if sockfile is None:
            sockfile = flmkvs.default_sockfile
            
        self.conn = flmxmlrpc.client.ServerProxy (sockfile)

    def put (self, key, value, desired_ls=None):
        if desired_ls is None:
            s = flmo.get_fd_label (flume.LABEL_S, self.conn.socket)
            i = flmo.get_fd_label (flume.LABEL_I, self.conn.socket)
            desired_ls = flmo.LabelSet (S=s, I=i)

        res = self.conn.put (key, value, desired_ls.to_filename ())
        #print 'response is %s' % (res,)
        if res[0] == flmkvs.KVS_OK:
            return None
        elif res[0] == flmkvs.KVS_ERR:
            raise KVSException, "KVS error"
        else:
            raise KVSException, "KVS error"

    def get (self, key):
        pass

    def get_range (self, startkey, endkey=None, num=default_query_size):
        pass
    
    def remove (self, key):
        res = self.conn.remove (key)
        #print 'response is %s' % (res,)
        if res[0] == flmkvs.KVS_OK:
            return None
        elif res[0] == flmkvs.KVS_ERR:
            raise KVSException, "KVS error"
        else:
            raise KVSException, "KVS error"


    
