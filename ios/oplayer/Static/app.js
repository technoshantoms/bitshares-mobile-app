!function i(c,s,a){function u(e,t){if(!s[e]){if(!c[e]){var n="function"==typeof require&&require;if(!t&&n)return n(e,!0);if(f)return f(e,!0);var r=new Error("Cannot find module '"+e+"'");throw r.code="MODULE_NOT_FOUND",r}var o=s[e]={exports:{}};c[e][0].call(o.exports,function(t){var n=c[e][1][t];return u(n||t)},o,o.exports,i,c,s,a)}return s[e].exports}for(var f="function"==typeof require&&require,t=0;t<a.length;t++)u(a[t]);return u}({1:[function(t,n,e){var r;function o(){}console.log("app started "+window.location.href),t("./extension.coffee"),window.utils=t("./utils.coffee"),o.prototype.show_block_view=function(t){this.__call("show_block_view",t)},o.prototype.hide_block_view=function(){this.__call("hide_block_view")},o.prototype.query_objects=function(t,n){this.__call("query_objects",t,n)},o.prototype.__callback_ids={},o.prototype.__handle_async_callback=function(t){var n,e;e=t.cid,(n=this.__callback_ids[e])&&(n(t.err,t.data),delete this.__callback_ids[e])},o.prototype.__call=function(t,n,e){var r,o;return r=JSON.stringify({mid:t,args:n||""}),"function"==typeof e?(o=prompt("__btspp_sdk_call_mode=async",r),this.__callback_ids[o]=e,o):prompt("__btspp_sdk_call_mode=sync",r)},o.prototype.initialize=function(t){var n;n=this,window.__btspp_jssdk_on_async_callback=function(t){n.__handle_async_callback(t)},t()},o.prototype.onHashChange=function(){},o.prototype._getLocationHash=function(){var t,n,e,r,o,i;return(o=(r=window.location.href).indexOf("#"))<0?{activity:"home",hash:"",args:{}}:{activity:(t=(n=0<=(i=(n=r.slice(o+1)).indexOf("?"))?decodeURI(n.slice(0,i))+n.slice(i):0<=(e=n.indexOf("#"))?decodeURI(n.slice(0,e))+n.slice(e):decodeURI(n)).replace(/\\/g,"/").split("/").filter(function(t){return""!==t})).first()||"home",hash:n=t.join("/"),args:t}},r=o,window.__btspp_jssdk||(window.__btspp_jssdk=new r,__btspp_jssdk.initialize(function(){return __btspp_jssdk.onHashChange()}))},{"./extension.coffee":2,"./utils.coffee":3}],2:[function(t,n,e){var a,r;String.prototype.padLeft=function(t,n){return this.length>=t?this:Array(t-this.length+1).join(n||"0")+this},Array.prototype.delete=function(t){var n;0<=(n=this.indexOf(t))&&this.splice(n,1)},Array.prototype.delete_at=function(t){this.splice(t,1)},Array.prototype.insert=function(t,n){this.splice(t+1,0,n)},Array.prototype.insert_before=function(t,n){this.splice(t,0,n)},Array.prototype.first=function(){return this[0]},Array.prototype.last=function(){var t;if(0!==(t=this.length))return this[t-1]},Array.prototype.asc_sort=function(o){this.sort(function(t,n){var e,r;return(e=o(t))===(r=o(n))?0:r<e?1:-1})},Array.prototype.des_sort=function(o){this.sort(function(t,n){var e,r;return(e=o(t))===(r=o(n))?0:r<e?-1:1})},Array.prototype.asc_sort_by=function(o){this.sort(function(t,n){var e,r;return(e=t[o])===(r=n[o])?0:r<e?1:-1})},Array.prototype.des_sort_by=function(o){this.sort(function(t,n){var e,r;return(e=t[o])===(r=n[o])?0:r<e?-1:1})},r=function(t){var n,e,r,o,i,c,s;if(null==t||"object"!=typeof t)return t;if(t instanceof Array){for(c=[],e=0,o=t.length;e<o;e++)s=t[e],c.push(s);return c}if(t instanceof Date)return new Date(t.getTime());if(t instanceof RegExp)return n="",null!=t.global&&(n+="g"),null!=t.ignoreCase&&(n+="i"),null!=t.multiline&&(n+="m"),null!=t.sticky&&(n+="y"),new RegExp(t.source,n);for(r in i=new t.constructor,t)i[r]=t[r];return i},a=function(t){var n,e,r,o,i,c,s;if(null==t||"object"!=typeof t)return t;if(t instanceof Array){for(c=[],e=0,o=t.length;e<o;e++)s=t[e],c.push(a(s));return c}if(t instanceof Date)return new Date(t.getTime());if(t instanceof RegExp)return n="",null!=t.global&&(n+="g"),null!=t.ignoreCase&&(n+="i"),null!=t.multiline&&(n+="m"),null!=t.sticky&&(n+="y"),new RegExp(t.source,n);for(r in i=new t.constructor,t)i[r]=a(t[r]);return i},window.f_createevent=function(n,e){var r;try{r=new CustomEvent(n,{detail:e,bubbles:!0,cancelable:!0})}catch(t){t,(r=document.createEvent("Event")).initEvent(n,!0,!0),r.detail=e}return r},window.clone=function(t){return r(t)},window.deep_clone=function(t){return a(t)},window.json_deep_clone=function(t){return JSON.parse(JSON.stringify(t))}},{}],3:[function(t,n,e){var r,o,u,i;r=/^\d+\.\d+\.\d+$/i,o=/^\d+\.[23]\.\d+$/i,u=function(t,n,e,r){var o,i,c,s,a;if("string"!=(s=typeof n)){if("object"==s)if(n instanceof Array)for(o=0,c=n.length;o<c;o++)a=n[o],u(t,a,e,r);else for(i in n)u(t,n[i],e,r)}else n.match(t)&&!r[n]&&(e[n]=!0)},i={delay0:function(t){setTimeout(t,0)},isAssetOrAccountOid:function(t){return t.match(o)},parseNestedOids:function(t,n){var e;return u(r,t,e={},n),Object.keys(e)},parseAssetAndAccountOids:function(t,n){var e;return u(o,t,e={},n),Object.keys(e)}},n.exports=i},{}]},{},[1]);