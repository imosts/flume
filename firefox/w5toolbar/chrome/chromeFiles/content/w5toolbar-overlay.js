/*
 * 1) Direct all requests through the w5 proxy
 * 2) Notify gateway when querying for a subframe
 * 3) Allow the user to add new etags easily
 * 4) Propagate labels from one request to the next
 * 5) Send login cookies from the w5.com to XXX.w5 domains
 * 6) Prohibit postMessage
 * 7) Implement labelled cross-context messages with w5sendmessage
 * 8) Close cross-context channel in window.name *** Not anymore 11/1/08 ***
 * 9) When loading a subframe, notify the server of the subframe's parent CID 
 */

var CI = Components.interfaces, CC = Components.classes, CR = Components.results, gFP;
var w5toolbar_enabled = null;
var prefManager = Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefBranch);
var protManager = Components.classes["@mozilla.org/network/protocol;1?name=http"].getService(Components.interfaces.nsIProtocolHandler);

const STATE_START = CI.nsIWebProgressListener.STATE_START;
const STATE_STOP = CI.nsIWebProgressListener.STATE_STOP;
const STATE_IS_REQUEST = CI.nsIWebProgressListener.STATE_IS_REQUEST;

const STATE_DOC = CI.nsIWebProgressListener.STATE_IS_DOCUMENT;
const STATE_START_DOC = STATE_START | STATE_DOC;
const STATE_STOP_DOC = STATE_STOP | STATE_DOC;

const ABORT = Components.results.NS_BINDING_ABORTED;

var all_windows = [];
var bflow_domains = [];

var IS_SUBFRAME_TRUE = "TRUE";
var IS_SUBFRAME_FALSE = "FALSE";

function is_bflow_zone (domain) {
  var i;
  for (i=0; i<bflow_domains.length; i++) {
    var zone_suffix = to_zone_suffix (bflow_domains[i]);
    if (domain.substring (domain.length-zone_suffix.length) == zone_suffix)
      return bflow_domains[i];
  }
  return null;
}

function get_windows (name) {
  var j = 0;
  var ret = [];
  for (var i=0; i<all_windows.length; i++) {
    if (all_windows[i].name == name)
      ret[j++] = all_windows[i];
  }
  return ret;
}

/******************
 * Order of Request Events:
 *  1) Proxying: applyFilter()
 *  2) http-on-modify-request
 *  3) http-on-examine-response
 *  4) URL observer
 *  5) DOMContentLoaded
 */

/*********** Proxy handlers *********/
var proxy_handler = {
  proxyInstances : null,
  
  QueryInterface: function(aIID) {
    if(!aIID.equals(CI.nsISupports) && !aIID.equals(CI.nsIObserver) && !aIID.equals(CI.nsISupportsWeakReference)) {
      throw CR.NS_ERROR_NO_INTERFACE;
    }
    return this;
  },
  
  applyFilter: function (proxyService, uri, proxy) {
    var proxy_server;
    if (proxy_server = is_bflow_zone (uri.host)) {
      ddump (DB_PROXY, "Proxying " + uri.spec + "\n");
      var proxyport = prefManager.getCharPref("extensions.w5toolbar.proxyport");

      if (!this.proxyInstances) {
        this.proxyInstances = new Object ();
      }

      if (!this.proxyInstances[proxy_server]) {
        this.proxyInstances[proxy_server] = proxyService.newProxyInfo ("http", proxy_server, proxyport, 
                                                                       0, proxyService.PR_UINT32_MAX, null);
      }
      
      return this.proxyInstances[proxy_server];
    } else {
      ddump (DB_PROXY, "Not Proxying " + uri.spec + "\n");
      return null;
    }
  }
};


/*********** HTTP Request handlers *********/
var urlObserver = {
  observe: function(subject, topic, data){
    if (topic == "http-on-modify-request") {
        /* Send the referrer's S and I labels to the server if we have them */
        
        // We must get the nsIHttpChannel interface before we can read
        // the subject.notificationCallbacks property.
        var chan = subject.QueryInterface(Components.interfaces.nsIHttpChannel); 
        ddump (DB_MODIFY, "-------- http-on-modify-request --------\n");
        ddump (DB_MODIFY, "  URL: " + chan.URI.spec + "\n");

        //dump_object (DB_MODIFY, subject);
        
        // Figure out if this request is for a subframe or a _top
        // frame.  We need this because the fragment ID channel allows
        // the _top frame to talk to it's descendants.  We can model
        // this communication in the gateway, but we cannot allow a
        // descendant to make its S label smaller (downgrade).
        // Otherwise, a parent frame with S={x} could initially have a
        // subframe with S={x}.  Then the subframe could use a
        // downgrader to reach S={}, and the parent could still use
        // the Fragment ID channel to leak data from the parent to the
        // subframe.
        //
        // So... we tell the gateway which requests come from
        // subframes and the gateway refuses to launch a downgrader
        // for that request.
        var is_subframe = is_topframe (subject) ? IS_SUBFRAME_FALSE : IS_SUBFRAME_TRUE;

        // If the user requested new tags, send them to the server
        var ctx = chan.URI.host;
        if (newtags[ctx]) {
          chan.setRequestHeader ("X-add-stags", label2str (newtags[ctx]), false);
          ddump (DB_HEADER, "X-add-stags " + chan.getRequestHeader ("X-add-stags") + "\n");
          delete newtags[ctx];
        }

        if (chan.referrer) {
            var ref_ctx = chan.referrer.host;
            var ref_meta = get_w5meta (ref_ctx);
            if (ref_meta) {
                try {
                    if (ref_meta.trusted) {
                        chan.setRequestHeader ("X-referrer-w5mode", "trusted", false);
                        ddump (DB_MODIFY, "  referrer was trusted\n");
                    } else {
                        chan.setRequestHeader ("X-referrer-w5mode", "untrusted", false);
                        chan.setRequestHeader ("X-referrer-slabel", label2str (ref_meta.slab, true), false);
                        chan.setRequestHeader ("X-referrer-ilabel", label2str (ref_meta.ilab, true), false);
                        chan.setRequestHeader ("X-referrer-olabel", label2str (ref_meta.olab, true), false);
                        ddump (DB_MODIFY, "  referrer was untrusted\n");
                        ddump (DB_MODIFY, "    slab " + label2str (ref_meta.slab, true) + "\n");
                        ddump (DB_MODIFY, "    olab " + label2str (ref_meta.olab, true) + "\n");
                    }
                } catch (e) { 
                    ddump (DB_MODIFY, e);
                }

                // Send cookies belonging to the BFlow server to the
                // server for this zone sub-domains (even though they
                // are different origins)
                var server_domain;
                if (server_domain = is_bflow_zone (chan.URI.host)) {
                    var newcookies = getCookies ("." + server_domain);
                    
                    try {
                        var cookieheader = chan.getRequestHeader ("Cookie");
                    } catch (e) {
                        var cookieheader = "";
                    }
                    
                    for (var i=0; i<newcookies.length; i++)
                        cookieheader += newcookies[i][0] + "=" + newcookies[i][1] + "; ";
                    chan.setRequestHeader ("Cookie", cookieheader, false);
                    
                    ddump (DB_MODIFY, "CookieHeader" + chan.getRequestHeader ("Cookie") +"\n");
                }

                // Decide whether to send request to server_domain based on tags.
                if (ref_meta.slab && ref_meta.slab.length > 0) {
                  // for each tag
                  var i;
                  for (i=0; i<ref_meta.slab.length; i++) {
                    h = get_host (ref_meta.slab[i]);
                    if (h != strip_zone_id (chan.URI.host)) {
                      ddump (DB_MODIFY, "Trying to declassifying data with " + ref_meta.slab[i] + " to " + chan.URI.host);
                      // Declassifying data from h to chan.URI.host

                      if (external_req_ok (ref_meta.slab, chan.URI.host)) {
                        ddump (DB_MODIFY, "  OK\n");
                      } else {
                        ddump (DB_MODIFY, "  ABORT\n");
                        chan.cancel (ABORT);
                      }
                    }
                  }
                }
            }
        }

        ddump (DB_MODIFY, "  IS_SUBFRAME " + is_subframe + "\n");
        chan.setRequestHeader ("X-target-issubframe", is_subframe, false);

    } else if (topic == "http-on-examine-response") {
        ddump (DB_EXAMINE, "-------- http-on-examine-response --------\n");
        ddump (DB_EXAMINE, "  subject: " + subject + "\n");
        ddump (DB_EXAMINE, "  data: " + data + "\n");

        var chan = subject.QueryInterface(Components.interfaces.nsIHttpChannel);
        ddump (DB_EXAMINE, "  URI: " + chan.URI.spec + "\n");
        
        // Get the context and save any labels the server sent us.
        // All we are doing here is remembering what the server told
        // us, so the browser can send the labelset with future
        // requests.
        var mode = null;
        try {
            mode = chan.getResponseHeader ("X-w5mode");
        } catch (e) {}

        if (mode == "trusted") {
            var ctx = chan.URI.host;
            ddump (DB_EXAMINE, "Got trusted W5 page for " + ctx + "\n");
            bflow_domains.push (chan.URI.host);

            if (set_w5meta (ctx, true, null, null, null, null)) {
              ddump (DB_META, "Strange, creating root zone more than once\n");
            }
            
            w5toolbar_update_groups (chan.URI.host, ctx, [], [], [], []);
        } else if (mode == "untrusted") {
            var ctx = chan.URI.host;
            ddump (DB_EXAMINE, "Got untrusted W5 page for " + ctx + "\n");

            if (is_topframe (subject)) {
              dump ("ABORTED request, requested untrusted page in top frame\n");
              // TODO: for some reason, this gets triggered and prints
              // messages, but doesn't affect browser behavior.
              // Figure out why.

              // This is commented out for debugging.  In a real
              // system, you would uncomment it to prevent untrusted
              // code running in the top frame.
              //chan.cancel (ABORT);
            }

            var slab = get_header_label (chan, "X-slabel", true);
            var ilab = get_header_label (chan, "X-ilabel", true);
            var olab = get_header_label (chan, "X-olabel", true);

            var slab_en = get_header_label (chan, "X-slabel-en");
            var slab_all_en = get_header_label (chan, "X-slabel-all-en");
            var ilab_en = get_header_label (chan, "X-ilabel-en");
            var ilab_all_en = [];

            ddump (DB_EXAMINE, "  slabel: " + label2str (slab) + "\n");
            ddump (DB_EXAMINE, "  ilabel: " + label2str (ilab) + "\n");
            ddump (DB_EXAMINE, "  olabel: " + label2str (olab) + "\n");
            ddump (DB_EXAMINE, "  slabel_en: " + slab_en + "\n");

            // don't change I label unless we're loading a document
            // (not an image, not an AJAX response)
            if (!is_document (subject)) { olab = null; }
            
            if (!is_topframe (subject) && is_document (subject)) {
              var parent = get_parent_docshell (subject);
              var parent_frame_ctx = get_docshell_uri (parent).host

              ddump (DB_META, "frame        host: " + ctx + "\n");
              ddump (DB_META, "parent frame host: " + parent_frame_ctx + "\n");

              var m = get_w5meta (ctx);

              // Check that the new label doesn't invalidate channels to children
              // Check that any parent to this frame's zone will be
              // allowed to send to this zone after this zone changes
              // its label.
              if (!ctx_may_have_label (ctx, slab)) {
                dump ("ABORTED request, illegal label change: parent to child1b\n");
                chan.cancel (ABORT);
              }
              
              var parent_m = get_w5meta (parent_frame_ctx);
              set_w5meta (ctx, false, slab, ilab, olab, parent_m);
              parent_m.addChild (get_w5meta (ctx));
                                 
              w5toolbar_update_groups (chan.URI.host, ctx, slab_all_en, ilab_all_en, slab_en, ilab_en);
              return;
            }

            var m = get_w5meta (ctx);
            ddump (DB_META, "meta is: " + m + "\n")
            ddump (DB_META, "new slab: " + label2str (slab) + "\n")
            // Check that the new label doesn't invalidate channels to children
            if (m && !m.check_children_label (slab)) {
              dump ("ABORTED request, illegal label change: parent to child2\n");
              chan.cancel (ABORT);
            }
            
            set_w5meta (ctx, false, slab, ilab, olab, null);

            w5toolbar_update_groups (chan.URI.host, ctx, slab_all_en, ilab_all_en, slab_en, ilab_en);
        } else {
            ddump (DB_EXAMINE, "Got non-W5 page\n");
        }
    }
  }
};

var newtags = new Object(); // Remembers what tags we need to add to this context on the next request
function w5toolbar_tag_change (tag, ctx) {
  var checkboxes = document.getElementById("w5toolbar_group_checkboxes");
  var _newtags = [];

  for (var i=0; i<checkboxes.childNodes.length; i++) {
    var box = checkboxes.childNodes[i];
    if (box.getAttribute ("disabled") == "false") {
      if ((box.getAttribute ("checked")) && (tag != box.getAttribute ("realtagname")) ||
          (!box.getAttribute ("checked")) && (tag == box.getAttribute ("realtagname")))
        _newtags.push (box.getAttribute ("tagval"));
    }
  }
  newtags[ctx] = _newtags;
  ddump (DB_HEADER, "new tags for " + ctx + " is " + newtags[ctx] + "\n");
}

function w5toolbar_update_groups (host, ctx, slab_all, ilab_all, slab_active, ilab_active) {
  var checkboxes = document.getElementById("w5toolbar_group_checkboxes");
  for (var i=checkboxes.childNodes.length-1; i>=0; i--) {
    checkboxes.removeChild (checkboxes.childNodes[i]);
  }

  var username = get_username (host);
  slab_all.sort ();
  var found = [];
  for (i=0; i<slab_all.length; i++) {
    
    var x = slab_all[i].split (":", 3);
    var tagval = x[0];
    var user = x[1];
    var tagname = x[2];
    var compound_tagname = user + ":" + tagname;
    
    var box = document.createElement ("checkbox");
    box.setAttribute ("disabled", "false");
    box.setAttribute ("realtagname", compound_tagname);
    box.setAttribute ("tagval", tagval);

    if (user == username)
      box.setAttribute ("label", tagname);
    else
      box.setAttribute ("label", compound_tagname);

    if (slab_active.indexOf (compound_tagname) >= 0) {
      box.setAttribute ("checked", "true");
      box.setAttribute ("disabled", "true");
      found.push (compound_tagname);
    } else {
      box.setAttribute ("onclick", "w5toolbar_tag_change (\"" + compound_tagname + "\", \"" + ctx + "\");");
    }
    checkboxes.appendChild (box);
  }
  
  for (i=0; i<slab_active.length; i++) {
    if (found.indexOf (slab_active[i]) < 0) {
      var box = document.createElement ("checkbox");
      box.setAttribute ("label", slab_active[i]);
      box.setAttribute ("checked", "true");
      box.setAttribute ("disabled", "true");
      box.setAttribute ("realtagname", slab_active[i]);
      checkboxes.appendChild (box);
    }
  }
}

/*********** Remove access to cross-domain messaging below *********/
function W5PostMessage (msg, targetorigin) {
    dump ("Illegal W5POSTMESSAGE to " + targetorigin + "\n");
}

function send_to_window (target_win, aId, msg){
  var doc = target_win.document;
  var elm = doc.getElementById(aId);

  if (elm && "createEvent" in doc) {
    elm.setAttribute("msg", msg);
    var evt = doc.createEvent("Events");
    evt.initEvent("w5recv", true, false);
    elm.dispatchEvent(evt);
  } else {
    dump ("Could not find element\n");
  }
}

function handle_w5send (win_id, evt) {
  var target_win_name = evt.target.getAttribute("target");
  var msg = evt.target.getAttribute("msg");
  ddump (DB_POSTMSG, "Received msg from window " + win_id + " to windows " + target_win_name + ": " + msg + "\n");

  var target_windows = get_windows (target_win_name);
  for (var i=0; i<target_windows.length; i++) {
    var src_w5meta = get_w5meta (evt.target.ownerDocument.domain);
    var dst_w5meta = get_w5meta (target_windows[i].document.domain);

    ddump (DB_POSTMSG, "src: " + src_w5meta.toString () + "\n");
    ddump (DB_POSTMSG, "dst: " + dst_w5meta.toString () + "\n");

    if (!label_is_subset (src_w5meta.slab, dst_w5meta.slab)) {
      dump ("handle_w5send: client tried to send illegal message, S label violation\n");
      return;
    }
    if (!label_is_subset (dst_w5meta.ilab, src_w5meta.ilab)) {
      dump ("handle_w5send: client tried to send illegal message, I label violation\n");
      return;
    }

    ddump (DB_POSTMSG, "sending legal msg\n");
    send_to_window (target_windows[i], "w5recvdiv", msg);
  }
}

function handle_augment_label (win_id, evt) {
  var tag = make_host_tag (strip_zone_id (evt.target.ownerDocument.domain),
                           evt.target.getAttribute("tag"));
  var w5meta = get_w5meta (evt.target.ownerDocument.domain);
  ddump (DB_LABEL, "Received augment_label from window " + win_id + " adding tag " + tag + " to context " + w5meta.ctx + "\n");
  ddump (DB_LABEL, "  " + w5meta + "\n");

  if (label_contains_tag (w5meta.slab, tag)) {
    ddump (DB_LABEL, "  already has tag " + tag + "\n");
    return;
  }
  
  var test_slab = w5meta.slab.slice ();
  test_slab.push (tag);
  
  if (!ctx_may_have_label (w5meta.ctx, test_slab)) {
    dump ("LABEL FAILURE, illegal label change: parent to child1b\n");
    return;
  }
  w5meta.slab.push (tag);

  ddump (DB_LABEL, "  label change succeeded\n");
  ddump (DB_LABEL, "  " + w5meta + "\n");
}

/*********** Remove the dangerous parts of a new window object. *********/
var counter = 0;
function makesafe_window_one (w) {
  // Prevent windows from sending cross-domain messages to each other
  var win_id = counter++;
  ddump (DB_POSTMSG, "WINDOW " + win_id + " " + w.location + "\n");

  // listen for w5send
  w.document.addEventListener("w5send", function(e) { handle_w5send (win_id, e); }, false);
  w.document.addEventListener("w5augment_label", function(e) { handle_augment_label (win_id, e); }, false);
  
  // Save a reference to this XPCwrapper
  // XXX eventually, we will need to remove references in all_windows after windows close.
  all_windows[win_id] = w;

  // Remove access to the original postMessage and eval
  //if (w.wrappedJSObject) { }
}

function makesafe_window (w) {
  makesafe_window_one (w);
  for (var i=0; i<w.frames.length; i++)
    makesafe_window (w.frames[i]);
}

/*********** Web Progress Listener *********/
var webprog_handler = {
  QueryInterface: function(aIID) {
    if(!aIID.equals(CI.nsISupports) && 
       !aIID.equals(CI.nsISupportsWeakReference) &&
       !aIID.equals(CI.nsIWebProgressListener)) {
      throw CR.NS_ERROR_NO_INTERFACE;
    }
    return this;
  },

  onStateChange: function(wp, req, stateFlag, status) {
    // This gets called before the HTML javascript begins to run.
    // This gets call a bunch of times, but we need to wait until
    // (STATE_START | STATE_IS_REQUEST) because any
    // changes we make to DOMWindow before then will not be visible to
    // the client HTML code.
    
    var st = STATE_START | STATE_IS_REQUEST;
    if ((stateFlag & st) == st && ! (wp.DOMWindow instanceof CI.nsIDOMChromeWindow)) {
      makesafe_window (wp.DOMWindow);
    }
  },
  onLocationChange: function() {},
  onStatusChange: function() {},
  onSecurityChange: function() {}, 
  onProgressChange: function() {}
};

function enable_feature (cap, enable) {
  try {    
    var p = cap;
    var k = Components.interfaces.nsISupportsString;
    var s = Components.classes['@mozilla.org/supports-string;1'].createInstance(k) ;
    s.data = enable ? "allAccess" : "noAccess";
    prefManager.setComplexValue (p, k, s);
  } catch (e)  {
    dump ("EERROR: " + e + "\n");
  }
}

function enable_postmessage (enable) {
  enable_feature ("capability.policy.default.Window.postMessage.get", enable);
}

function enable_window_location (enable) {
  enable_feature ("capability.policy.default.Window.location", enable);
}

/*********** Register event handlers below *********/
function w5toolbar_init (event) {
    var enabled = prefManager.getBoolPref("extensions.w5toolbar.enabled");
    w5toolbar_set_enabled (enabled);
}

function w5toolbar_register_listeners () {
  /* Register Proxy Handler */
  var ps = CC["@mozilla.org/network/protocol-proxy-service;1"].getService(CI.nsIProtocolProxyService);
  ps.unregisterFilter(proxy_handler);
  ps.registerFilter(proxy_handler, 0);
  
  var observerService = Components.classes["@mozilla.org/observer-service;1"].getService(Components.interfaces.nsIObserverService);
  observerService.addObserver(urlObserver, "http-on-modify-request", false); 
  observerService.addObserver(urlObserver, "http-on-examine-response", false); 
  
  var dls = CC['@mozilla.org/docloaderservice;1'].getService(CI.nsIWebProgress);
  dls.addProgressListener(webprog_handler, 
                          CI.nsIWebProgress.NOTIFY_STATE_DOCUMENT |
                          CI.nsIWebProgress.NOTIFY_STATE_REQUEST);

  enable_postmessage (false);
  enable_window_location (false);
}

function w5toolbar_unregister_listeners () {
  var ps = CC["@mozilla.org/network/protocol-proxy-service;1"].getService(CI.nsIProtocolProxyService);
  try {
    ps.unregisterFilter(proxy_handler);
  } catch (e) {}

    var observerService = Components.classes["@mozilla.org/observer-service;1"].getService(Components.interfaces.nsIObserverService);
  try {
    observerService.removeObserver(urlObserver, "http-on-modify-request"); 
  } catch (e) {}
  try {
    observerService.removeObserver(urlObserver, "http-on-examine-response");
  } catch (e) {}

  var dls = CC['@mozilla.org/docloaderservice;1'].getService(CI.nsIWebProgress);
  try {
    dls.removeProgressListener(webprog_handler);
  } catch (e) {}

  enable_postmessage (true);
  enable_window_location (true);
}

function w5toolbar_set_enabled (_enabled) {
    if (_enabled == w5toolbar_enabled)
        return;

    var elem = document.getElementById("w5toolbar-status-text");
    if (_enabled) {
        w5toolbar_register_listeners ();
        elem.label = "Webmac Enabled";
        elem.setAttribute ("style", "font-weight: bold; color: green");
    } else {
        w5toolbar_unregister_listeners ();
        elem.label = "Webmac Disabled";
        elem.setAttribute ("style", "font-weight: bold; color: red");
    }
    prefManager.setBoolPref("extensions.w5toolbar.enabled", _enabled);
    w5toolbar_enabled = _enabled;
}

function w5toolbar_toggle () { w5toolbar_set_enabled (!w5toolbar_enabled); }

