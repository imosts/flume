
class WCError (Exception): pass
class WCInternalError (WCError): pass
class WCExtensionError (WCError): pass
class WCUnsupported (WCError): pass

class InvalidObject (Exception): pass
class InvalidLogin (Exception): pass
class IllegalUsername (Exception): pass
class DuplicateError (Exception): pass


