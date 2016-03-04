
var CI = Components.interfaces, CC = Components.classes, CR = Components.results, gFP;
var PH = Components.classes["@mozilla.org/network/protocol;1?name=http"].getService(Components.interfaces.nsIProtocolHandler);

function asciiURI (uri) {
    return uri.spec;
}

/*********** Experimental load event handlers *********/
function print_event (typ, e) {
    dump ("Got event for " + typ + " " + e.target + "\n");
    dump ("  type: " + e.type + "\n");

    if (e.target.URL != undefined) {
        dump ("  URL: " + e.target.URL + "\n");
    }
    if (e.target.innerHTML != undefined) {
        dump ("  innerHTML: " + e.target.innerHTML + "\n");
    }
    if (e.target.contentDocument != undefined) {
        dump ("  contentDocument.URL: " + e.target.contentDocument.URL + "\n");
    }
}

function handle_load (event) {
    dump ("HANDLE LOAD\n");
}
function handle_domcontentloaded (event) {
    dump ("HANDLE DOMCONTENTLOADED\n");
}



function testOnStartURIOpen (uri)
{
 if (redirectRequired(uri)) // redirectRequired is implemented by me
 {
   getBrowser().mCurrentTab.linkedBrowser.loadURI(newUrl);
   return true;
 }
 return false;

}

var s = "http://pdos.csail.mit.edu/~yipal/test/basic.html";

var urlObserver = {
  observe: function(subject, topic, data){
    if (topic == "http-on-modify-request") {
        dump ("http-on-modify-request\n");
        var chan = subject.QueryInterface(Components.interfaces.nsIHttpChannel);

        z = PH.newURI (s, null, null);
        if (chan.URI.equals(z))
            return

        if (true) {
            dump ("  cancelling...\n");
            chan.cancel (Components.results.NS_BINDING_ABORTED);
        }

        if (chan.URI)
            dump ("  URI   " + asciiURI (chan.URI) + "\n");
        if (chan.originalURI)
            dump ("  orig  " + asciiURI (chan.originalURI) + "\n");

        try {
            if (chan.referrer)
                dump ("  refer " + asciiURI (chan.referrer) + "\n");
            if (chan.owner) 
                dump ("  owner " + chan.owner + "\n");
            if (chan.contentType)
                dump ("  ctype " + chan.contentType + "\n");
        } catch (err) {}


        w = getBrowser ().contentWindow
        
        
        newuri = PH.newURI (s, null, null);
        newchan = PH.newChannel (newuri);

        dump ("  newchan " + newchan + "\n");

        if (subject.notificationCallbacks) {
            dump ("callbacks: " + subject.notificationCallbacks + "\n");
            loader = Components.classes["@mozilla.org/uriloader;1"].getService(Components.interfaces.nsIURILoader);
            try {
                loader.openURI (newchan, true, subject.notificationCallbacks);
            } catch (err) {
                dump ("ERR " + err + "\n");
            }
        }

        if (false) {
            if (subject.notificationCallbacks) {
                dump ("HERE1 " + subject.notificationCallbacks + "\n");
                
                // If the request was initiated by an XMLHTTPRequest, the
                // following check would be true.  The XMLHTTPRequest
                // object would be listening for notificationCallbacks.
                if (subject.notificationCallbacks instanceof Components.interfaces.nsIXMLHttpRequest) {
                    dump ("HERE2\n");
                }
            }
        }
        
        
    } else if (topic == "http-on-examine-response") {
        var chan = subject.QueryInterface(Components.interfaces.nsIHttpChannel);
        dump ("http-on-examine-response: " + asciiURI (chan.URI) + "\n");
    }

  }
};


function W5Meta (http_req_obj) {
    this.req = http_req_obj;
    this.slab = [];
    this.ilab = [];
    this.read_data (this);
}
W5Meta.prototype = {
    visitHeader : function (name, value) {
        this.theaders[name] = value;
        dump ("SAW HEADER " + name + ": " + value + "\n");
    },

    read_data : function () {
        this.theaders = [];
        this.req.visitResponseHeaders (this);
    },

    print : function () {
        dump ("In W5META\n");
    }
}

var headerListener = {
    onStateChange: function (webProgObj, req, flags, status) {
        if (flags & Components.interfaces.nsIWebProgressListener.STATE_STOP &&
            flags & Components.interfaces.nsIWebProgressListener.STATE_IS_DOCUMENT) {  // XXX: not sure if this is the event we want...

            // We must find the 'DOMWindow' to be able to put our 'HeaderInfo' object in it
            try {
                req.QueryInterface(Components.interfaces.nsIHttpChannel);
            } catch (ex) {
                req.QueryInterface(Components.interfaces.nsIMultiPartChannel);
                req = req.baseChannel.QueryInterface(Components.interfaces.nsIHttpChannel);
            }

            // Squirrel away some metadata.  
            webProgObj.DOMWindow.document.w5meta = new W5Meta (req);

            // Unregister listener
            webProgObj.removeProgressListener (this);
        }
    },
    onProgressChange: function(aProg, b,c,d,e,f) {},
    onLocationChange: function(aProg, aRequest, aURI) {},
    onStatusChange: function(aProg, aRequest, aStatus, aMessage) {},
    onSecurityChange: function(aWebProgress, aRequest, aState) {},

    observe: function (subject, topic, data) {
        if (topic == "http-on-modify-request") {
            try {
                subject.QueryInterface(Components.interfaces.nsIRequest);
                
                // YIPAL: Not sure about the loadgroup, since W5 tracks labels per document, not per page.

                // We only need to register a listener if this is a document uri as all embeded object
                // are checked by the same listener (not true for frames but frames are document uri...)
                if ((subject.loadFlags & Components.interfaces.nsIChannel.LOAD_DOCUMENT_URI) && 
                    subject.loadGroup && subject.loadGroup.groupObserver) {
                    var go = subject.loadGroup.groupObserver;
                    go.QueryInterface(Components.interfaces.nsIWebProgress);
                    
                    // YIPAL: This is where it subscribes to the WebProgressListener
                    //  This occurs once per page load.
                    go.addProgressListener(this, Components.interfaces.nsIWebProgress.NOTIFY_STATE_DOCUMENT); // 0x2 or 0xff
                }
            } catch (ex) {
                dump("headerListener: " + ex + "\n");
            }
        }
    },

    GetWeakReference : function () {
        // YIPAL: We probably don't need this.
        dump("nsHeaderInfo: GetWeakReference called!!!\n");
    },

    QueryInterface: function(iid) {
        if (!iid.equals(Components.interfaces.nsISupports) &&
            !iid.equals(Components.interfaces.nsISupportsWeakReference) &&
            //!iid.equals(Components.interfaces.nsIWeakReference) &&
            //!iid.equals("db242e01-e4d9-11d2-9dde-000064657374") &&
            !iid.equals(Components.interfaces.nsIObserver) &&
            !iid.equals(Components.interfaces.nsIWebProgressListener)) {
            //!iid.equals(Components.interfaces.nsIHttpNotify)) {
            dump("nsHeaderInfo: QI unknown interface: " + iid + "\n");
            throw Components.results.NS_ERROR_NO_INTERFACE;
        }
        return this;
    }

};

var observerService = Components.classes["@mozilla.org/observer-service;1"].getService(Components.interfaces.nsIObserverService);
//observerService.addObserver(urlObserver, "http-on-modify-request", false); 
observerService.addObserver(headerListener, "http-on-modify-request", false); 
//observerService.addObserver(urlObserver, "http-on-examine-response", false); 

var newWindowObserver = {
    observe: function (subject, topic, data) {
        if (topic == "toplevel-window-ready") {
            dump ("NEW TOPLEVEL WINDOW\n");
        }
    }
};
observerService.addObserver(newWindowObserver, "toplevel-window-ready", false); 


/* See if we can read the w5meta field in the DOM document */
function handle_new_window (e) {
    dump ("handle_new_window: " + e.target.defaultView.location + "\n");
    dump ("  bla: " + e.target.defaultView.content.document + "\n");
}
getBrowser().addEventListener("DOMContentLoaded", function(e) { handle_new_window (e) }, false);


function w5toolbar_init (event) { }
