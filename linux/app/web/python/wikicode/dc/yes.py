from wikicode.dc import Declassifier

class AlwaysYes (Declassifier):
    def declassify_ok (self, *args):
        return True

if __name__ == "__main__":
    obj = AlwaysYes ()
    obj.run ()
