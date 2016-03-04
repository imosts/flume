
var DB_PROXY     = 1 << 0;
var DB_MODIFY    = 1 << 1;
var DB_EXAMINE   = 1 << 2;
var DB_HEADER    = 1 << 3;
var DB_POSTMSG   = 1 << 4;
var DB_META      = 1 << 5;
var DB_LABEL     = 1 << 6;

var debug_level = DB_LABEL | DB_MODIFY | DB_EXAMINE;

/* Makeshift declassification rules.  A better impl would get these
 * from the server. */
declass_rules = new Object ();
declass_rules["pdos.csail.mit.edu"] = ["hydra.lcs.mit:0x050000000001b828"];
declass_rules["web.mit.edu"] = ["hydra.lcs.mit:0x050000000001b829"];

function ddump (lvl, s) {
    if (debug_level & lvl) 
        dump (s);
}

function dump_object (lvl, obj) {
    ddump (lvl, "OBJECT " + obj + "\n");
    for (var k in obj) {
      try {
        var s = obj[k].toString ().substring(0,40);
      } catch (e) {
        var s = "";
      }
      ddump (lvl, "  " + k + "\t " + s + "\n");
    }
}

function to_zone_suffix (domain) {
  return domain.substring (0, domain.lastIndexOf ("."));
}

function strip_zone_id (zone_domain) {
  return zone_domain.substring (zone_domain.indexOf (".") + 1);
}

function strip_host (host_and_tag) {
  return host_and_tag.substring (host_and_tag.indexOf (":") + 1)
}

function get_host (host_and_tag) {
  return host_and_tag.substring (0, host_and_tag.indexOf (":"))
}

function make_host_tag (host, tag) {
  return host + ":" + tag;
}



// Represent labels as a list of strings like this: "0x12345678"
function get_header_label (chan, headername, append_host) {
    try {
        var s = chan.getResponseHeader (headername);
        ddump (DB_HEADER, "header " + headername + " is " + s + "\n");
        if (s.length == 0)
            return [];
        var lab_str = s.split (",");

        if (append_host) {
          var i;
          var ret = [];
          for (i=0; i<lab_str.length; i++) {
            ret.push (strip_zone_id (chan.URI.host) + ":" + lab_str[i]);
          }
          return ret;
        } else {
          return lab_str;
        }
          
    } catch (e) {
        return [];
    }
}

function label2str (lab, _strip_host) {
    var s = "[";
    for (var i=0; i<lab.length; i++) {
        if (i > 0) 
            s += ",";
        if (_strip_host) {
          s += strip_host (lab[i]);
        } else { 
          s += lab[i];
        }
    }
    return s + "]";
}

function label_is_subset (lab1, lab2) {
  for (var i=0; i<lab1.length; i++) {
    var found = false;
    for (var j=0; j<lab2.length; j++)
      if (lab1[i] == lab2[j]) 
        found = true;
    
    if (!found)
      return false;
  }
  return true;
}

function label_contains_tag (lab, tag) {
  for (var i=0; i<lab.length; i++) {
    if (tag == lab[i]) {
      return true;
    }
  }
  return false;
}

function array_contains (arr, val) {
  var i;
  for (i=0; i<arr.length; i++) {
    if (arr[i] == val) {
      return arr[i];
    }
  }
  return false;
}

function external_req_ok (parent_slab, child_host) {
  ddump (DB_LABEL, "external_req_ok " + child_host + "\n");
  
  var i;
  for (i=0; i<parent_slab.length; i++) {
    ddump (DB_LABEL, "searching for " + parent_slab[i] + " rule for " + child_host +  " rules: \n");
    ddump (DB_LABEL, " rules: " + declass_rules[child_host] + "\n");
    
    if (declass_rules [child_host] == undefined || !array_contains (declass_rules [child_host], parent_slab[i])) {
      return false;
    }
  }
  return true;
}

var contextMetaData = new Object(); // Maps contexts to S and I labels.
function W5Meta (ctx, trusted, slab, ilab, olab, parent) {
    ddump (DB_META, "creating meta " + parent + " <- " + ctx + "\n");
    this.ctx = ctx;
    this.trusted = trusted;
    this.slab = slab;
    this.ilab = ilab;
    this.olab = olab;
    this.parent = parent;
    this.children = [];
}
W5Meta.prototype = {
 toString : function () {
    if (this.trusted)
      return "[cid: " + this.ctx + " trusted]";
    else
      return "[cid: " + this.ctx + " S: " + this.slab + " I: " + this.ilab + " O: " + this.olab + "]";
  },

 addChild : function (child) {
    for (var i=0; i<this.children.length; i++) {
      if (this.children[i].ctx == child.ctx)
        return;
    }
    this.children.push (child);
  },

 check_children_label : function (slab) {
    // returns True if every child's S >= slab
    for (var i=0; i<this.children.length; i++) {
      ddump (DB_META, "child: " + this.children[i] + "\n");
      if (!label_is_subset (slab, this.children[i].slab))
        return false
    }
    return true;
  },
    
 canTalkOutside : function () {
    return (this.slab.length == 0 && this.ilab.length == 0);
  },
 maySendTo : function (dst_lab) {
    return (label_is_subset (this.slab, dst_lab));
  }
};

function set_w5meta (ctx, trusted, slab, ilab, olab, parent) {
  c = contextMetaData[ctx];
  if (c) {
    ddump (DB_META, "updating old meta for ctx " + ctx + "\n");
    c.trusted = trusted;
    if (slab) { c.slab = slab; }
    if (ilab) { c.ilab = ilab; }
    if (olab) { c.olab = olab; }
    return false;
  } else {
    ddump (DB_META, "creating new meta for ctx " + ctx + "\n");
    contextMetaData[ctx] = new W5Meta (ctx, trusted, slab, ilab, olab, parent);
    return true;
  }
}

function get_w5meta (ctx) {
  var r = contextMetaData[ctx];
  return r ? r : null;
}

function getCookies(host)
{
    var ret = [];
    var i = 0;
    var cookieManager = Components.classes["@mozilla.org/cookiemanager;1"].getService(Components.interfaces.nsICookieManager);

    var iter = cookieManager.enumerator;
    while (iter.hasMoreElements()){
        var cookie = iter.getNext();
        if (cookie instanceof Components.interfaces.nsICookie){
            if (cookie.host == host)
              ret[i++] = [cookie.name, cookie.value];
        }
    }
    return ret;
}

function get_username (host) {
  // Get username from cookies
  var cookies = getCookies ("." + host);
  for (var i=0; i<cookies.length; i++) {
    if (cookies[i][0] == "FLUME_UN")
      return cookies[i][1];
  }
  return null;
}

function check_interfaces (s, obj) {
    ddump (DB_MODIFY, s + " 1 " + obj + "\n");

    function check (typ, typname) {
        if (obj instanceof typ)
            ddump (DB_MODIFY, "  Is " + typname + "\n");
    }

    check (Components.interfaces.nsIChannel, "nsIChannel");
    check (Components.interfaces.nsIRequest, "nsIRequest");
    check (Components.interfaces.nsIHttpChannel, "nsIHttpChannel");
    check (Components.interfaces.nsIXMLHttpRequest, "nsIXMLHttpRequest");
    check (Components.interfaces.nsIDOMWindow, "nsIDOMWindow");
    check (Components.interfaces.nsIDocShell, "nsIDocShell");
    check (Components.interfaces.nsIInterfaceRequestor, "nsIInterfaceRequestor");
    check (Components.interfaces.nsIWebProgress, "nsIWebProgress");
    check (Components.interfaces.nsIWebNavigation, "nsIWebNavigation");
    check (Components.interfaces.nsIDocShellHistory, "nsIDocShellHistory");
    check (Components.interfaces.nsIRequestObserver, "nsIRequestObserver");
    check (Components.interfaces.nsIDocShellTreeItem, "nsIDocShellTreeItem");
    check (Components.interfaces.nsIContentHandler, "nsIContentHandler");

    check (Components.interfaces.imgIContainer, "imgIContainer");
    check (Components.interfaces.imgIContainerObserver, "imgIContainerObserver");
    check (Components.interfaces.imgIDecoder, "imgIDecoder");
    check (Components.interfaces.imgIDecoderObserver, "imgIDecoderObserver");
    check (Components.interfaces.imgIEncoder, "imgIEncoder");
    check (Components.interfaces.imgILoad, "imgILoad");
    check (Components.interfaces.imgILoader, "imgILoader");
    check (Components.interfaces.imgIRequest, "imgIRequest");
    check (Components.interfaces.imgICache, "imgICache");

    ddump (DB_MODIFY, s + " 2 " + obj + "\n");
}

function docshell_gethost (docshell) {
  if (docshell instanceof Components.interfaces.nsIWebNavigation) {
    n = docshell.QueryInterface(Components.interfaces.nsIInterfaceRequestor)
                .getInterface(Components.interfaces.nsIWebNavigation);
    if (n.currentURI &&
        (n.currentURI.scheme == "http" || n.currentURI.scheme == "https")) {
      return n.currentURI.host;
    }
  }
  return null;
}

function traverse_docShellTree (node, func) {
  _node = node.QueryInterface(Components.interfaces.nsIInterfaceRequestor)
              .getInterface(Components.interfaces.nsIWebNavigation);
  func (_node);
  var i;
  for (i=0; i<node.childCount; i++) {
    traverse_docShellTree (node.getChildAt (i), func);
  }
}

function traverse_all_docShells (func) {
  root = window.QueryInterface(Components.interfaces.nsIInterfaceRequestor)
    .getInterface(Components.interfaces.nsIWebNavigation)
    .QueryInterface(Components.interfaces.nsIDocShellTreeItem)
    .rootTreeItem;

  traverse_docShellTree (root, func);
}

function is_document (subject) {
  var chan = subject.QueryInterface(Components.interfaces.nsIHttpChannel); 
  if (subject.notificationCallbacks) {
    if (subject.notificationCallbacks instanceof Components.interfaces.nsIDocShellTreeItem) {
      return true;
    } else {
      return false;
    }
  } else {
    // We see this for things like CSS files.
    ddump (DB_MODIFY, "Strange, subject.notificationCallbacks is empty1\n");
    return false;
  } 
}

function is_topframe (subject) {
  var chan = subject.QueryInterface(Components.interfaces.nsIHttpChannel); 
  if (subject.notificationCallbacks) {
    if (subject.notificationCallbacks instanceof Components.interfaces.nsIDocShellTreeItem) {
      subject.notificationCallbacks.QueryInterface (Components.interfaces.nsIDocShellTreeItem);
      parent = subject.notificationCallbacks.parent;
      if (parent == subject.notificationCallbacks.rootTreeItem) {
        return true;
      }
    }
  }
  return false; 
}

function get_parent_docshell (subject) {
  var chan = subject.QueryInterface(Components.interfaces.nsIHttpChannel); 
  if (subject.notificationCallbacks) {
    if (subject.notificationCallbacks instanceof Components.interfaces.nsIDocShellTreeItem) {
      subject.notificationCallbacks.QueryInterface (Components.interfaces.nsIDocShellTreeItem);
      var parent = subject.notificationCallbacks.parent;
      return parent;
    }
  }
  return null;
}

function get_docshell_uri (docshell) {
  if (docshell instanceof Components.interfaces.nsIWebNavigation) {
    i = docshell.QueryInterface (Components.interfaces.nsIWebNavigation);
    return docshell.currentURI;
  }
  return null;
}

function _ctx_may_have_label (ctx, label, frame_docshell) {
  var i;

  if (frame_docshell.itemType == frame_docshell.typeContent) {
    for (i=0; i<frame_docshell.childCount; i++) {
      // If <frame_docshell> has a child with <ctx>, check that <frame_docshell>'s label is a subset of <label>

      n = frame_docshell.QueryInterface(Components.interfaces.nsIInterfaceRequestor)
                        .getInterface(Components.interfaces.nsIWebNavigation);

      if (docshell_gethost (frame_docshell.getChildAt (i)) == ctx) {
        var frame_m = get_w5meta (docshell_gethost (frame_docshell));
        if (!frame_m.maySendTo (label))
          return false;
      }

      if (docshell_gethost (frame_docshell) == ctx) {
        // If <frame_docshell> has ctx, then check to see if all its children may see <label>
        child_docshell = frame_docshell.getChildAt (i)

        if (docshell_gethost (child_docshell)) {

          var child_host = docshell_gethost (child_docshell);
          // If parent and child are from the same host
          if (strip_zone_id (child_host) == to_zone_suffix (docshell_gethost (frame_docshell)) || 
              strip_zone_id (child_host) == strip_zone_id (docshell_gethost (frame_docshell))) {
            
            var child_m = get_w5meta (docshell_gethost (child_docshell));
            if (!label_is_subset (label, child_m.slab)) {
            ddump (DB_LABEL, "  frame " + to_zone_suffix (docshell_gethost (frame_docshell)) +
                   " has external child(1) " + docshell_gethost (child_docshell) + "\n");

            return false;
            }
          } else {
            ddump (DB_LABEL, "  frame " + to_zone_suffix (docshell_gethost (frame_docshell)) +
                   " has external child(2) " + docshell_gethost (child_docshell) + "\n");

            if (!external_req_ok (label, docshell_gethost (child_docshell))) {
              // There is no declass rule allowing the parents slabel
              // to communicate to the external host
              return false;
            }
          }
        }
      }
    }
  }

  for (i=0; i<frame_docshell.childCount; i++) {
    if (!_ctx_may_have_label (ctx, label, frame_docshell.getChildAt (i)))
      return false;
  }
  return true;
}

/* returns true if it's safe for <frame> to have the S= <label> */
function ctx_may_have_label (ctx, label) {
  root = window.QueryInterface(Components.interfaces.nsIInterfaceRequestor)
    .getInterface(Components.interfaces.nsIWebNavigation)
    .QueryInterface(Components.interfaces.nsIDocShellTreeItem)
    .rootTreeItem;

  return _ctx_may_have_label (ctx, label, root);
}
