
function http(m, u, d, f, s, c){
  var r=null;
  var t=0,p=0,q=0;
  if(window.XMLHttpRequest){
    r=new XMLHttpRequest();
  }else{
    if(window.ActiveXObject){
      try{
        r=new ActiveXObject("Msxml2.XMLHTTP");
      }
      catch(e){
        try{
          r=new ActiveXObject("Microsoft.XMLHTTP");
        }
        catch(e){
        }
      }
    }
  }
  if(!r){
    return false;
  }
  r.onreadystatechange=function(){
    if(r.readyState==4){
      window.clearTimeout(w);
      if(r.status==200){
        eval(f+"(r.responseText, c)");
      } else if (r.status==500) {
        eval (f + "('', c)");
      }else{
        if(!s){
          alert("error 1");
          eval(f+"('', c)");
        }
      }
    }
  };
  this.hfail=function(){
    r.onreadystatechange=function(){
    };
    r.abort();
    if(!s){
      alert(t14+"timeout");
      eval(f+"('', c)");
    }
  };

  var w=window.setTimeout(this.hfail,20000);
  r.open(m,u,true);
  r.setRequestHeader("Connection","close");
  if(d){
    r.setRequestHeader("Content-Type","application/x-www-form-urlencoded");
  }
  r.send(d);
  return true;
}

function send_poke (form) {
  poke_content = document.getElementById ("poke_content").value;
  sender = document.getElementById ("sender").value;
  receiver = document.getElementById ("receiver").value;

  // Fetch the current content of this "sender:receiver" poke-pipe.
  var key = sender + ":" + receiver;
  if(!http("GET",
           "/pythonf/js/lc_/storage/forkdjango.py/get/" +
           ("?submit=submit" + 
            "&key=" + key),
           null,
           "send_poke_cb",
           false,
           [key, poke_content])){    
    return false;
  }
  return true;
}

var DELIM = "|";
function send_poke_cb (data, pass) {
  // Send data to server
  key = pass[0];
  if (data == "") {
    data = pass[1];
  } else {
    data = data + DELIM + pass[1];
  }
  if (!http ("POST",
             "/pythonf/js/lc_/storage/forkdjango.py/put/",
             ("submit=submit" + 
              "&key=" + key +
              "&val=" + data),
             "send_poke_cb2",
             false,
             null)){
    f.pst.value=ptmp;
    return false;
  }
  return true;
}

function send_poke_cb2 (data, foo) {
  alert ("done?");
}

function get_pokes () {
  if (!http ("GET", "{{ compareprefix }}/get_friends/",
             null, "get_friends_cb", false, null)) {
    alert ("error GETing friendlist");
  }
}

function get_friends_cb (data, foo) {
  var friends = data.split (",");
  for (var i=0; i<friends.length; i++) {

    key = friends[i] + ":" + "{{ username }}";
      
    if (!http ("GET", "{{ storageprefix }}/get/" +
               ("?submit=submit" + 
                "&key=" + key),
               null, "get_pokes_cb", false, friends[i])) {
      alert ("error GETing pokes");
    }
  }
}

function get_pokes_cb (data, friend) {
  var pokes = data.split (DELIM);
  for (var i=0; i<pokes.length; i++) {
    if (pokes[i] != "") {
      alert (friend + " -> {{ username}}:" + pokes[i]);
    }
  }
}
