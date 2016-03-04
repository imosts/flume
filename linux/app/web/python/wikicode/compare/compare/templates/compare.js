function http(m, u, d, f, s, c){
  //alert ("HTTP " + m);
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

var my_interests = [];
function start () {
  if (!http ("GET", "{{ urlprefix }}/get_interests/{{ username }}/",
             null, "my_interests_cb", false, "{{ username }}")) {
    alert ("error GETing interests for {{ username }}");
  }
}

function my_interests_cb (data, foo) {
  my_interests = data.split (",");
  get_friends ();
}

function get_friends () {
  if (!http ("GET", "{{ urlprefix }}/get_friends/",
             null, "get_friends_cb", false, null)) {
    alert ("error GETing friendlist");
  }
}

function get_friends_cb (data, foo) {
  alert ("friends are: " + data);
  var friends = data.split (",");
  for (var i=0; i<friends.length; i++) {
    if (!http ("GET", "{{ urlprefix }}/get_interests/" + friends[i] + "/",
               null, "get_interests_cb", false, friends[i])) {
      alert ("error GETing interests for " + friends[i]);
    }
  }
}

function get_interests_cb (data, friendname) {
  var interests = data.split (",");
  alert (friendname + "'s interests are " + data);

  for (var i=0; i<my_interests.length; i++) {
    for (var j=0; j<interests.length; j++) {
      if (interests[j] != "" && my_interests[i] == interests[j]) {
        is_interested (friendname, interests[j]);
      }
    }
  }
}

function is_interested (friendname, interest) {
  e = document.getElementById ("output");
  e.innerHTML = e.innerHTML + ", " + friendname + "(" + interest + ")";
}

function foo () {
  if (!http ("GET", "{{ urlprefix }}/get_interests/carol/",
             null, "get_interests_cb", false, "carol")) {
    alert ("error GETing interests for " + "carol");
  }
}
