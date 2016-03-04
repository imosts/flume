from wikicode.dc import Declassifier

class AlwaysNo (Declassifier):
    def declassify_ok (self, *args):
        return True

if __name__ == "__main__":
    obj = AlwaysNo ()
    obj.run ()
