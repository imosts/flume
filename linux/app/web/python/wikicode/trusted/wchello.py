import wikicode
import flume.flmos as flmo

class helloworld (wikicode.extension):
    def run (self):
        self.append_to_page ("Hello World<BR>")
        self.send_page ()

if __name__ == '__main__':
    wikicode.run_extension (helloworld)
