
import wikicode
import flume.flmos as flmo

class django_tools_main (wikicode.extension):
    def run (self):
        self.append_to_page ("<h1>Django Tools</h1>")
        self.send_page ()

if __name__ == '__main__':
    wikicode.run_extension (django_tools_main)
